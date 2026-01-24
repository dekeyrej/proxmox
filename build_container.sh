#!/usr/bin/env bash

node=iluvatar
sshkeys=/root/.ssh/authorized_keys
gateway=192.168.86.1
storage_pool=nvme_pool
vmid=$1
template=$2
# ostype=$3
hostname=$3
ipaddress=$4
cores=$5
memory=$6
disk_size=$7
# resource_pool=$9

for p in vmid template hostname ipaddress cores memory disk_size; do
	echo $p
done

            # --ostype $ostype --rootfs $storage_pool:$disk_size --arch amd64 \
            # --cores $cores --memory $memory --swap 0 --pool $resource_pool --start 1 --unprivileged 1
ssh $node pct create $vmid local:vztmpl/$template  --hostname $hostname \
            --rootfs $storage_pool:$disk_size --arch amd64 \
            --net0 name=eth0,bridge=vmbr0,gw=$gateway,ip=$ipaddress/24 \
	        --ssh-public-keys $sshkeys \
            --cores $cores --memory $memory --swap 0 --start 1 --unprivileged 1

if [[ $? -ne 0 ]]; then
    echo "❌ Create Container failed for VMID $vmid ($hostname)"
    exit 1
fi

echo "✅ Create Container succeeded for VMID $vmid ($hostname)"

# build_container.sh 201 "ubuntu-noble-latest-custom.tar.xz" "ubuntu" "rose"      "192.168.86.94" 2  2048  10 "Lothlorien"
