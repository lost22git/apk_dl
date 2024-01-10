import ./[util]
import std/[strformat, strutils]
import std/[typetraits]
import std/[uri, htmlparser, xmltree]

type
  RepoId* = enum
    all = ""
    main
    community
    testing

type
  ArchId* = enum
    all = ""
    x86_64
    x86
    aarch64
    armhf
    ppc64le
    s390x
    armv7
    riscv64

converter toArchId*(str: string): ArchId =
  result = parseEnum[ArchId](str)

converter toRepoId*(str: string): RepoId =
  result = parseEnum[RepoId](str)

type PageId* = 1..int.high()

converter toPageId*(str: string): PageId =
  result = PageId(str.parseInt())

type
  SearchParam* = object
    page* {.option.}: PageId = PageId.low()
    name* {.option.}: string = ""
    branch*: string = "edge"
    repo* {.option.}: RepoId = all
    arch* {.option.}: ArchId = all
    maintainer*: string = ""

type
  DownloadParam* = object
    outfile* {.option.}: string
    name* {.option.}: string
    repo* {.option.}: RepoId
    arch* {.option.}: ArchId

type
  PkgInfo* = object
    name*: string
    version*: string
    project*: string
    license*: string
    branch*: string
    repo*: RepoId
    arch*: ArchId
    maintainer*: string
    buildDate*: string

func nextPage(param: sink SearchParam): SearchParam =
  result = param
  param.page.inc()

func prevPage(param: sink SearchParam): SearchParam =
  result = param
  if param.page > PageId.low():
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
      repo: tdList[5].findAll("a")[0].innerText().strip(),
      arch: tdList[6].findAll("a")[0].innerText().strip(),
      maintainer: tdList[7].findAll("a")[0].innerText().strip(),
      buildDate: tdList[8].innerText().strip(),
    )

func getDownloadUrl*(pkg: PkgInfo): Uri =
  result =
    parseUri fmt"http://dl-cdn.alpinelinux.org/alpine/{pkg.branch}/{pkg.repo}/{pkg.arch}/{pkg.name}-{pkg.version}.apk"

proc searchPkg*(param: SearchParam): seq[PkgInfo] =
  let queryString = param.toQueryString()
  let url = parseUri ("https://pkgs.alpinelinux.org/packages?" & queryString)
  let html = fetch url
  result = parsePkg html

proc printPkg*(pkgList: openArray[PkgInfo]) =
  var list = newSeq[seq[string]](pkgList.len() + 1)
  list[0] = @["name", "version", "repo", "arch", "buildDate"]
  for i, pkg in pkgList.pairs():
    for k, v in pkg.fieldPairs():
      if k in list[0]:
        list[i + 1].add $v
  printTable list

proc validate*(param: DownloadParam) =
  if param.name == "":
    raise newException(ValueError, "name is required")
  if param.repo == all:
    raise newException(ValueError, "repo is required")
  if param.arch == all:
    raise newException(ValueError, "arch is required")

converter toSearchParam*(param: DownloadParam): SearchParam =
  result.name = param.name
  result.repo = param.repo
  result.arch = param.arch

proc downloadPkg*(pkg: PkgInfo, to: string) =
  var outfile = to
  if outfile == "":
    outfile = fmt"./{pkg.name}-{pkg.version}-{pkg.arch}.apk"
  download pkg.getDownloadUrl(), outfile
