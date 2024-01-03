import std/[uri]
import puppy
import nancy

func fetch*(url: Uri): string =
  result = fetch($url)

proc download*(url: Uri; to: string) =
  let content = fetch($url)
  writeFile(to, content)

proc printTable*(list: seq[seq[string]]) =
  var table: TerminalTable
  for i in list:
    table.add i
  table.echoTableSeps(80, boxSeps)
