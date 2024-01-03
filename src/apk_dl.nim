import std/[strformat, strutils]
import std/[cmdline, parseopt]
import ./[command]

proc main() =
  let cmdParams = commandLineParams()

  if cmdParams.len() == 0:
    printHelp()
    quit(0)

  # 解析命令
  var command = parseCommand cmdParams[0]

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
