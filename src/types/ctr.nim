import os
import strutils
import strformat

import console
export console

import ../configure
import ../strings

const TextureCommand = """tex3ds "$1" --format=rgba8888 -z=auto --border -o "$2.t3x""""
const FontCommand = """mkbcfnt "$1" -o "$2.bcfnt""""

const SmdhCommand = """smdhtool --create "$1" "$2" "$3" "$4" "$5.smdh""""
const BinaryCommand = """3dsxtool "$1" "$2.3dsx" --smdh="$2.smdh""""

const Textures = @[".png", ".jpg", ".jpeg"]
const Fonts = @[".ttf", ".otf"]

type
    Ctr* = ref object of ConsoleBase

proc getBinaryExtension*(self: Ctr): string = "3dsx"
proc getConsoleName*(self: Ctr): string = "Nintendo 3DS"
proc getElfBinaryName*(self: Ctr): string = "3ds.elf"
proc getIconExtension*(self: Ctr): string = "png"

proc convertFiles(self: Ctr, source: string): bool =
    let outputName = console.getRomFSDirectory()

    for path in os.walkDirRec(source, relative = true):
        if os.isHidden(path):
            continue

        let (dir, name, extension) = os.splitFile(path)

        let relativePath = fmt("{source}/{path}")
        let destination = fmt("{outputName}/{dir}")

        try:
            os.createDir(destination)

            let destinationPath = fmt("{destination}/{name}")

            if extension in Textures:
                console.runCommand(TextureCommand.format(relativePath,
                        destinationPath))
            elif extension in Fonts:
                console.runCommand(FontCommand.format(relativePath,
                        destinationPath))
            else:
                os.copyFileToDir(relativePath, destination)
        except Exception:
            return false

    return true

proc publish*(self: Ctr) =
    if not self.convertFiles(config.source):
        return

    let elfBinaryPath = self.getElfBinaryPath()

    if not os.fileExists(elfBinaryPath) and not config.rawData:
        raise newException(Exception, strings.ElfBinaryNotFound.format(
                config.name, self.getConsoleName(), self.getElfBinaryName(),
                config.binSearchPath))

    let properDescription = fmt("{config.description} • {config.version}")
    let tempBinaryPath = self.getTempMetadataBinaryPath()

    try:
        # Output LOVEPotion.smdh to `build` directory
        console.runCommand(SmdhCommand.format(config.name, properDescription,
                config.author, self.getIcon(), tempBinaryPath))

        # Output LOVEPotion.3dsx to `build` directory
        console.runCommand(BinaryCommand.format(self.getElfBinaryPath(),
                tempBinaryPath))
    except Exception as e:
        echo(e.msg)
        return

    self.packGameDirectory(fmt("{config.outputName}/"))
