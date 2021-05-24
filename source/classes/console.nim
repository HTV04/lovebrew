import osproc, strformat, strutils, os, times
import iface

import ../config/configfile
import ../assets

import zippy/ziparchives

type ConsoleBase* = ref object of RootObj
    name*        : string
    author*      : string
    description* : string
    version*     : string

proc getProjectName(self: ConsoleBase): string = self.name

iface *Console:
    proc getName() : string
    proc getProjectName() : string
    proc publish(source: string) : bool
    proc getBinaryName() : string
    proc getIconExtension() : string
    proc getExtension() : string

var buildOptions  : tuple[clean: bool, source: string, icon: string, binSearchPath: string]
var outputOptions : tuple[buildPath : string, romFS : string]

proc initVariables*() =
    buildOptions  = Config.getBuildOptions()
    outputOptions = Config.getOutputOptions()
    echo buildOptions.binSearchPath

proc runCommand*(command : string) =
    ## Runs a specified command

    var commandResult = execCmdEx(command)

    if commandResult.exitCode != 0:
        echo(fmt("\nError Code {commandResult.exitCode}: {commandResult.output}"))


proc getBinarySearchPath() : string =
    ## Returns the search path of the expected ELF binary

    return buildOptions.binSearchPath

proc getBinaryPath*(self : Console) : string =
    ## Returns the full path and name of the ELF binary

    return fmt("{getBinarySearchPath()}/{self.getBinaryName()}")

proc getRomFSDirectory*() : string =
    ## Returns the relative directory to use as the romFS directory
    ## It gets appended to the build directory

    let buildDirectory = outputOptions.buildPath
    let romfsDirectory = outputOptions.romFS

    return fmt("{buildDirectory}/{romfsDirectory}")

proc getBuildDirectory*() : string =
    ## Returns the build directory, relative to the project root

    return outputOptions.buildPath

proc preBuildCleanup*() =
    if not buildOptions.clean:
        return

    let extensions = @[".3dsx", ".nro"]

    for _, path in walkDir(getBuildDirectory(), relative = true):
        let (_, _, extension) = splitFile(path)

        if (extension in extensions):
            removeFile(path)

proc postBuildCleanup() =
    let extensions = @[".smdh", ".nacp"]

    for _, path in walkDir(getBuildDirectory(), relative = true):
        let (_, name, extension) = splitFile(path)

        if (extension in extensions) or ("SuperGame" in name):
            removeFile(path)


proc getOutputName*(self : Console) : string =
    ## Returns the filename (with extension)

    return fmt("{self.getProjectName()}.{self.getExtension()}")

proc getBuildBinary*(self : Console) : string =
    ## Returns build binay name (with extension)

    return fmt("{getBuildDirectory()}/SuperGame.{self.getExtension()}")

proc getOutputPath*(self : Console) : string =
    ## Returns the output filename relative to the build directory

    return fmt("{getBuildDirectory()}/{self.getOutputName()}")

proc packGameDirectory*(self: Console, source : string) : bool =
    ## Pack the game directory into the binary data

    write(stdout, "Packing game content.. please wait.. ")
    flushFile(stdout)

    let start = getTime()

    let romFS = fmt("{getRomFSDirectory()}.love")
    let sourceDirectory = fmt("{source}/")

    let binaryPath = self.getBuildBinary()

    try:
        createZipArchive(sourceDirectory, romFS)

        # Run the command to append the zip data to the binary
        var command = fmt("$1 '{binaryPath}' $2 '{romFS}' $3 '{self.getOutputPath()}'")

        when defined(Windows):
            runCommand(command.format("copy /b", "+", ""))
        when defined(MacOS) or defined(MacOSX) or defined(Linux):
            runCommand(command.format("cat", "", ">"))

        postBuildCleanup()

        removeFile(romFS)
    except Exception as e:
        echo(e.msg)
        return false

    let delta = (getTime() - start).inSeconds()
    echo(fmt("done in {delta}s"))

    return true

proc getIcon*(self : Console) : string =
    ## Returns the relative path to the icon for the project.
    ## If one isn't found, it uses the default icon.

    var extension = self.getIconExtension()

    let path = buildOptions.icon
    let filename = fmt("{path}.{extension}")

    if not filename.fileExists():
        writeFile(filename, getAsset(fmt("icon.{extension}")))

    return filename
