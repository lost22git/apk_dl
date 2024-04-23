import ./[domain, util]
import std/[parseopt]
import std/[macros]

proc printHelp*() =
  echo """
  Search alpine linux packages

  Usage:
    apk_dl <command> [options]
 
  Commmands:
    search
    download

  Common options:
    --help
    --version

  Search options:
    --page=[1..] (default:1)
    --name=[keyword, wildcards: '?' '*'] (default:"")
    --repo=[main|community|testing] (default:"")
    --arch=[x86_64|x86|aarch64|armhf|ppc64le|s390x|armv7|riscv64] (default:"")

  Download options:
    --name=[fullname] (Mandatory)
    --repo=[main|community|testing] (Mandatory)
    --arch=[x86_64|x86|aarch64|armhf|ppc64le|s390x|armv7|riscv64] (Mandatory)
  """

type CommandId* = enum
  notsupport
  cmdSearch
  cmdDownload

type Command* = object
  case id*: CommandId
  of notsupport:
    discard
  of cmdSearch:
    searchParam*: SearchParam
  of cmdDownload:
    downloadParam*: DownloadParam

proc run*(command: Command) =
  case command.id
  of notsupport:
    printHelp()
    quit(0)
  of cmdSearch:
    let param: SearchParam = command.searchParam
    echo "searching..." & $param
    let pkgList = searchPkg param
    printPkg pkgList
  of cmdDownload:
    let param: DownloadParam = command.downloadParam
    validate param
    let pkgList = searchPkg param
    if pkgList.len() == 1:
      let pkg = pkgList[0]
      echo "downloading..." & $(pkg.getDownloadUrl())
      downloadPkg pkg, param.outfile
      echo "download finished!"
    else:
      echo "can not download since multiple packages matched"
      printPkg pkgList

func parseCommand*(command: string): Command =
  result =
    case command
    of "search":
      Command(id: cmdSearch, searchParam: SearchParam())
    of "download":
      Command(id: cmdDownload, downloadParam: DownloadParam())
    else:
      Command(id: notsupport)

proc parseOpts*(command: var Command, p: var OptParser) =
  template parse(param: typed) =
    for k, v in param.fieldPairs():
      when v.hasCustomPragma(option):
        if k == p.key:
          v = p.val
          break

  case command.id
  of cmdSearch:
    parse command.searchParam
  of cmdDownload:
    parse command.downloadParam
  else:
    discard
