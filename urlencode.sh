#!/usr/bin/env bash
#
# urlencode - codificando sua string para usar em URLs
# source: https://meleu.sh/urlencode/

urlencode() {
  local LC_ALL=C
  local string="$*"
  local length="${#string}"
  local char

  for (( i = 0; i < length; i++ )); do
    char="${string:i:1}"
    if [[ "$char" == [a-zA-Z0-9.~_-] ]]; then
      printf "$char" 
    else
      printf '%%%02X' "'$char" 
    fi
  done
}

urlencode "$@"
