import Foundation

@main
struct MetalSourceGenerator {
  static func main() throws {
    guard CommandLine.arguments.count == 3 else {
      print(
        """
        MetalSourceGenerator is an internal Chroma build tool and is not a demo.

        Run the local demo:
          swift run --package-path Example -c release ChromaDemo

        Or run the same demo remotely in two terminals:
          swift run --package-path Example -c release RemoteDemoDaemon
          swift run --package-path Example -c release RemoteDemoClient
        """
      )
      return
    }

    let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
    let source = try String(contentsOf: inputURL, encoding: .utf8)

    var hashes = "#"
    while source.contains("\"\"\"\(hashes)") || source.contains("\\\(hashes)(") {
      hashes += "#"
    }

    let generated = """
      // Generated from \(inputURL.lastPathComponent) by MetalSourcePlugin. Do not edit.
      let metalSource = \(hashes)\"\"\"
      \(source)\(source.hasSuffix("\n") ? "" : "\n")\"\"\"\(hashes)

      """

    try FileManager.default.createDirectory(
      at: outputURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try generated.write(to: outputURL, atomically: true, encoding: .utf8)
  }
}

enum GeneratorError: Error, CustomStringConvertible {
  case usage

  var description: String {
    "usage: MetalSourceGenerator <input.metal> <output.swift>"
  }
}
