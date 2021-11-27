#! /usr/bin/env bash

main() {
  strict

  # Set home so docker doesn't moan
  export HOME="${HOME:-/var/root}"

  synchronize_etc_hosts_as_containers_start_and_stop &
  synchronize_etc_hosts_safely
  log "started"
}

strict() {
  set -euo pipefail; IFS=$'\n\t'
}

synchronize_etc_hosts_as_containers_start_and_stop() {
  strict
  docker events \
    --filter 'type=container' \
    --filter 'event=start' \
    --filter 'event=die' |
    while read -r _; do
      synchronize_etc_hosts_safely
    done
  log "exiting - docker container start/die event stream terminated"
}

synchronize_etc_hosts_safely() {
  if ! synchronize_etc_hosts; then
    error "failed to synchronize /etc/hosts with currently running docker containers"
  fi
}

synchronize_etc_hosts() {
  strict

  local section_name="added by docker-etc-hosts"
  local section_start="## START $section_name"
  local section_end="## END $section_name"

  local altered_etc_hosts; altered_etc_hosts=$(mktemp)
  local etc_hosts_hash_at_start; etc_hosts_hash_at_start=$(md5sum "/etc/hosts")
  sed "/^$section_start/,/^$section_end/d" /etc/hosts > "$altered_etc_hosts"

  local etc_host_entries; etc_host_entries=$(get_etc_host_entries | sort)
  {
    echo "$section_start"
    echo "$etc_host_entries"
    echo "$section_end"
  } >>"$altered_etc_hosts"

  # Yes, this is check then act... if you know a way to atomically do this
  # commit in bash please tell me
  local etc_hosts_hash_now; etc_hosts_hash_now=$(md5sum "/etc/hosts")
  if [ "$etc_hosts_hash_now" = "$etc_hosts_hash_at_start" ]; then
    sudo cp "$altered_etc_hosts" /etc/hosts
    rm "$altered_etc_hosts"
    log "Updated /etc/hosts with $etc_host_entries"
  else
    rm "$altered_etc_hosts"
    synchronize_etc_hosts
  fi
}

get_etc_host_entries() {
  strict

  declare -A etc_hosts

  local all_containers; all_containers=$(get_all_containers_repeat)

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
  done <<< "$all_containers"

  for hostname in "${!etc_hosts[@]}"; do
    echo "${etc_hosts[$hostname]} $hostname"
  done
}

get_all_containers_repeat() {
  strict

  local max_attempts=10
  local attempt=0
  local all_containers;
  until [ $attempt -eq $max_attempts ] || all_containers=$(get_all_containers); do
    attempt=$((attempt+1))
    sleep 0.2
  done
  if [ "$attempt" -eq $max_attempts ]; then
    error "Failed to get all containers on attempt $attempt"
    exit 1
  else
    echo "$all_containers"
  fi
}

get_all_containers() {
  strict
  local format; format="$(format_template)"
  local bridge_networks_filter; bridge_networks_filter="$(all_docker_bridge_networks_as_filter)"
  # we want the filters to be expanded
  # shellcheck disable=SC2086
  local running_containers; running_containers="$(docker ps -q $bridge_networks_filter)"
  # we want docker ps -q to be expanded
  # shellcheck disable=SC2086
  docker inspect --format="$format" $running_containers |
    sed '/^$/d' |
    sort
}

sanitise() {
  strict
  local sanitised="$1"

  shopt -s extglob
  sanitised=${sanitised//+([^A-Za-z0-9\.])/-}
  sanitised=${sanitised//+([\.])/.}
  sanitised=${sanitised#[^[:alnum:]]}
  sanitised=${sanitised%[^[:alnum:]]}
  echo "${sanitised,,}"
}

format_template() {
  strict
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
  strict
  local separator=$1
  vars=()
  while IFS='' read -r line; do vars+=("$line"); done < <(surround '{{$' '}}' "${@:2}")
  local joined; IFS="$separator" joined="${vars[*]}"
  echo "$joined"
}

surround() {
  strict
  local prefix=$1
  local suffix=$2
  local to_surround=("${@:3}")
  local result=("${to_surround[@]/#/"$prefix"}")
  result=("${result[@]/%/"$suffix"}")
  echo "${result[*]}"
}

var_exp() {
  strict
  local var_name=$1
  local expr=$2
  echo '{{$'"$var_name"' := '"$expr"'}}'
}

label_var_default_empty_string() {
  strict
  local var_name=$1
  local label=$2
  local label_expr="index .Config.Labels \"$label\""

  var_exp "$var_name" '""'" | or ($label_expr)"
}

all_docker_bridge_networks_as_filter() {
  strict
  docker network ls --filter 'driver=bridge' --format '--filter=network={{.ID}}'
}

log() {
  echo "$(date +%Y-%m-%dT%H:%M:%S%z) docker-etc-hosts $1"
}

error() {
  log >&2 "$1"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
