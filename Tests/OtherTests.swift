import Testing

@testable import SwiftWayland
@testable import Wayland

@Test func cloudFlare() async {
  let ips = await getIps()
  #expect(ips.count > 0)
  #expect(ips.allSatisfy { $0.contains(".") })
}

@Test func hashing() async {
  let chromaHash = hash("Chroma")
  #expect(chromaHash == 4_247_990_530_641_679_754)

  let chromaHash2 = hash("Chroma")
  #expect(chromaHash == chromaHash2)

  let rehash = hash(chromaHash)
  #expect(chromaHash != rehash)
}
