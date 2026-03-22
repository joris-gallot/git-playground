#!/usr/bin/env bash

set -euo pipefail

NAME="Reviu"
TARGET_DIR="${HOME}/workspace"

say_hello() {
  local who="${1:-world}"
  echo "Hello ${who} from ${NAME}"
}

if [[ -d "$TARGET_DIR" ]]; then
  echo "Listing $(basename "$TARGET_DIR")"
  for entry in "$TARGET_DIR"/*; do
    [[ -e "$entry" ]] || continue
    printf '%s\n' "$entry"
  done
else
  echo "Missing directory: $TARGET_DIR" >&2
fi

case "${1:-status}" in
  status)
    say_hello "bash"
    ;;
  clean)
    unset NAME
    export TARGET_DIR="/tmp"
    ;;
  *)
    echo "Unknown command: $1"
    ;;
esac
