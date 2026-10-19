#!/bin/bash
#
# Windows Server 2025 installer for Contabo VPS (BIOS / MBR).
#
# Run as root from the Contabo Rescue System (Debian live).
# WARNING: a normal install ERASES THE WHOLE DISK.
#
# Usage:
#   bash install.sh                    prepare the disk and the Windows installer
#   bash install.sh --disk /dev/sdb    use a specific disk (default: largest disk)
#   bash install.sh --repair-drivers   only rebuild the VirtIO drivers in the
#                                      installer (no data is erased)
#
# https://github.com/Rustyyyh/contabo-windows-server-2025 - MIT License

set -euo pipefail

# --- Settings ----------------------------------------------------------------

# Windows Server 2025 Evaluation ISO, English (official Microsoft link)
WIN_URL="${WIN_URL:-https://go.microsoft.com/fwlink/?linkid=2345730&culture=en-us&country=us}"
# Latest stable VirtIO drivers (Fedora project)
VIRTIO_URL="${VIRTIO_URL:-https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso}"

SETUP_SIZE=14GiB                       # partition holding the Windows installer
WINPE_DRIVERS="vioscsi viostor NetKVM" # drivers offered in Setup (disk + network)
OS_FOLDERS="2k25 2k22"                 # VirtIO driver folders, in order of preference

# --- Helpers -----------------------------------------------------------------

die()  { echo -e "\nERROR: $*" >&2; exit 1; }
step() { echo -e "\n==> $*"; }

usage() {
    cat <<'EOF'
Usage: bash install.sh [--disk /dev/sdX] [--repair-drivers]

  --disk DEVICE      disk to use (default: the largest disk)
  --repair-drivers   only rebuild the VirtIO drivers in an existing
                     installer partition; no data is erased
EOF
    exit 0
}

# Partition path: /dev/sda -> /dev/sda1, /dev/nvme0n1 -> /dev/nvme0n1p1
part() { case "$DISK" in *[0-9]) echo "${DISK}p$1" ;; *) echo "${DISK}$1" ;; esac; }

install_packages() {
    step "Installing required packages"
    export DEBIAN_FRONTEND=noninteractive
    # The live rescue has no room to rebuild its initramfs, and does not need to
    if [ ! -L /usr/sbin/update-initramfs ]; then
        dpkg-divert --local --rename --add /usr/sbin/update-initramfs >/dev/null
        ln -s /bin/true /usr/sbin/update-initramfs
    fi
    dpkg --configure -a || true
    apt-get update -qq
    apt-get install -y -qq "$@" || true    # a failing post-install hook is not fatal
}

require() {
    for c in "$@"; do
        command -v "$c" >/dev/null || die "missing command: $c"
    done
}

