# Containers

## Adding new Containers

Before deploying a new container or after renaming an existing container remember to generate a new `machine-id`.

```bash
export CONTAINER="xn-xxx"
mkdir /state/var/lib/machines/$CONTAINER/etc/
mkdir /state/var/lib/machines/$CONTAINER/var/lib/systemd
systemd-machine-id-setup --root /state/var/lib/machines/$CONTAINER
```
