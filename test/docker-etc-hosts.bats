#!/usr/bin/env ./libs/bats/bin/bats
load '../docker-etc-hosts.sh'

@test "get_all_containers returns a single name and ip address" {

  local container_id; container_id=$(random_hex_id)
  create_docker_container "hardcore_vaughan" "172.17.0.3" "$container_id"

  local output; output="$(get_all_containers)"

  assert_equals "$output" "/hardcore_vaughan $container_id 172.17.0.3 $default_bridge_network_id"
}

@test "get_all_containers returns multiple names and ip addresses" {

  local container_id_1; container_id_1=$(random_hex_id)
  create_docker_container "container_one" "172.17.0.2" "$container_id_1"
  local container_id_2; container_id_2=$(random_hex_id)
  create_docker_container "container_two" "172.17.0.3" "$container_id_2"

  local output; output="$(get_all_containers)"

  assert_equals "$output" "/container_one $container_id_1 172.17.0.2 $default_bridge_network_id
/container_two $container_id_2 172.17.0.3 $default_bridge_network_id"
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
  local command=$1
  shift

  case $command in
    ps)      docker_ps_aq "$@" ;;
    inspect) docker_inspect "$@" ;;
    *)       echo "Unknown command: $command"; return 1 ;;
  esac
}

docker_ps_aq() {
  for container in "${docker_containers[@]}"; do
    IFS=' ' read -r name ip network id <<< "$container"
    echo "${id:0:12}"
  done
}

docker_inspect() {
  local format="$1"
  shift
  local ids=("$@")

  for id in "${ids[@]}"; do
    for container in "${docker_containers[@]}"; do
      IFS=' ' read -r name ip network_id container_id <<< "$container"
      if [ "$id" = "${container_id:0:12}" ]; then
        echo "/$name $container_id $ip $network_id"
      fi
    done
  done
}

assert_equals() {
  local actual=$1
  local expected=$2
  echo "Expected: [$expected]"
  echo "Actual:   [$actual]"

  [ "$actual" = "$expected" ]
}
