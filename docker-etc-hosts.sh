#! /usr/bin/env bash

main() {
  set -euo pipefail
  IFS=$'\n\t'

  # Set home so docker doesn't moan
  export HOME="${HOME:-/var/root}"

  log 'I ran'
  get_all_containers
}

get_all_containers() {
  # we want docker ps -aq to be expanded
  # shellcheck disable=SC2046
  docker inspect \
    --format='{{$service := index .Config.Labels "com.docker.compose.service"}}{{$name := .Name}}{{$container_id := .Id}}{{range $network_name, $value := .NetworkSettings.Networks}}{{$ip_address := .IPAddress}}{{$network_id := .NetworkID}}{{$name}}|{{$container_id}}|{{$ip_address}}|{{$network_name}}|{{$network_id}}|{{$service}}{{printf "\n"}}{{end}}' \
    $(docker ps -q $(all_docker_bridge_networks_as_filter)) \
    | sed '/^$/d'
}

all_docker_bridge_networks_as_filter() {
  docker network ls --filter 'driver=bridge' --format '--filter=network={{.ID}}'
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
