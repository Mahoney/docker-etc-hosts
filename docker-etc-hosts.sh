#! /usr/bin/env bash

# Set home so docker doesn't moan
export HOME="${HOME:-/var/root}"

main() {
  set -euo pipefail
  IFS=$'\n\t'

  log 'I ran'
}

get_all_containers() {
  # we want docker ps -aq to be expanded
  # shellcheck disable=SC2046
  docker inspect --format='{{.Name}} {{.Id}} {{range .NetworkSettings.Networks}}{{.IPAddress}} {{.NetworkID}}{{end}}' $(docker ps -aq)
}

log() {
  echo "$(date +%Y-%d-%mT%H:%M:%S\ %Z) $1"
}

error() {
  log >&2 "$1"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
