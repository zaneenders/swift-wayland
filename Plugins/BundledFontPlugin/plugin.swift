import PackagePlugin

@main
struct BundledFontPlugin: BuildToolPlugin {
  func createBuildCommands(
    context: PluginContext,
    target: Target
  ) async throws -> [Command] {
    let generator = try context.tool(named: "BundledFontGenerator")
    let input = target.directoryURL.appendingPathComponent("FontData/BundledFont.rle")
    let output = context.pluginWorkDirectoryURL.appendingPathComponent("BundledFont.swift")
    return [
      .buildCommand(
        displayName: "Generating bundled font coverage",
        executable: generator.url,
        arguments: [input.path, output.path],
        inputFiles: [generator.url, input],
        outputFiles: [output]
      )
    ]
  }
}
