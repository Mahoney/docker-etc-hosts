#!/usr/bin/env ./libs/bats/bin/bats
load '../docker-etc-hosts.sh'

@test "get_all_containers returns names and ip addresses" {

  # given
  function docker() {
    if [ "$*" = 'ps -aq' ]; then
      echo '05178994c37d'
    elif [ "$*" = "inspect --format={{.Name}} {{range .NetworkSettings.Networks}}{{.IPAddress}} {{.NetworkID}}{{end}} 05178994c37d" ]; then
      echo '/hardcore_vaughan 172.17.0.3 c11d10006ca6e45b73c514acb6ca1bdc99a080cdfd29650cf4dd334053936912'
    fi
  }
  export -f docker

  run get_all_containers
  test "$status" -eq 0
  test "$output" = '/hardcore_vaughan 172.17.0.3 c11d10006ca6e45b73c514acb6ca1bdc99a080cdfd29650cf4dd334053936912'
}
