import PackagePlugin

@main
struct ShaderGeneratorPlugin: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {

    guard target.name == "Wayland" else { return [] }

    let packageDirectory = context.package.directory
    let shadersDirectory = packageDirectory.appending("shaders")
    let outputFile = context.pluginWorkDirectory.appending("Shaders.swift")

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
