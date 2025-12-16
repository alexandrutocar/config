# ────────────────────────────────────────────────────────────────────────
#
# █░█ ▀█▀ █ █░░ █ ▀█▀ █ █▀▀ █▀
# █▄█ ░█░ █ █▄▄ █ ░█░ █ ██▄ ▄█
#
# ────────────────────────────────────────────────────────────────────────
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # System Monitoring
    btop # modern, feature-rich, interactive monitoring
    lsof # standard for listing open files

    # Disk & Filesystem
    ncdu # efficient disk usage analyzer
    parted # disk partitioning
    gptfdisk # comfortable disk partitioning
    rclone # cloud storage sync
    restic # backup tool
    rsync # file synchronization
    glib # virtual filesystems

    # Version Control
    git-annex

    # Databases
    sqlitebrowser

    # Encryption & Keys
    openssl
    gnupg
    age
    yubikey-manager

    # Key Management
    cfssl

    # Nix
    nix-tree
    nix-diff

    # Networking
    curl # HTTP client
    dig # DNS lookup

    # Archiving & Compression
    pigz # parallel gzip compression
    xz # compression
    zip # archiving
    zstd # modern compression
    unzip # extraction

    # Scripting
    gnused # stream editor
    bc # basic calculator

    # Text
    jq # JSON processor
    yq # XML, YAML processor
    xq-xml # XML (XPath) query utility

    # Hardware & Kernel
    hwinfo # hardware detection
    inxi # system information
    iw # wireless interfaces

    # Peripheral & Bus Info
    pciutils # PCI device info
    usbutils # USB device info
  ];
}
