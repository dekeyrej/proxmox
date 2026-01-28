#!/usr/bin/env bash
# default parameters               - can be over-ridden by command line args
# definitely modify for environment
node=iluvatar                      # pve node or 'local' if you are running it on the Proxmox node
gateway=192.168.86.1               # default gateway for VMs
storage_pool=nvme_pool             # default storage pool for VM disks
# less likely to need modification
sshkeys=/root/.ssh/authorized_keys # or a text file with public keys, one per line, OPENSSH format _ON the NODE_!!!
image_path=ssd_backup:import       # PVESM path to cloud images on the node, e.g., local:import
physical_path=/mnt/ssd_backup/import   # physical path on the node where images are stored
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
cputype="host"                     # e.g., host, qemu64, x86-64-v2-AES, etc.
extra_disk=0                       # scsi1 size in GB
remarks=""                         # VM description enclosed in quotes, stored as a comment in <vmid>.conf
tags=""
machine_type="pc"                  # "pc" or "q35"
display=""                         # VGA/display type; e.g., default, std, qxl, none
hostpci0=""                        # PCI passthrough mapping; e.g., mapping=pro6000,pcie=1,x-vga=1, also enables q35/OVMF/EFI Disk
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

while getopts "Ln:w:s:k:I:v:h:i:u:c:m:d:a:p:t:e:r:g:T:D:P:RH" opt; do
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
    t) cputype="$OPTARG" ;;
    e) extra_disk="$OPTARG" ;;
    r) remarks="$OPTARG" ;;
    g) tags="$OPTARG" ;;
    T) machine_type="$OPTARG" ;;
    D) display="$OPTARG" ;;
    P) hostpci0="$OPTARG" ;;
    R) dry_run=1 ;;
    H) help=1 ;;
  esac
done

if [[ -z $vmid || -z $hostname || -z $image || $help -eq 1 ]]; then
    cat <<EOF
NAME
    build_vm.sh – Create Proxmox VMs with sane defaults and cloud-init support

SYNOPSIS
    build_vm.sh -v <vmid> -h <hostname> -i <image> [options]

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
    -k <sshkeys>         SSH public keys file on the node (default: $sshkeys)

ADVANCED OPTIONS
    -p <pool>            Assign VM to a resource pool
    -t <cpu>             CPU type (e.g., host, qemu64)
    -e <size>            Extra disk size in GB
    -T <type>            Machine type (e.g., q35)
    -D <display>         VGA/display type
    -P <hostpci0>        PCI passthrough mapping
    -r <remarks>         VM description
    -g <tags>            Comma-separated VM tags

FLAGS
    -R                   Dry run (print actions only)
    -H                   Show this help and exit
    -L                   List available images on the node

DESCRIPTION
    build_vm.sh wraps the Proxmox 'qm' command to provide a clean,
    declarative interface for VM creation. It handles cloud-init,
    storage selection, PCI passthrough, q35/OVMF configuration,
    and safe defaults for most Linux cloud images.

    The script auto-detects the default cloud-init user based on
    the image filename unless overridden with -u.

EXAMPLES
    build_vm.sh -v 400 -h frodo -i ubuntu-24.04-cloudimg-amd64.qcow2
    build_vm.sh -v 401 -h sam -i debian-13-generic-amd64.qcow2 -u debian
    build_vm.sh -v 402 -h aragorn -i rocky-9.qcow2 -P mapping=pro6000,pcie=1,x-vga=1
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

run_qm() {
    local args=("$@")

    if [[ $dry_run -eq 1 ]]; then
        echo "Dry run: qm ${args[*]}"
        return 0
    fi

    if [[ $node == "local" ]]; then
        qm "${args[@]}"
    else
        # Escape everything so SSH passes it as a single, safe command
        local cmd
        cmd=$(escape_for_ssh qm "${args[@]}")
        ssh "$node" "$cmd"
    fi
}

if [[ $node == "local" ]]; then
    if qm status "$vmid" &>/dev/null; then
        echo "VMID $vmid already exists on local node"
        exit 1
    fi
else
    if ssh "$node" qm status "$vmid" &>/dev/null; then
        echo "VMID $vmid already exists on $node"
        exit 1
    fi
fi

