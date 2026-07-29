import Foundation

nonisolated struct HAUpdateReleaseNotesDocument: Equatable, Sendable {
    nonisolated enum Block: Equatable, Sendable {
        case heading(level: Int, text: String)
        case paragraph(String)
        case unorderedListItem(depth: Int, text: String)
        case orderedListItem(depth: Int, ordinal: Int, text: String)
        case quote(String)
        case code(String)
        case divider
    }

    let blocks: [Block]

    init(markdown: String) {
        blocks = Self.parse(markdown)
    }

    func omittingLeadingHeading(matching expectedHeading: String?) -> HAUpdateReleaseNotesDocument {
        guard let expectedHeading = expectedHeading?.trimmingCharacters(in: .whitespacesAndNewlines),
              !expectedHeading.isEmpty,
              let firstBlock = blocks.first,
              case .heading(_, let heading) = firstBlock,
              heading.compare(expectedHeading, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame else {
            return self
        }

        return HAUpdateReleaseNotesDocument(blocks: Array(blocks.dropFirst()))
    }

    private init(blocks: [Block]) {
        self.blocks = blocks
    }

    // Home Assistant release notes are Markdown. Keep the parsing surface small
    // and deterministic while preserving the structures commonly used by integrations.
    private static func parse(_ markdown: String) -> [Block] {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        var blocks: [Block] = []
        var paragraphLines: [String] = []
        var codeLines: [String] = []
        var isInsideCodeFence = false

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            blocks.append(.paragraph(paragraphLines.joined(separator: " ")))
            paragraphLines.removeAll(keepingCapacity: true)
        }

        func flushCode() {
            blocks.append(.code(codeLines.joined(separator: "\n")))
            codeLines.removeAll(keepingCapacity: true)
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if isInsideCodeFence {
                    flushCode()
                    isInsideCodeFence = false
                } else {
                    flushParagraph()
                    isInsideCodeFence = true
                }
                continue
            }

            if isInsideCodeFence {
                codeLines.append(line)
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
                continue
            }

            if let heading = heading(from: trimmed) {
                flushParagraph()
                blocks.append(heading)
                continue
            }

            if isDivider(trimmed) {
                flushParagraph()
                blocks.append(.divider)
                continue
            }

            if let listItem = unorderedListItem(from: line) {
                flushParagraph()
                blocks.append(listItem)
                continue
            }

            if let listItem = orderedListItem(from: line) {
                flushParagraph()
                blocks.append(listItem)
                continue
            }

            if trimmed.hasPrefix(">") {
                flushParagraph()
                let text = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                blocks.append(.quote(text))
                continue
            }

            if leadingWhitespaceCount(in: line) > 0,
               let lastBlock = blocks.last,
               let continuedBlock = lastBlock.appendingContinuation(trimmed) {
                blocks[blocks.count - 1] = continuedBlock
                continue
            }

            paragraphLines.append(trimmed)
        }

        if isInsideCodeFence {
            flushCode()
        } else {
            flushParagraph()
        }

        return blocks
    }

    private static func heading(from line: String) -> Block? {
        let markerCount = line.prefix { $0 == "#" }.count
        guard (1...6).contains(markerCount) else { return nil }

        let contentStart = line.index(line.startIndex, offsetBy: markerCount)
        guard contentStart < line.endIndex, line[contentStart].isWhitespace else {
            return nil
        }

        let text = line[contentStart...].trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return .heading(level: markerCount, text: text)
    }

    private static func unorderedListItem(from line: String) -> Block? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let marker = trimmed.first,
              ["-", "*", "+"].contains(marker),
              trimmed.dropFirst().first?.isWhitespace == true else {
            return nil
        }

        let text = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return .unorderedListItem(depth: listDepth(for: line), text: text)
    }

    private static func orderedListItem(from line: String) -> Block? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let periodIndex = trimmed.firstIndex(of: ".") else { return nil }

        let ordinalText = trimmed[..<periodIndex]
        guard !ordinalText.isEmpty,
              ordinalText.allSatisfy(\.isNumber),
              let ordinal = Int(ordinalText) else {
            return nil
        }

        let contentStart = trimmed.index(after: periodIndex)
        guard contentStart < trimmed.endIndex, trimmed[contentStart].isWhitespace else {
            return nil
        }

        let text = trimmed[contentStart...].trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return .orderedListItem(depth: listDepth(for: line), ordinal: ordinal, text: text)
    }

    private static func isDivider(_ line: String) -> Bool {
        let compact = line.filter { !$0.isWhitespace }
        guard compact.count >= 3, let marker = compact.first else { return false }
        return ["-", "*", "_"].contains(marker) && compact.allSatisfy { $0 == marker }
    }

    private static func listDepth(for line: String) -> Int {
        leadingWhitespaceCount(in: line) / 2
    }

    private static func leadingWhitespaceCount(in line: String) -> Int {
        line.prefix(while: \.isWhitespace).count
    }
}

private extension HAUpdateReleaseNotesDocument.Block {
    nonisolated func appendingContinuation(_ continuation: String) -> Self? {
        switch self {
        case .unorderedListItem(let depth, let text):
            return .unorderedListItem(depth: depth, text: "\(text) \(continuation)")
        case .orderedListItem(let depth, let ordinal, let text):
            return .orderedListItem(depth: depth, ordinal: ordinal, text: "\(text) \(continuation)")
        default:
            return nil
        }
    }
}
