import Testing
@testable import Homestead

struct CameraICEDiagnosticsTests {
    @Test(arguments: [
        ("10.1.2.3", "ipv4/private"), ("172.31.0.1", "ipv4/private"),
        ("192.168.0.1", "ipv4/private"), ("100.64.0.1", "ipv4/shared"),
        ("169.254.1.2", "ipv4/link-local"), ("127.0.0.1", "ipv4/loopback"),
        ("192.0.2.1", "ipv4/documentation"), ("203.0.113.1", "ipv4/documentation"),
        ("0.0.0.0", "ipv4/unspecified"), ("224.0.0.1", "ipv4/multicast-or-reserved"),
        ("8.8.8.8", "ipv4/other"), ("2001:db8::1", "ipv6/documentation"),
        ("fe80::1", "ipv6/link-local"), ("fd12::1", "ipv6/private"),
        ("::1", "ipv6/loopback"), ("::", "ipv6/unspecified"), ("ff02::1", "ipv6/multicast"),
        ("::ffff:192.168.1.1", "ipv4-mapped/private"),
        ("2001:4860:4860::8888", "ipv6/other"),
        ("secret.local", "name/mdns"), ("secret.example", "name/unknown")
    ])
    func candidateAddressesBecomeOnlyAllowlistedCategories(address: String, category: String) {
        let summary = CameraICECandidateSummary.describe(type: "host", transport: "TCP", address: address)
        #expect(summary == "host/tcp/\(category)/unknown")
        #expect(!summary.contains(address))
    }

    @Test func tcpCandidateRolesStayAllowlisted() {
        #expect(CameraICECandidateSummary.describe("candidate:secret 1 tcp 123 fd12::1 54321 typ host tcptype active") == "host/tcp/ipv6/private/active")
        #expect(CameraICECandidateSummary.describe("candidate:secret 1 tcp 123 10.0.0.1 54321 typ host tcptype passive") == "host/tcp/ipv4/private/passive")
        #expect(CameraICECandidateSummary.describe("candidate:secret 1 tcp 123 10.0.0.1 54321 typ host tcptype secret") == "host/tcp/ipv4/private/unknown")
    }

    @Test func unknownStatisticsFieldsCannotBecomeLogContent() {
        #expect(CameraICECandidateSummary.describe(type: "secret", transport: "password", address: nil) == "unknown/unknown/unknown")
    }

    #if DEBUG
    @Test func candidateBurstStaysInCountersWithoutRawPayloads() {
        var diagnostics = CameraICECandidateDiagnostics()
        let candidate = "candidate:secret 1 tcp 123 fe80::1234 54321 typ host ufrag password"
        for _ in 0..<10_000 { diagnostics.append(candidate, direction: .remote) }
        diagnostics.didAcknowledge()
        let summary = diagnostics.summary
        #expect(summary.contains("total 10000"))
        #expect(summary.contains("unique 1,"))
        #expect(summary.contains("host/tcp/ipv6/link-local/unknown=10000"))
        #expect(summary.contains("acknowledged 1"))
        #expect(!summary.contains("secret") && !summary.contains("password"))
        #expect(!summary.contains("fe80::1234") && !summary.contains("54321"))
        #expect(summary.count < 350)
    }

    @Test func embeddedAndTrickleCandidatesShareUniqueCountAndStaySeparateByDirection() {
        var diagnostics = CameraICECandidateDiagnostics()
        let candidate = "candidate:secret 1 udp 123 192.0.2.1 54321 typ srflx"
        diagnostics.appendSDP("v=0\r\na=ice-pwd:secret\r\na=\(candidate)\r\n", direction: .remote)
        diagnostics.append(candidate, direction: .remote)
        diagnostics.append(candidate, direction: .local)
        let summary = diagnostics.summary
        #expect(summary.contains("local [total 1, SDP 0"))
        #expect(summary.contains("remote [total 2, SDP 1"))
        #expect(!summary.contains("secret") && !summary.contains("192.0.2.1"))
        #expect(!summary.contains("unique 2"))
        #expect(CameraICECandidateDiagnostics().summary.contains("remote [total 0"))
    }

    @Test func fingerprintStorageIsBounded() {
        var diagnostics = CameraICECandidateDiagnostics()
        for i in 0..<1_000 {
            diagnostics.append("candidate:\(i) 1 udp 123 192.0.2.1 54321 typ host", direction: .remote)
        }
        #expect(diagnostics.summary.contains("unique 512+"))
        #expect(diagnostics.summary.contains("total 1000"))
        #expect(diagnostics.summary.count < 350)
    }
    #endif
}
