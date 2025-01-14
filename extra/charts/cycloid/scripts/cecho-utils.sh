#!/usr/bin/bash
# shellcheck shell=sh

# INFO: this script come from https://github.com/cycloidio/docker-cycloid-toolkit/blob/develop/scripts/cecho-utils

# Usage: source /usr/bin/cecho-utils
# Then you can call predefined
#  * pwarning "message"
#  * perror "message"
#  * pinfo "message"
#
# Or directly use cecho with the following args
#
# The following function prints a text using custom color
# -c or --color define the color for the print. See the array colors for the available options.
# -n or --noline directs the system not to print a new line after the content.
# Last argument is the message to be printed.

cecho() {
  current_xtrace_enabled=${-//[^x]/}
  set +x
  xtrace_enabled="${xtrace_enabled:-$current_xtrace_enabled}"

  defaultMSG="No message passed."
  defaultColor="black"
  defaultNewLine=true

  while [ $# -gt 1 ]; do
    key="$1"

    case $key in
    -c | --color)
      color="$2"
      shift
      ;;
    -n | --noline)
      newLine=false
      ;;
    *)
      # unknown option
      ;;
    esac
    shift
  done

  message=${1:-$defaultMSG} # Defaults to default message.
  case ${color-$defaultColor} in
  black) color='\E[0;47m' ;;
  red) color='\E[0;31m' ;;
  green) color='\E[0;32m' ;;
  yellow) color='\E[0;33m' ;;
  blue) color='\E[0;34m' ;;
  magenta) color='\E[0;35m' ;;
  cyan) color='\E[0;36m' ;;
  white) color='\E[0;37m' ;;
  esac

  newLine=${newLine:-$defaultNewLine}

  printf "$color%s" "$message"
  if [ "$newLine" = true ]; then
    echo
  fi
  tput -T xterm-256color sgr0 #  Reset text attributes to normal without clearing screen.

  if [ -n "$xtrace_enabled" ]; then set -x; else set +x; fi
  return
}
pwarning() {
  xtrace_enabled=${-//[^x]/}
  set +x
  cecho -c 'yellow' "$@"
  if [ -n "$xtrace_enabled" ]; then set -x; else set +x; fi
}

perror() {
  xtrace_enabled=${-//[^x]/}
  set +x
  cecho -c 'red' "$@"
  if [ -n "$xtrace_enabled" ]; then set -x; else set +x; fi
}

pinfo() {
  xtrace_enabled=${-//[^x]/}
  set +x
  cecho -c 'blue' "$@"
  if [ -n "$xtrace_enabled" ]; then set -x; else set +x; fi
}

psuccess() {
  xtrace_enabled=${-//[^x]/}
  set +x
  cecho -c 'green' "$@"
  if [ -n "$xtrace_enabled" ]; then set -x; else set +x; fi
}
