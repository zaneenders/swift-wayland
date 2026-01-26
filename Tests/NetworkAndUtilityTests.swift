import Testing

@testable import ShapeTree
@testable import SwiftWayland
@testable import Wayland

@Suite struct NetworkAndUtilityTests {

  @Test
  func cloudFlare() async {
    let ips = await getIps()
    #expect(ips.count > 0)
    #expect(ips.allSatisfy { $0.contains(".") })
  }

  @Test
  func hashing() async {
    let chromaHash = hash("ShapeTree")
    #expect(chromaHash == 17_125_067_097_633_046_526)

    let chromaHash2 = hash("ShapeTree")
    #expect(chromaHash == chromaHash2)

    let rehash = hash(chromaHash)
    #expect(chromaHash != rehash)

    // Test edge cases
    #expect(hash("") != hash(" "))
    #expect(hash("a") != hash("A"))
  }
}
