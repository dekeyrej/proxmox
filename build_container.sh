#!/usr/bin/env bash
# default parameters               - can be over-ridden by command line args
# definitely modify for environment
node=iluvatar                      # pve node or 'local' if you are running it on the Proxmox node
gateway=192.168.86.1               # default gateway for VMs
storage_pool=nvme_pool             # default storage pool for VM disks
# less likely to need modification
sshkeys=/root/.ssh/authorized_keys # or a text file with public keys, one per line, OPENSSH format _ON the NODE_!!!
image_path=ssd_backup:vztmpl       # PVESM path to cloud images on the node, e.g., local:import
physical_path=/mnt/ssd_backup/template/cache # physical path on the node where images are stored
# required parameters to create VM
vmid=""                            # VMID to create, must be unique
hostname="vm-$vmid"                # hostname for the VM
image=""                           # cloud image filename (must exist in ${image_path} on the node)
user=""                            # cloud-init user; auto-detected if omitted
# required parameters to run a VM with reasonable defaults
cores=2                            # number of vCPUs
memory=2048                        # minimum and balloon memory in MB, swap 0
disk_size=10                       # scsi0 boot disk size, in GB
# optional parameters
ipaddress=""                       # static IP address; if empty, use DHCP
resource_pool=""                   # resource pool to assign the VM to, or empty for none
# cputype="host"                     # e.g., host, qemu64, x86-64-v2-AES, etc.
# extra_disk=0                       # scsi1 size in GB
remarks=""                         # VM description enclosed in quotes, stored as a comment in <vmid>.conf
tags=""
arch="amd64"                       # e.g., amd64, arm64
# machine_type="pc"                  # "pc" or "q35"
# display=""                         # VGA/display type; e.g., default, std, qxl, none
# hostpci0=""                        # PCI passthrough mapping; e.g., mapping=pro6000,pcie=1,x-vga=1, also enables q35/OVMF/EFI Disk
# flags
dry_run=0
help=0

list_images() {
    echo "Available images on node $node in path $physical_path:"
    if [[ $node == "local" ]]; then
        ls -1 "$physical_path"
    else
        ssh "$node" "ls -1 $physical_path"
    fi
    exit 1
}

while getopts "Ln:w:s:k:I:v:h:i:u:c:m:d:a:p:r:g:RH" opt; do
  case $opt in 
    L) list_images ;;
    n) node="$OPTARG" ;;
    w) gateway="$OPTARG" ;;
    s) storage_pool="$OPTARG" ;;
    k) sshkeys="$OPTARG" ;;
    I) image_path="$OPTARG" ;;
    v) vmid="$OPTARG" ;;
    h) hostname="$OPTARG" ;;
    i) image="$OPTARG" ;;
    u) user="$OPTARG" ;;
    c) cores="$OPTARG" ;;
    m) memory="$OPTARG" ;;
    d) disk_size="$OPTARG" ;;
    a) ipaddress="$OPTARG" ;;
    p) resource_pool="$OPTARG" ;;
    r) remarks="$OPTARG" ;;
    g) tags="$OPTARG" ;;
    R) dry_run=1 ;;
    H) help=1 ;;
  esac
done

if [[ -z $vmid || -z $hostname || -z $image || $help -eq 1 ]]; then
    cat <<EOF
NAME
    build_container.sh – Create Proxmox containers with sane defaults and cloud-init-"like" support

SYNOPSIS
    build_container.sh -v <vmid> -h <hostname> -i <image> [options]

REQUIRED OPTIONS
    -v <vmid>            VMID to create
    -h <hostname>        Hostname for the VM
    -i <image>           Cloud image filename (must exist in ${image_path} on the node)

COMMON OPTIONS
    -u <user>            Cloud-init user (auto-detected if omitted)
    -c <cores>           Number of vCPUs (default: $cores)
    -m <memory>          Memory in MB (default: $memory)
    -d <size>            Boot disk size in GB (default: $disk_size)
    -a <ip>              Static IP address (default: DHCP)
    -n <node>            Proxmox node or 'local' (default: $node)
    -w <gateway>         Gateway IP address (default: $gateway)
    -s <storage>         Storage pool for disks (default: $storage_pool)
    -k <sshkeys>         SSH public keys file on the node (default: $sshkeys) (applied to root user)

