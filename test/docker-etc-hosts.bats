#!/usr/bin/env ./libs/bats/bin/bats
load '../docker-etc-hosts.sh'

@test "get_all_containers returns names and ip addresses" {

  local container_id; container_id=$(random_hex_id)
  create_docker_container "hardcore_vaughan" "172.17.0.3" "$container_id"

  local output; output="$(get_all_containers)"

  assert_equals "$output" "/hardcore_vaughan $container_id 172.17.0.3 $default_bridge_network_id"
}

random_hex_id() {
  hexdump -n 32 -e '8/4 "%08x" 1 "\n"' /dev/random
}

default_bridge_network_id=$(random_hex_id)

declare -a docker_containers
declare -a docker_networks=("bridge bridge $default_bridge_network_id")

create_docker_container() {
  local name=$1
  local ip=$2
  local id=${3:-$(random_hex_id)}
  local network=${4:-"$default_bridge_network_id"}
  docker_containers+=("$name $ip $network $id")
}

docker() {
  if [ "$*" = 'ps -aq' ]; then
    docker_ps_aq
  elif [ "$1" = "inspect" ]; then
    shift
    docker_inspect "$@"
  else
    echo "Unknown: $*"
    return 1
  fi
}

docker_ps_aq() {
  for container in "${docker_containers[@]}"; do
    IFS=' ' read -r name ip network id <<< "$container"
    echo "${id:0:12}"
  done
}

docker_inspect() {
  local format="$1"
  local id="$2"

  for container in "${docker_containers[@]}"; do
    IFS=' ' read -r name ip network_id container_id <<< "$container"
    if [ "$id" = "${container_id:0:12}" ]; then
      echo "/$name $container_id $ip $network_id"
    fi
  done

#  if [ "$1" = "inspect --format={{.Name}} {{range .NetworkSettings.Networks}}{{.IPAddress}} {{.NetworkID}}{{end}} 05178994c37d" ]; then
#    echo '/hardcore_vaughan 172.17.0.3 c11d10006ca6e45b73c514acb6ca1bdc99a080cdfd29650cf4dd334053936912'
#  else
#    echo "Unknown: $*"
#  fi
}

assert_equals() {
  local actual=$1
  local expected=$2
  echo "Expected: [$expected]"
  echo "Actual:   [$actual]"

  [ "$actual" = "$expected" ]
}
