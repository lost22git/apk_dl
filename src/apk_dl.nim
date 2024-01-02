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
  main
  community
  testing

type ArchId = enum
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
  repo: RepoId = main
  arch: ArchId = x86_64
  maintainer: string = ""

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
    fmt"http://dl-cdn.alpinelinux.org/alpine/latest-stable/{pkg.repo}/{pkg.arch}/{pkg.name}-{pkg.version}.apk".parseUri()

proc searchPkg(param: SearchParam): seq[PkgInfo] =
  let queryString = param.toQueryString()
  let url = parseUri ("https://pkgs.alpinelinux.org/packages?" & queryString)
  let html = fetch url
  result = parsePkg html

proc downloadPkg(pkg: PkgInfo; to: string) =
  pkg.getDownloadUrl().download(to)

proc printPkg(pkgList: openArray[PkgInfo]) =
  var list = newSeq[seq[string]](pkgList.len())
  for i, pkg in pkgList.pairs():
    for _, v in pkg.fieldPairs():
      list[i].add $v
  printTable list

proc printHelp() =
  echo """
  Search alpine linux packages

  Usage:
  apk_dl <command> [options]
 
  Commmand:
  search

  Common option:
  --help
  --version

  Search option:
  --page=[1..] (default:1)
  --name=[keyword, wildcards: '?' '*'] (default:"")
  --branch=[edge|v3.19] (default:edge)
  --repo=[main|community|testing] （default:main)
  --arch=[x86_64|x86|aarch64|armhf|ppc64le|s390x|armv7|riscv64] (default:x86_64)
  """

type CommandId = enum
  notsupport
  search

type Command = object
  case id: CommandId
  of notsupport:
    discard
  of search:
    opts: SearchParam

proc run(command: Command) =
  case command.id
  of notsupport:
    printHelp()
    quit(0)
  of search:
    let pkgList = searchPkg command.opts
    printPkg pkgList

proc parseOpts(searchParam: var SearchParam; p: var OptParser) =
  case p.key
  of "page":
    searchParam.page = p.val.parseInt()
  of "name":
    searchParam.name = p.val
  of "branch":
    searchParam.branch = p.val
  of "repo":
    searchParam.repo = parseEnum[RepoId](p.val)
  of "arch":
    searchParam.arch = parseEnum[ArchId](p.val)
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
      Command(id: search, opts: SearchParam())
    else:
      Command(id: notsupport)

  # 解析选项
  var p = initOptParser cmdParams.join(" ")
  while true:
    p.next()
    case p.kind
    of cmdEnd:
      break
    of cmdLongOption:
      case p.key
      # 通用选项
      of "help":
        printHelp()
        quit(0)
      # 命令选项
      else:
        case command.id
        of search:
          command.opts.parseOpts(p)
        else:
          discard
    else:
      discard

  echo fmt"debug: {command = }"

  try:
    run command
  except:
    echo getCurrentExceptionMsg()

main()
