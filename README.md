## WARNING - REQUIRES BASH 5.x

This script depends on bash 5.x, and macOs ships with bash 3.x.

On an M1 Mac homebrew installs bash 5.x into /opt/homebrew/bin, which is not on
root's `PATH`, so this script fails as it runs as root when run via
`docker-lifecycle-listener`.

See [Issue 2: Make the script work on an M1 mac](https://github.com/Mahoney/docker-etc-hosts/issues/2)
for discussion of how to fix this...

docker-etc-hosts
================
docker-etc-hosts is a little service to update /etc/hosts with the names of your
running containers, so that you can address them by name.

e.g., if you run:
```bash
docker run --name my-blog nginx
```
you will be able to reach it at http://my-blog

It works in conjunction with
[docker-lifecycle-listener](https://github.com/Mahoney/docker-lifecycle-listener)

It can be installed as so: `brew install mahoney/tap/docker-etc-hosts`

You may need to restart `docker-lifecycle-listener` afterwards:

`sudo services restart docker-lifecycle-listener`

On Linux you will need to set up
[docker-lifecycle-listener](https://github.com/Mahoney/docker-lifecycle-listener)
manually and copy `docker-etc-hosts.sh` into
`/etc/docker-lifecycle-listener.d/on_start/`, ensuring that it is owned & only
writable by root.

On macOS by default you cannot address containers by IP address - you can
install [Docker Mac Net Connect](https://github.com/chipmk/docker-mac-net-connect)
via `brew install chipmk/tap/docker-mac-net-connect` to allow addressing containers
by IP address.

## Releasing

- release a new tag in form x.y.z using the GitHub GUI.
- Edit `$(brew --repository)/Library/Taps/mahoney/homebrew-tap/Formula/docker-etc-hosts.rb`
- Change the version in the `url` field
- Run `brew fetch docker-etc-hosts --build-from-source`
- Update the sha256 with the reported SHA256
- Commit with the message `docker-etc-hosts $version` & push
