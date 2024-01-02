import std/[strformat, strutils]
import std/[os, cmdline, parseopt]
import std/[uri, htmlparser, xmltree]
import std/[typetraits]
import puppy
import nancy

func fetch(url: Uri): string =
  result = fetch($url)

proc download(url: Uri; to: string) =
  let content = fetch($url)
  writeFile(to, content)

proc printTable(list: seq[seq[string]]) =
  var table: TerminalTable
  for i in list:
    table.add i
  table.echoTableSeps(80, boxSeps)

type RepoId = enum
  all = ""
  main
  community
  testing

type ArchId = enum
  all = ""
  x86_64
  x86
  aarch64
  armhf
  ppc64le
  s390x
  armv7
  riscv64

type PageNo = 1 .. int.high()

type SearchParam = object
  page: PageNo = PageNo.low()
  name: string = ""
  branch: string = "edge"
  repo: RepoId = all
  arch: ArchId = all
  maintainer: string = ""

type DownloadParam = object
  outfile: string
  name: string
  repo: RepoId
  arch: ArchId

type PkgInfo = object
  name: string
  version: string
  project: string
  license: string
  branch: string
  repo: RepoId
  arch: ArchId
  maintainer: string
  buildDate: string

func nextPage(param: sink SearchParam): SearchParam =
  result = param
  param.page.inc()

func prevPage(param: sink SearchParam): SearchParam =
  result = param
  if param.page > PageNo.low():
    param.page.dec()

func toQueryString(param: SearchParam): string =
  result =
    fmt"page={param.page}&name={param.name.encodeUrl()}&branch={param.branch}&repo={param.repo}&arch={param.arch}&maintainer={param.maintainer.encodeUrl()}"

proc parsePkg(html: string): seq[PkgInfo] =
  result = @[]
  let dom = html.parseHtml()
  let tbody = dom.findAll("tbody")[0]
  for tr in tbody.findAll("tr"):
    let tdList = tr.findAll("td")
    result.add PkgInfo(
        name: tdList[0].findAll("a")[0].innerText().strip(),
        version: tdList[1].findAll("a")[0].innerText().strip(),
        project: tdList[2].findAll("a")[0].attr("href"),
        license: tdList[3].innerText().strip(),
        branch: tdList[4].innerText().strip(),
        repo: parseEnum[RepoId](tdList[5].findAll("a")[0].innerText().strip()),
        arch: parseEnum[ArchId](tdList[6].findAll("a")[0].innerText().strip()),
        maintainer: tdList[7].findAll("a")[0].innerText().strip(),
        buildDate: tdList[8].innerText().strip(),
      )

func getDownloadUrl(pkg: PkgInfo): Uri =
  result =
    parseUri fmt"http://dl-cdn.alpinelinux.org/alpine/{pkg.branch}/{pkg.repo}/{pkg.arch}/{pkg.name}-{pkg.version}.apk"

proc searchPkg(param: SearchParam): seq[PkgInfo] =
  let queryString = param.toQueryString()
  let url = parseUri ("https://pkgs.alpinelinux.org/packages?" & queryString)
  let html = fetch url
  result = parsePkg html

proc printPkg(pkgList: openArray[PkgInfo]) =
  var list = newSeq[seq[string]](pkgList.len() + 1)
  list[0] = @["name", "version", "repo", "arch", "buildDate"]
  for i, pkg in pkgList.pairs():
    for k, v in pkg.fieldPairs():
      if k in list[0]:
        list[i + 1].add $v
  printTable list

proc validate(param: DownloadParam) =
  if param.name == "":
    raise newException(ValueError, "name is required")
  if param.repo == all:
    raise newException(ValueError, "repo is required")
  if param.arch == all:
    raise newException(ValueError, "arch is required")

converter toSearchParam(param: DownloadParam): SearchParam =
  result.name = param.name
  result.repo = param.repo
  result.arch = param.arch

proc downloadPkg(pkg: PkgInfo; to: string) =
  var outfile = to
  if outfile == "":
    outfile = fmt"./{pkg.name}-{pkg.version}-{pkg.arch}.apk"
  download pkg.getDownloadUrl(), outfile

proc printHelp() =
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

type CommandId = enum
  notsupport
  cmdSearch
  cmdDownload

type Command = object
  case id: CommandId
  of notsupport:
    discard
  of cmdSearch:
    searchParam: SearchParam
  of cmdDownload:
    downloadParam: DownloadParam

proc run(command: Command) =
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

proc parseOpts(command: var Command; p: var OptParser) =
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

proc main() =
  let cmdParams = commandLineParams()

  if cmdParams.len() == 0:
    printHelp()
    quit(0)

  # 解析命令
  var command: Command =
    case cmdParams[0]
    of "search":
      Command(id: cmdSearch, searchParam: SearchParam())
    of "download":
      Command(id: cmdDownload, downloadParam: DownloadParam())
    else:
      Command(id: notsupport)

  # 解析选项
  var p = initOptParser cmdParams.join(" ")
  while true:
    p.next()
    case p.kind
    of cmdEnd:
      break
    of cmdShortOption, cmdLongOption:
      case p.key
      # 通用选项
      of "help":
        printHelp()
        quit(0)
      # 命令选项
      else:
        command.parseOpts(p)
    else:
      discard

  echo fmt"debug: {command = }"

  try:
    run command
  except:
    echo getCurrentExceptionMsg()

main()