if [[ -z $user ]]; then
  case "$image" in
    *ubuntu*|*noble*|*questing*) user="ubuntu" ;;
    *debian*|*bookworm*|*trixie*) user="debian" ;;
    *Rocky*|*rocky*|*almalinux*|*CentOS*|*centos*|*rhel*) user="cloud-user" && cputype="host" ;;
    *amzn2*|*al2023*) user="ecs-user" && cputype="host" ;;
    *fedora*) user="fedora" ;;
    *arch*) user="arch" ;;
    *) user="ubuntu" ;;  # safe default
  esac
fi

echo "Building VMID $vmid ($hostname) on node $node"

qm_options=(
  --cores "$cores"
  --memory "$memory"
  --balloon "$memory"
  --net0 "virtio,bridge=vmbr0"
  --scsihw virtio-scsi-single
  --boot order=scsi0
  --scsi0 "$storage_pool:0,import-from=$image_path/$image"
  --ostype l26
  --ide2 "$storage_pool:cloudinit"
  --citype nocloud
  --ciupgrade true
  --ciuser "$user"
  --sshkeys "$sshkeys"
  --serial0 socket
  --agent 1
  --onboot 1
)

[[ -n $ipaddress ]] \
  && qm_options+=(--ipconfig0 "ip=$ipaddress/24,gw=$gateway") \
  || qm_options+=(--ipconfig0 ip=dhcp)

[[ -n $resource_pool ]] && qm_options+=(--pool "$resource_pool")
[[ -n $cputype ]] && qm_options+=(--cpu "cputype=$cputype")
[[ $extra_disk -ne 0 ]] && qm_options+=(--scsi1 "file=$storage_pool:$extra_disk")
[[ -n $remarks ]] && qm_options+=(--description "$remarks")
[[ -n $tags ]] && qm_options+=(--tags "$tags")
[[ -n $display ]] && qm_options+=(--vga "$display")
[[ -n $hostpci0 ]] && qm_options+=(--hostpci0 "$hostpci0" --machine "type=q35" --bios ovmf --efidisk0 "$storage_pool:1,efitype=4m,ms-cert=2023,pre-enrolled-keys=1")

if [[ "$machine_type" == "q35" ]]; then
  qm_options+=(--machine "type=q35" --bios ovmf --efidisk0 "$storage_pool:1,efitype=4m,ms-cert=2023,pre-enrolled-keys=1")
fi

run_qm create "$vmid" --name "$hostname" "${qm_options[@]}"
run_qm disk resize "$vmid" scsi0 $disk_size"G"
run_qm start "$vmid"


if [[ $? -ne 0 ]]; then
    echo "❌ Creation failed for VMID $vmid ($hostname)"
    exit 1
fi

echo "✅ Creation succeeded for VMID $vmid ($hostname)"
# Examples:
# ./build_vm.sh -v 400 -h frodo -i ubuntu-24.04-cloudimg-amd64.qcow2
# ./build_vm.sh -v 400 -h frodo -i ubuntu-24.04-cloudimg-amd64.qcow2 -a 192.168.86.90
# ./build_vm.sh -v 400 -h frodo -i ubuntu-24.04-cloudimg-amd64.qcow2 -a 192.168.86.90 -p Shire
# ./build_vm.sh -v 400 -h frodo -i ubuntu-24.04-cloudimg-amd64.qcow2 -a 192.168.86.90 -p Shire -t qemu64
# ./build_vm.sh -v 400 -h frodo -i ubuntu-24.04-cloudimg-amd64.qcow2 -a 192.168.86.90 -p Shire -t qemu64 -d 20
# ./build_vm.sh -v 400 -h frodo -i ubuntu-24.04-cloudimg-amd64.qcow2 -a 192.168.86.90 -p Shire -t qemu64 -d 20 -e 50 -c 4 -m 16384
# ./build_vm.sh -v 400 -h frodo -i ubuntu-24.04-cloudimg-amd64.qcow2 -a 192.168.86.90 -p Shire -t qemu64 -d 20 -e 50 -c 4 -m 16384 -T q35
# ./build_vm.sh -v 400 -h frodo -i ubuntu-24.04-cloudimg-amd64.qcow2 -a 192.168.86.90 -p Shire -t qemu64 -d 20 -e 50 -c 4 -m 16384 -T q35 -P mapping=pro6000,pcie=1,x-vga=1 -D none 
# ./build_vm.sh -n bluep -s vmdata -k /root/sachin.pub -v 400 -h frodo -i debian-13-generic-amd64.qcow2 -u debian
