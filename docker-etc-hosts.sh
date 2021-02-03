#! /usr/bin/env bash

main() {
  set -euo pipefail
  IFS=$'\n\t'

  # Set home so docker doesn't moan
  export HOME="${HOME:-/var/root}"

  get_etc_host_entries | sort
}

get_etc_host_entries() {

  declare -A etc_hosts

  while read -r container_and_ip; do
    IFS='|' read -r compose_project compose_service compose_number name ip_address network_name <<<"$container_and_ip"

    if [ -z "$compose_project" ]; then
      local sanitised_name; sanitised_name=$(sanitise "$name")
      local sanitised_network_name; sanitised_network_name=$(sanitise "$network_name")
      etc_hosts["$sanitised_name.$sanitised_network_name"]="$ip_address"
      if [ "$network_name" = 'bridge' ] || [[ ! -v "etc_hosts[$sanitised_name]" ]]; then
        etc_hosts["$sanitised_name"]="$ip_address"
      fi
    else
      local sanitised_name; sanitised_name=$(sanitise "$compose_service")
      local sanitised_project_name; sanitised_project_name=$(sanitise "$compose_project")
      etc_hosts["$compose_number.$sanitised_name.$sanitised_project_name"]="$ip_address"
      if [ "$compose_number" = '1' ]; then
        etc_hosts["$sanitised_name.$sanitised_project_name"]="$ip_address"
        etc_hosts["$sanitised_name"]="$ip_address"
      fi
    fi
  done < <(get_all_containers)

  for hostname in "${!etc_hosts[@]}"; do
    echo "${etc_hosts[$hostname]} $hostname"
  done
}

get_all_containers() {
  # we want docker ps -q to be expanded
  # shellcheck disable=SC2046
  docker inspect \
    --format="$(format_template)" \
    $(docker ps -q $(all_docker_bridge_networks_as_filter)) |
    sed '/^$/d' |
    sort
}

sanitise() {
  local sanitised="$1"

  shopt -s extglob
  sanitised=${sanitised//+([^A-Za-z0-9\.])/-}
  sanitised=${sanitised//+([\.])/.}
  sanitised=${sanitised#[^[:alnum:]]}
  sanitised=${sanitised%[^[:alnum:]]}
  echo "${sanitised,,}"
}

format_template() {
  local name_var; name_var=$(var_exp 'name' '.Name')

  local compose_project_var; compose_project_var=$(label_var_default_empty_string 'compose_project' 'com.docker.compose.project')
  local compose_service_var; compose_service_var=$(label_var_default_empty_string 'compose_service' 'com.docker.compose.service')
  local compose_number_var; compose_number_var=$(label_var_default_empty_string 'compose_number' 'com.docker.compose.container-number')

  local ip_address_var; ip_address_var=$(var_exp 'ip_address' '.IPAddress')

  local entry; entry=$(join_vars_with_separator '|' 'compose_project' 'compose_service' 'compose_number' 'name' 'ip_address' 'network_name')

  local per_network="$ip_address_var""$entry"'{{printf "\n"}}'

  # shellcheck disable=SC2016
  local network_loop='{{range $network_name, $value := .NetworkSettings.Networks}}'"$per_network"'{{end}}'

  echo "$name_var""$compose_project_var""$compose_service_var""$compose_number_var""$network_loop"
}

join_vars_with_separator() {
  local separator=$1
  vars=()
  while IFS='' read -r line; do vars+=("$line"); done < <(surround '{{$' '}}' "${@:2}")
  local joined; IFS="$separator" joined="${vars[*]}"
  echo "$joined"
}

surround() {
  local prefix=$1
  local suffix=$2
  local to_surround=("${@:3}")
  local result=("${to_surround[@]/#/"$prefix"}")
  result=("${result[@]/%/"$suffix"}")
  echo "${result[*]}"
}

var_exp() {
  local var_name=$1
  local expr=$2
  echo '{{$'"$var_name"' := '"$expr"'}}'
}

label_var_default_empty_string() {
  local var_name=$1
  local label=$2
  local label_expr="index .Config.Labels \"$label\""

  var_exp "$var_name" '""'" | or ($label_expr)"
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
