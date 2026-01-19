import Testing

@testable import ShapeTree
@testable import SwiftWayland
@testable import Wayland

@Suite("Network and Utility Tests")
struct NetworkAndUtilityTests {

  @Test("CloudFlare IP lookup")
  func cloudFlare() async {
    let ips = await getIps()
    #expect(ips.count > 0, "Should return at least one IP address")
    #expect(ips.allSatisfy { $0.contains(".") }, "All IPs should contain dots")
  }

  @Test("Hash function consistency")
  func hashing() async {
    let chromaHash = hash("Chroma")
    #expect(chromaHash == 4_247_990_530_641_679_754, "Hash should match expected value")

    let chromaHash2 = hash("Chroma")
    #expect(chromaHash == chromaHash2, "Same input should produce same hash")

    let rehash = hash(chromaHash)
    #expect(chromaHash != rehash, "Hashing a hash should produce different result")

    // Test edge cases
    #expect(hash("") != hash(" "), "Empty string should hash differently from space")
    #expect(hash("a") != hash("A"), "Case sensitivity should be preserved")
  }
}
