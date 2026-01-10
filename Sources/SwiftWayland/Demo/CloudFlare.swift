import AsyncHTTPClient
import Foundation

struct CloudflareIPResponse: Decodable {
  let result: IPResult
  let success: Bool
  let errors: [APIError]
  let messages: [String]

  struct IPResult: Decodable {
    let ipv4Cidrs: [String]
    let ipv6Cidrs: [String]
    let etag: String

    enum CodingKeys: String, CodingKey {
      case ipv4Cidrs = "ipv4_cidrs"
      case ipv6Cidrs = "ipv6_cidrs"
      case etag
    }
  }

  struct APIError: Decodable {
    let code: Int?
    let message: String?
  }
}

func getIps() async -> [String] {
  let start = ContinuousClock.now
  let url = "https://api.cloudflare.com/client/v4/ips"
  let request = HTTPClientRequest(url: url)
  guard let response = try? await HTTPClient.shared.execute(request, timeout: .seconds(5)) else {
    print("ERRROR")
    return []
  }
  guard let buffer = try? await response.body.collect(upTo: .max) else {
    print("Unable to collect")
    return []
  }
  let body = String(buffer: buffer)
  guard response.status == .ok else {
    print("status: \(response.status)")
    print("body: \(body)")
    return []
  }
  guard let data = try? JSONDecoder().decode(CloudflareIPResponse.self, from: body.data(using: .utf8)!) else {
    print("IDK")
    return []
  }
  let ips = data.result.ipv4Cidrs
  let end = ContinuousClock.now
  print("Request time:", start.duration(to: end))
  return ips
}
