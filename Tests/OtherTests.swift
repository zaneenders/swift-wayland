import Testing

@testable import SwiftWayland
@testable import Wayland

@Test func cloudFlare() async {
  let ips = await getIps()
  #expect(ips.count > 0)
}

@Test func hashing() async {
  let hash = hash("Chroma")
  #expect(hash == 4_247_990_530_641_679_754)
}
