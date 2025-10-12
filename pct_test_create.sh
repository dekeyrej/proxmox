#!/bin/bash

node=bluep
resource_pool=CloudFish # or BluePolaris or Demos
storage_pool=nvme_pool # or local-lvm or hdd_pool

build_container() {
    local vmid=$1
    local template=$2
    local ostype=$3
    local hostname=$4
    local ipaddress=$5

    ssh $node pct create $vmid local:vztmpl/$template  --hostname $hostname \
                --ostype $ostype --rootfs $storage_pool:8 --arch amd64 \
                --net0 name=eth0,bridge=vmbr0,gw=192.168.50.1,ip=$ipaddress/24 \
                --cores 2 --memory 2048 --swap 0 --pool $resource_pool --start 1 --unprivileged 1

    if [[ $? -ne 0 ]]; then
        echo "❌ Test failed for VMID $vmid ($hostname)"
        exit 1
    fi

    echo "✅ Test succeeded for VMID $vmid ($hostname)"
}

build_container 300 "ubuntu-noble-latest-custom.tar.xz"     "ubuntu" "pune"    "192.168.50.68"
build_container 301 "ubuntu-plucky-latest-custom.tar.xz"    "ubuntu" "bangkok" "192.168.50.69"
build_container 302 "debian-bookworm-latest-custom.tar.xz"  "debian" "onset"   "192.168.50.70"
build_container 303 "debian-trixie-latest-custom.tar.xz"    "debian" "samana"  "192.168.50.71"
build_container 304 "centos-9-stream-latest-custom.tar.xz"  "centos" "clayton" "192.168.50.72"
build_container 305 "centos-10-stream-latest-custom.tar.xz" "centos" "kells"   "192.168.50.73"