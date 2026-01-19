import PackagePlugin

@main
struct ShaderGeneratorPlugin: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    // This plugin should only run for the Wayland target
    guard target.name == "Wayland" else { return [] }

    // Paths for the shader files and output
    let packageDirectory = context.package.directory
    let shadersDirectory = packageDirectory.appending("shaders")
    let outputFile = context.pluginWorkDirectory.appending("Shaders.swift")

    // Get the generator tool
    let generatorTool = try context.tool(named: "ShaderGeneratorTool")

    return [
      .buildCommand(
        displayName: "Generating shader strings",
        executable: generatorTool.path,
        arguments: [
          packageDirectory.string,
          outputFile.string,
          shadersDirectory.string,
        ],
        inputFiles: [
          shadersDirectory.appending("vertex.glsl"),
          shadersDirectory.appending("fragment.glsl"),
        ],
        outputFiles: [outputFile]
      )
    ]
  }
}