ADVANCED OPTIONS
    -p <pool>            Assign VM to a resource pool
    -r <remarks>         VM description
    -g <tags>            Comma-separated VM tags

FLAGS
    -R                   Dry run (print actions only)
    -H                   Show this help and exit
    -L                   List available images on the node

DESCRIPTION
    build_container.sh wraps the Proxmox 'pct' command to provide a clean,
    declarative interface for VM creation. It handles cloud-init,
    storage selection, PCI passthrough, q35/OVMF configuration,
    and safe defaults for most Linux cloud images.

    The script auto-detects the default cloud-init user based on
    the image filename unless overridden with -u.

EXAMPLES
    build_container.sh -v 400 -h frodo   -i ubuntu-noble-latest-custom.tar.xz  -a 192.168.86.90 -r "test container - expect it to be created/destroyed frequently"
    build_container.sh -v 401 -h samwise -i debian-trixie-latest-custom.tar.xz -a 192.168.86.91 -p Lothlorien
    build_container.sh -v 402 -h aragorn -i rockylinux-9-latest-custom.tar.xz  -c 4 -m 16384 -d 50 -g kubernetes,main -r "ip4=dhcp, but K8s node for production workloads"
EOF
    exit 1
fi

if [[ $node == "local" ]]; then
    if ! test -f "$physical_path/$image"; then
        echo "Image $image not found on local node"
        list_images
    fi
else
    if ! ssh "$node" test -f "$physical_path/$image"; then
        echo "Image '$image' not found on node $node"
        list_images

    fi
fi

escape_for_ssh() {
    local out=()
    for arg in "$@"; do
        out+=("$(printf '%q' "$arg")")
    done
    printf '%s ' "${out[@]}"
}

run_pct() {
    local args=("$@")

    if [[ $dry_run -eq 1 ]]; then
        echo "Dry run: pct ${args[*]}"
        return 0
    fi

    if [[ $node == "local" ]]; then
        pct "${args[@]}"
    else
        # Escape everything so SSH passes it as a single, safe command
        local cmd
        cmd=$(escape_for_ssh pct "${args[@]}")
        ssh "$node" "$cmd"
    fi
}

if [[ $node == "local" ]]; then
    if pct status "$vmid" &>/dev/null; then
        echo "VMID $vmid already exists on local node"
        exit 1
    fi
else
    if ssh "$node" pct status "$vmid" &>/dev/null; then
        echo "VMID $vmid already exists on $node"
        exit 1
    fi
fi

if [[ -z $user ]]; then
  case "$image" in
    *ubuntu*|*noble*|*questing*) user="ubuntu" ;;
    *debian*|*bookworm*|*trixie*) user="debian" ;;
    *Rocky*|*rocky*|*almalinux*|*CentOS*|*centos*|*rhel*) user="cloud-user" ;;
    *amzn2*|*al2023*) user="ecs-user" ;;
    *fedora*) user="fedora" ;;
    *arch*) user="arch" ;;
    *) user="ubuntu" ;;  # safe default
  esac
fi

echo "Building VMID $vmid ($hostname) on node $node"

pct_options=(
  $image_path/$image
  --rootfs $storage_pool:$disk_size
  --hostname $hostname
  --cores "$cores"
  --memory "$memory"
  --swap 0
  --ssh-public-keys "$sshkeys"
  --onboot 1
  --start 1
  --unprivileged 1
)

[[ -n $ipaddress ]] \
  && pct_options+=(--net0 "name=eth0,bridge=vmbr0,ip=$ipaddress/24,gw=$gateway") \
  || pct_options+=(--net0 "name=eth0,bridge=vmbr0,ip=dhcp")

[[ -n $resource_pool ]] && pct_options+=(--pool "$resource_pool")
[[ -n $remarks ]] && pct_options+=(--description "$remarks")
[[ -n $tags ]] && pct_options+=(--tags "$tags")

run_pct create "$vmid" "${pct_options[@]}"

if [[ $? -ne 0 ]]; then
    echo "❌ Create Container failed for VMID $vmid ($hostname)"
    exit 1
fi

echo "✅ Create Container succeeded for VMID $vmid ($hostname)"