# Copy the drivers for the newest Windows Server version available
copy_virtio_drivers() {   # $1 = mounted VirtIO ISO, $2 = destination
    local dir name os
    for dir in "$1"/*/; do
        name=$(basename "$dir")
        for os in $OS_FOLDERS; do
            if [ -d "$dir$os/amd64" ]; then
                mkdir -p "$2/$name"
                cp -r "$dir$os/amd64/." "$2/$name/"
                break
            fi
        done
    done
    [ -d "$2/vioscsi" ] || die "VirtIO SCSI driver not found in the VirtIO ISO"
}

# Put disk/network drivers in boot.wim as X:\virtio, to be loaded manually in
# Setup. They are NOT placed in $WinPEDriver$: auto-loading VirtIO drivers makes
# Setup fail with error 0x80070103 - 0x40031.
inject_winpe_drivers() {  # $1 = mounted installer partition
    local wim="$1/sources/boot.wim" tmp=/root/winpe-virtio n i
    [ -f "$wim" ] || die "boot.wim not found: is $(part 1) the installer partition?"

    rm -rf "$tmp" && mkdir -p "$tmp"
    for n in $WINPE_DRIVERS; do
        [ -d "$1/virtio-drivers/$n" ] && cp -r "$1/virtio-drivers/$n" "$tmp/"
    done
    [ -d "$tmp/vioscsi" ] || die "VirtIO SCSI driver missing from $1/virtio-drivers"

    for i in 1 2; do
        printf 'delete --force --recursive /$WinPEDriver$\ndelete --force --recursive /virtio\nadd %s /virtio\n' "$tmp" \
            | wimlib-imagex update "$wim" "$i" >/dev/null
    done
    echo "Drivers available in Setup under X:\\virtio: $(ls "$tmp" | xargs)"
}

# --- Arguments and checks ----------------------------------------------------

DISK=""
REPAIR=0
while [ $# -gt 0 ]; do
    case "$1" in
        --disk)           DISK="${2:-}"; shift 2 ;;
        --repair-drivers) REPAIR=1; shift ;;
        -h|--help)        usage ;;
        *)                die "unknown option: $1 (see --help)" ;;
    esac
done

[ "$(id -u)" -eq 0 ]      || die "run this script as root"
[ -d /run/live ]          || die "this is not the Contabo Rescue System: boot it from the control panel first"
[ ! -d /sys/firmware/efi ] || die "the server booted in UEFI mode; this script supports BIOS/MBR only"

if [ -z "$DISK" ]; then
    DISK=$(lsblk -dnbpo NAME,TYPE,SIZE | awk '$2=="disk" {print $3, $1}' | sort -n | tail -1 | cut -d' ' -f2)
fi
[ -b "$DISK" ] || die "disk not found: $DISK"

# --- Repair mode: rebuild drivers only ---------------------------------------

if [ "$REPAIR" = 1 ]; then
    install_packages wimtools ntfs-3g
    require wimlib-imagex ntfs-3g

    mkdir -p /mnt/setup
    mountpoint -q /mnt/setup || mount -t ntfs-3g "$(part 1)" /mnt/setup
    # Older layout: drivers were in $WinPEDriver$ (auto-loaded)
    if [ -d '/mnt/setup/$WinPEDriver$' ]; then
        rm -rf /mnt/setup/virtio-drivers
        mv '/mnt/setup/$WinPEDriver$' /mnt/setup/virtio-drivers
    fi

    step "Rebuilding VirtIO drivers in the installer"
    inject_winpe_drivers /mnt/setup
    umount /mnt/setup
    sync
    echo -e "\nDone. Rebooting into Windows Setup..."
    sleep 3
    reboot
    exit 0
fi

# --- 1. Confirmation ---------------------------------------------------------

SIZE_GB=$(( $(blockdev --getsize64 "$DISK") / 1024 / 1024 / 1024 ))
[ "$SIZE_GB" -ge 50 ] || die "disk too small: ${SIZE_GB} GiB (minimum 50 GiB)"

echo
lsblk "$DISK"
echo
echo "This will ERASE ALL DATA on $DISK (${SIZE_GB} GiB) and prepare the"
echo "Windows Server 2025 installer. Download size is about 9 GB."
echo
read -rp "Type YES to continue: " answer
[ "$answer" = "YES" ] || die "aborted, nothing was changed"

# Current network settings (in case Windows needs a static IP)
IFACE=$(ip -4 route show default | awk '{print $5; exit}')
GATEWAY=$(ip -4 route show default | awk '{print $3; exit}')
ADDRESS=$(ip -4 -o addr show dev "$IFACE" | awk '{print $4; exit}')

# --- 2. Packages -------------------------------------------------------------

install_packages parted ntfs-3g grub-pc-bin grub2-common wget rsync wimtools
require parted wipefs mkfs.ntfs ntfs-3g grub-install wget rsync wimlib-imagex

# --- 3. Partitions -----------------------------------------------------------
#
#   Partition 1  NTFS  14 GiB  active  Windows installer, later boot files
#   Partition 2  NTFS  rest            temporary, for the downloads; deleted at
#                                      the end so Windows installs there

step "Partitioning $DISK"
swapoff -a || true
umount "$DISK"?* 2>/dev/null || true
wipefs -af "$DISK" >/dev/null
dd if=/dev/zero of="$DISK" bs=1M count=10 conv=fsync status=none

parted -s "$DISK" -- mklabel msdos \
    mkpart primary ntfs 1MiB "$SETUP_SIZE" \
    mkpart primary ntfs "$SETUP_SIZE" 100% \
    set 1 boot on
partprobe "$DISK"
udevadm settle
sleep 2

mkfs.ntfs -Q -L WINSETUP "$(part 1)" >/dev/null
mkfs.ntfs -Q -L TEMP     "$(part 2)" >/dev/null

mkdir -p /mnt/setup /mnt/download /mnt/winiso /mnt/virtio
mount -t ntfs-3g "$(part 1)" /mnt/setup
mount -t ntfs-3g "$(part 2)" /mnt/download

# --- 4. Downloads ------------------------------------------------------------

step "Downloading Windows Server 2025 (about 8 GB)"
wget -c --tries=5 -q --show-progress -U "Mozilla/5.0" -O /mnt/download/windows.iso "$WIN_URL"

step "Downloading VirtIO drivers"
wget -c --tries=5 -q --show-progress -O /mnt/download/virtio.iso "$VIRTIO_URL"

mount -o loop,ro /mnt/download/windows.iso /mnt/winiso
mount -o loop,ro /mnt/download/virtio.iso  /mnt/virtio
for f in bootmgr sources/boot.wim sources/install.wim; do
    [ -f "/mnt/winiso/$f" ] || die "the Windows ISO looks invalid ($f missing)"
done

# --- 5. Installer files and drivers ------------------------------------------

step "Copying the Windows installer"
rsync -rt --info=progress2 /mnt/winiso/ /mnt/setup/

step "Adding VirtIO drivers"
copy_virtio_drivers /mnt/virtio /mnt/setup/virtio-drivers
mkdir -p /mnt/setup/virtio-tools
cp /mnt/virtio/virtio-win-gt-x64.msi /mnt/virtio/virtio-win-guest-tools.exe /mnt/setup/virtio-tools/ 2>/dev/null || true
inject_winpe_drivers /mnt/setup

# --- 6. Enable Remote Desktop at the end of Setup -----------------------------

scripts='/mnt/setup/sources/$OEM$/$$/Setup/Scripts'
mkdir -p "$scripts"
cat > "$scripts/SetupComplete.cmd" <<'EOF'
@echo off
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
netsh advfirewall firewall set rule group="@FirewallAPI.dll,-28752" new enable=Yes
EOF
sed -i 's/$/\r/' "$scripts/SetupComplete.cmd"

# --- 7. Bootloader (GRUB -> Windows bootmgr) ---------------------------------

step "Installing the bootloader"
grub-install --target=i386-pc --boot-directory=/mnt/setup/boot "$DISK"
cat > /mnt/setup/boot/grub/grub.cfg <<'EOF'
set timeout=3
set default=0
insmod part_msdos
insmod ntfs
insmod ntldr
menuentry "Windows Server 2025" {
    search --no-floppy --file --set=root /bootmgr
    ntldr /bootmgr
}
EOF

# --- 8. Cleanup --------------------------------------------------------------

step "Cleaning up"
umount /mnt/winiso /mnt/virtio /mnt/download
parted -s "$DISK" rm 2
umount /mnt/setup
sync

cat <<EOF

=====================================================================
 Ready. Write down your network settings:

   IP address : $ADDRESS
   Gateway    : $GATEWAY

 Next: the server reboots into Windows Setup. Open the VNC console
 from the Contabo panel and follow the README.
=====================================================================

EOF
read -rp "Press ENTER to reboot..." _
reboot
