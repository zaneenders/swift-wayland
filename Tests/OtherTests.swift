import Testing

@testable import SwiftWayland

@Test func cloudFlare() async {
  let ips = await getIps()
  print(ips)
}
