import ./[domain]
import std/[strutils]
import std/[parseopt]

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

proc parseOpts*(command: var Command; p: var OptParser) =
  case command.id
  of cmdSearch:
    case p.key
    of "page":
      command.searchParam.page = p.val.parseInt()
    of "name":
      command.searchParam.name = p.val
    of "repo":
      command.searchParam.repo = parseEnum[RepoId](p.val)
    of "arch":
      command.searchParam.arch = parseEnum[ArchId](p.val)
    else:
      discard
  of cmdDownload:
    case p.key
    of "name":
      command.downloadParam.name = p.val
    of "repo":
      command.downloadParam.repo = parseEnum[RepoId](p.val)
    of "arch":
      command.downloadParam.arch = parseEnum[ArchId](p.val)
    else:
      discard
  else:
    discard
