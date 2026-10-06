# Installation

- [Installation](#installation)
  - [Step 1: Remote Access to the Installation Environment](#step-1-remote-access-to-the-installation-environment)
  - [Step 2: Disk Partitioning, Full Disk Encryption and File Systems](#step-2-disk-partitioning-full-disk-encryption-and-file-systems)
  - [Step 3: Writing Configuration](#step-3-writing-configuration)
    - [Full Disk Layout (Partitioning)](#full-disk-layout-partitioning)
    - [Secure Boot (Lanzaboote)](#secure-boot-lanzaboote)
    - [Impermanence](#impermanence)
    - [Hardware Configuration (*Facter Report*)](#hardware-configuration-facter-report)
  - [Step 4: Deploying Configuration](#step-4-deploying-configuration)


> [!IMPORTANT] 
> This document is an early draft so please be cautious running commands mentioned in here. Do not run any commands from this guide if you are not sure as to what those do.

You have booted the live environment from a USB or other peripheral device. You either downloaded the ISO-file provided by NixOS and referenced in its installation guide, or created your own bootable image with network, SSH, and other credentials preconfigured for convenience.

If you already have SSH access to the live environment, then feel free to skip [Step 1: Remote Access to the Installation Environment](#step-1-remote-access-to-the-installation-environment).

## Step 1: Remote Access to the Installation Environment

After connecting your target (host/machine you wish to set up) to the local network and confirming its address by either running `ip addr` or by listing connected devices in your router dashboard, you need to set up an SSH connection.

> [!NOTE]
> To write to `/root/.ssh/authorized_keys` you can either use sudo or set root user's password with `passwd` and then log-in as root user with `su root`.

Generate SSH keys on your other machine (which is used to set up your target) and put them somewhere under `~/.ssh/keys.d/`. Type your public key manually into the `/root/.ssh/authorized_keys` file and then confirm that it is correct by connecting via SSH to your target with:


```sh
ssh root@<IP>
```

If you have ULA enabled on your network and your unique subnet prefix ready, you can generate an Interface ID and append it to the prefix to form the target's ULA address. To generate the Interface ID, run:

```sh
openssl rand -hex 8 | fold -w4 | paste -sd:
```

Then to make connecting to the target easier, it is best to write a configuration block to `~/.ssh/config` like this:

```ini
Match host fischl.hosts.net.internal # use your preferred name
  HostName <IP>
  IdentitiesOnly yes
  IdentityFile ~/.ssh/keys.d/hosts.net.internal/root@fischl
```

Later, `fischl.hosts.net.internal` will resolve dynamically, so all you need to do is remove `HostName ...`.

## Step 2: Disk Partitioning, Full Disk Encryption and File Systems

*This part is not ready yet.*

## Step 3: Writing Configuration

### Full Disk Layout (Partitioning)

Specify LUKS, SWAP and other file systems by their UUID (`/dev/disk/by-uuid/<UUID>`). This requires you to go over the commands you previously used to encrypt and partition physical devices and then format and mount the file systems. To generate a Host ID you can use:

```sh
openssl rand -hex 4
```

### Secure Boot (Lanzaboote)

If secure boot is being configured at initialisation step, then follow this [guide](https://github.com/nix-community/lanzaboote/blob/ba33415d747d8dedd2931af107521634f1f2e8a8/docs/getting-started/prepare-your-system.md) which goes into more detail.

> [!NOTE]
The keys must land relative to the root mount point i.e. `/mnt/var/lib/sbctl` or `/mnt/state/var/lib/sbctl` if mount point is impermanent and mounted by the Impermanence module. 

### Impermanence

If your root mount point is impermanent, then you also need to persist the `machine-id`, which you can generate and persist using:

```sh
mkdir -p /mnt/state/etc && openssl rand -hex 16 > /mnt/state/etc/machine-id
```

You must also provide the hashed user passwords and any other persisted files and credentials which are expected to be found under `/state` directory.

###  Hardware Configuration (*Facter Report*)

To generate the report and copy it over to the machine deploying the configuration use the following:

```sh
nix run github:nix-community/nixos-facter -- -o report.json
scp  root@fischl.hosts.net.internal:/root/report.json ~/.tracked/config/etc/fischl/report.json
```

## Step 4: Deploying Configuration

After skimming through your configuration files and confirming everything looks all right, you need to build it, copy the result to the host over an SSH connection and then install it. The following command will build the configuration on the machine used to setup the target:

> [!NOTE]
`nixos-rebuild switch --target-host root@fischl.hosts.net.internal` cannot be used to deploy the configuration to your target machine, as it has no way to specify the non-standard root of the system.


```sh
nix build .#nixosConfigurations.fischl.config.system.build.toplevel
```

```sh
nix copy --to 'ssh://root@fischl.hosts.net.internal?remote-store=local%3Froot%3D/mnt' ./result
```

After that you need to find store path suffixed with `nixos-system-<hostname>`.

```sh
ls -la /mnt/state/nix/store | grep "nixos-system-<hostname>"
```

Specify `/mnt` as root. Drop `/mnt` from the system closure path like this:

```sh
nixos-install --root /mnt \
  --system /nix/store/lf21645vkqnak8q53kb3qb335pydfifz-nixos-system-fischl-26.11.20260927.7276cb9 \
  --no-root-passwd
```

> [!IMPORTANT]
Seeing no errors does not guarantee that your configuration will boot without issue, and it could still be the case that you have something missing from the `/state` directory. So check twice.

If the installation has succeeded, you can reboot the system. 