import VideoToolbox
@preconcurrency import WebRTC

/// Extends the upstream decoder factory with Apple's receive-only HEVC decoder.
nonisolated final class CameraVideoDecoderFactory: NSObject, RTCVideoDecoderFactory {
    private let upstream = RTCDefaultVideoDecoderFactory()

    func supportedCodecs() -> [RTCVideoCodecInfo] {
        var codecs = upstream.supportedCodecs()
        if VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC) {
            codecs.append(RTCVideoCodecInfo(name: "H265", parameters: [
                "profile-id": "1", "tier-flag": "0", "level-id": "153", "tx-mode": "SRST"
            ]))
        }
        return codecs
    }

    func createDecoder(_ info: RTCVideoCodecInfo) -> (any RTCVideoDecoder)? {
        info.name == "H265" ? CameraHEVCDecoder() : upstream.createDecoder(info)
    }
}

nonisolated final class CameraHEVCDecoder: NSObject, RTCVideoDecoder {
    // MARK: - Properties
    private var callback: RTCVideoDecoderCallback?
    private var parameterSets: [UInt8: Data] = [:]
    private var format: CMVideoFormatDescription?
    private var session: VTDecompressionSession?

    // MARK: - Lifecycle
    func setCallback(_ callback: @escaping RTCVideoDecoderCallback) { self.callback = callback }
    func startDecode(withNumberOfCores numberOfCores: Int32) -> Int { 0 }
    func implementationName() -> String { "VideoToolbox HEVC" }

    func release() -> Int {
        invalidateSession()
        parameterSets.removeAll()
        callback = nil
        return 0
    }

    // MARK: - Decoding
    func decode(_ encodedImage: RTCEncodedImage, missingFrames: Bool,
                codecSpecificInfo info: (any RTCCodecSpecificInfo)?, renderTimeMs: Int64) -> Int {
        guard let units = HEVCFramePayload.nalUnits(in: encodedImage.buffer as Data) else { return -1 }
        var changed = false
        for unit in units {
            let type = (unit[unit.startIndex] >> 1) & 0x3f
            if (32...34).contains(type), parameterSets[type] != unit {
                parameterSets[type] = unit
                changed = true
            }
        }
        if changed { invalidateSession() }
        guard units.contains(where: { (($0[$0.startIndex] >> 1) & 0x3f) < 32 }) else { return 0 }
        guard prepareSession(), let session, let format,
              let payload = HEVCFramePayload.lengthPrefixed(units) else { return -1 }

        var block: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil,
            blockLength: payload.count, blockAllocator: kCFAllocatorDefault, customBlockSource: nil,
            offsetToData: 0, dataLength: payload.count, flags: 0, blockBufferOut: &block) == noErr,
            let block else { return -1 }
        let copied = payload.withUnsafeBytes { bytes in
            CMBlockBufferReplaceDataBytes(with: bytes.baseAddress!, blockBuffer: block,
                                          offsetIntoDestination: 0, dataLength: payload.count)
        }
        guard copied == noErr else { return -1 }
        var size = payload.count
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: block,
            formatDescription: format, sampleCount: 1, sampleTimingEntryCount: 0,
            sampleTimingArray: nil, sampleSizeEntryCount: 1, sampleSizeArray: &size,
            sampleBufferOut: &sample) == noErr, let sample else { return -1 }
        let timestamp = encodedImage.timeStamp
        let rotation = encodedImage.rotation
        let captureNs = encodedImage.captureTimeMs * 1_000_000
        let callback = callback
        var decodeStatus: OSStatus = noErr
        // Synchronous output keeps decoder ownership and release on WebRTC's decoder thread.
        let status = VTDecompressionSessionDecodeFrame(session, sampleBuffer: sample,
            flags: [], infoFlagsOut: nil) { status, _, image, _, _ in
                decodeStatus = status
                guard status == noErr, let image else { return }
                let frame = RTCVideoFrame(buffer: RTCCVPixelBuffer(pixelBuffer: image),
                    rotation: rotation, timeStampNs: captureNs)
                frame.timeStamp = Int32(bitPattern: timestamp)
                callback?(frame)
            }
        return status == noErr && decodeStatus == noErr ? 0 : -1
    }

    // MARK: - Private Helpers
    private func prepareSession() -> Bool {
        if session != nil { return true }
        guard let vps = parameterSets[32], let sps = parameterSets[33], let pps = parameterSets[34] else { return false }
        let sets = [vps, sps, pps]
        let joined = sets.reduce(into: Data()) { $0.append($1) }
        let status = joined.withUnsafeBytes { raw -> OSStatus in
            guard let start = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return -1 }
            let pointers = [start, start.advanced(by: vps.count), start.advanced(by: vps.count + sps.count)]
            return CMVideoFormatDescriptionCreateFromHEVCParameterSets(allocator: kCFAllocatorDefault,
                parameterSetCount: 3, parameterSetPointers: pointers, parameterSetSizes: sets.map(\.count),
                nalUnitHeaderLength: 4, extensions: nil, formatDescriptionOut: &format)
        }
        guard status == noErr, let format else { return false }
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        return VTDecompressionSessionCreate(allocator: kCFAllocatorDefault, formatDescription: format,
            decoderSpecification: nil, imageBufferAttributes: attributes as CFDictionary,
            outputCallback: nil, decompressionSessionOut: &session) == noErr
    }

    private func invalidateSession() {
        if let session { VTDecompressionSessionInvalidate(session) }
        session = nil
        format = nil
    }
}

/// WebRTC supplies Annex B access units; Core Media expects four-byte NAL lengths.
nonisolated enum HEVCFramePayload {
    static func nalUnits(in data: Data) -> [Data]? {
        guard !data.isEmpty, data.count <= 16 * 1_024 * 1_024 else { return nil }
        return data.withUnsafeBytes { raw -> [Data]? in
            let bytes = raw.bindMemory(to: UInt8.self)
            var starts: [(prefix: Int, payload: Int)] = []
            var index = 0
            while index + 2 < bytes.count {
                if bytes[index] == 0, bytes[index + 1] == 0 {
                    if bytes[index + 2] == 1 {
                        starts.append((index, index + 3)); index += 3; continue
                    }
                    if index + 3 < bytes.count, bytes[index + 2] == 0, bytes[index + 3] == 1 {
                        starts.append((index, index + 4)); index += 4; continue
                    }
                }
                index += 1
            }
            guard let first = starts.first, bytes[..<first.prefix].allSatisfy({ $0 == 0 }) else { return nil }
            var units: [Data] = []
            for (offset, start) in starts.enumerated() {
                var end = offset + 1 < starts.count ? starts[offset + 1].prefix : bytes.count
                while end > start.payload, bytes[end - 1] == 0 { end -= 1 }
                guard end - start.payload >= 2 else { return nil }
                units.append(data.subdata(in: start.payload..<end))
            }
            return units
        }
    }

    static func lengthPrefixed(_ units: [Data]) -> Data? {
        guard !units.isEmpty else { return nil }
        var result = Data()
        for unit in units {
            guard unit.count >= 2, let count = UInt32(exactly: unit.count) else { return nil }
            var size = count.bigEndian
            withUnsafeBytes(of: &size) { result.append(contentsOf: $0) }
            result.append(unit)
        }
        return result
    }
}
