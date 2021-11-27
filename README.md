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

On Linux you will need to set up
[docker-lifecycle-listener](https://github.com/Mahoney/docker-lifecycle-listener)
manually and copy `docker-etc-hosts.sh` into
`/etc/docker-lifecycle-listener.d/on_start/`, ensuring that it is owned & only
writable by root.

On macOS by default you cannot address containers by IP address - you can
install [docker-tuntap-osx](https://github.com/Mahoney-forks/docker-tuntap-osx)
via `brew install mahoney/tap/docker-tuntap-osx` to allow addressing containers
by IP address.

## Releasing

- release a new tag in form x.y.z using the GitHub GUI.
- Edit `$(brew --repository)/Library/Taps/mahoney/homebrew-tap/Formula/docker-etc-hosts.rb`
- Change the version in the `url` field
- Run `brew fetch docker-etc-hosts --build-from-source`
- Update the sha256 with the reported SHA256
- Commit with the message `docker-etc-hosts $version` & push
