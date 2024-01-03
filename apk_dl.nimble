# Package

version = "0.1.0"
author = "lost22git"
description = "alpine package downloader cli"
license = "MIT"
srcDir = "src"
binDir = "target"
bin = @["apk_dl"]

# Dependencies

requires "nim >= 2.0.2", "puppy", "nancy"
