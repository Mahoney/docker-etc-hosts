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

  # shellcheck disable=SC2016
  local name_var='{{$name := .Name}}'
  # shellcheck disable=SC2016
  local id_var='{{$container_id := .Id}}'

  local compose_project_var; compose_project_var=$(label_var_default_empty_string 'compose_project' 'com.docker.compose.project')
  local compose_service_var; compose_service_var=$(label_var_default_empty_string 'compose_service' 'com.docker.compose.service')
  local compose_number_var; compose_number_var=$(label_var_default_empty_string 'compose_number' 'com.docker.compose.container-number')

  # shellcheck disable=SC2016
  local ip_address_var='{{$ip_address := .IPAddress}}'
  # shellcheck disable=SC2016
  local network_id_var='{{$network_id := .NetworkID}}'

  # shellcheck disable=SC2016
  local entry='{{$name}}|{{$container_id}}|{{$ip_address}}|{{$network_name}}|{{$network_id}}|{{$compose_project}}|{{$compose_service}}|{{$compose_number}}'

  # shellcheck disable=SC2016
  local per_network="$ip_address_var""$network_id_var""$entry"'{{printf "\n"}}'

  # shellcheck disable=SC2016
  local network_loop='{{range $network_name, $value := .NetworkSettings.Networks}}'"$per_network"'{{end}}'

  local format_template="$name_var""$id_var""$compose_project_var""$compose_service_var""$compose_number_var""$network_loop"

  # we want docker ps -q to be expanded
  # shellcheck disable=SC2046
  docker inspect \
    --format="$format_template" \
    $(docker ps -q $(all_docker_bridge_networks_as_filter)) \
    | sed '/^$/d'
}

label_var_default_empty_string() {
  local var_name=$1
  local label=$2
  local label_expr; label_expr="$(label_expression "$label")"

  go_template_var_default_empty_string "$var_name" "$label_expr"
}

go_template_var_default_empty_string() {
  local var_name=$1
  local expression=$2
  echo '{{$'"$var_name"' := "" | or ('"$expression"')}}'
}

label_expression() {
  local label=$1
  echo "index .Config.Labels \"$label\""
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
