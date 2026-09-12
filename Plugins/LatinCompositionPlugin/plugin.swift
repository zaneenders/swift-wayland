import PackagePlugin

@main
struct LatinCompositionPlugin: BuildToolPlugin {
  func createBuildCommands(
    context: PluginContext,
    target: Target
  ) async throws -> [Command] {
    let generator = try context.tool(named: "LatinCompositionGenerator")
    let output = context.pluginWorkDirectoryURL.appendingPathComponent("LatinCompositions.swift")
    return [
      .buildCommand(
        displayName: "Generating Latin bitmap compositions",
        executable: generator.url,
        arguments: [output.path],
        // The repertoire and mark patterns are compiled into the generator.
        // Track the executable explicitly so tool changes invalidate the output.
        inputFiles: [generator.url],
        outputFiles: [output]
      )
    ]
  }
}
