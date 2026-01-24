#!/usr/bin/env bash

node=iluvatar
sshkeys=/root/.ssh/authorized_keys
image_dir=/home/ubuntu/repos/custom-container-images
gateway=192.168.86.1
storage_pool=nvme_pool
image=$(cat images.txt)
vmid=104

build_container() {
   vmid=$1
   template=$2
   hostname=$3
   ipaddress=$4
   cores=$5
   memory=$6
   disk_size=$7

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

}

sudo arp -d boromir
build_container $vmid $image boromir 192.168.86.96 2 2048 8

# for image in $(cd $image_dir && ls -1 *.tar.xz); do
# for image in $(cat images.txt); do
   # sudo arp -d boromir
   # build_container 105 "$image" "boromir" "192.168.86.96" 2 2048 8
   # sleep 20
   # ssh root@boromir cat /etc/os-release
   # ssh root@boromir poweroff
   # sleep 20
   # ssh iluvatar pct destroy 104 --purge
   # sleep 20
# done
