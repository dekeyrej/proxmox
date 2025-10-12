#!/bin/bash

node=bluep
sshkey=/root/.ssh/authorized_keys # or a text file with public keys, one per line, OPENSSH format
resource_pool=CloudFish # or BluePolaris or Demos
storage_pool=nvme_pool # or local-lvm or hdd_pool

build_virtual_machine() {
    local vmid=$1
    local image=$2
    local user=$3
    local hostname=$4
    local ipaddress=$5

    # both CentOS releases and Amazon Linux 2023 are sensitive to the cputype setting
    # so we use cputype=host for all VMs for consistency
        ssh $node qm create $vmid --name $hostname --pool $resource_pool \
                --cores 2 --cpu cputype=host --memory 2048 --balloon 2048 \
                --net0 virtio,bridge=vmbr0  --ipconfig0 ip=$ipaddress/24,gw=192.168.86.1 --serial0 socket --ostype l26 \
                --scsihw virtio-scsi-pci --boot order=scsi0 --ide2 $storage_pool:cloudinit \
                --citype nocloud --ciupgrade true --ciuser $user --sshkeys $sshkey
                
    ssh $node qm disk import $vmid /var/lib/vz/import/$image local-lvm --target-disk scsi0
    case "$vmid" in 
        200|201|202|203)
            echo "Resizing rootfs."
            ssh $node qm disk resize $vmid scsi0 +10G
            ;;
        *)
            echo "No resizing needed."
            ;;
    esac
    ssh $node qm start $vmid

    if [[ $? -ne 0 ]]; then
        echo "❌ Test failed for VMID $vmid ($hostname)"
        exit 1
    fi

    echo "✅ Test succeeded for VMID $vmid ($hostname)"
}

# both CentOS releases and Amazon Linux 2023 are sensitive to the cputype setting
# so we use cputype=host for all VMs for consistency
build_virtual_machine 200 "ubuntu-24.04-server-cloudimg-amd64.qcow2"                     "ubuntu"   "india"    "192.168.50.80"
build_virtual_machine 201 "ubuntu-25.04-server-cloudimg-amd64.qcow2"                     "ubuntu"   "thailand" "192.168.50.81"
build_virtual_machine 202 "debian-12-generic-amd64.qcow2"                                "debian"   "mexico"   "192.168.50.82"
build_virtual_machine 203 "debian-13-generic-amd64.qcow2"                                "debian"   "panama"   "192.168.50.83"
# CentOS starts with a 10G rootfs, so no need to resize
build_virtual_machine 204 "centos-9-stream-generic-cloud.qcow2"                          "centos"   "spain"    "192.168.50.85"
build_virtual_machine 205 "centos-10-stream-generic-cloud.qcow2"                         "centos"   "ireland"  "192.168.50.86"
# Amazon Linux starts with an 25G rootfs, so no need to resize
build_virtual_machine 206 "amzn2-kvm-2.0.20250915.0-x86_64.xfs.gpt.qcow2"                "ec2-user" "colombia" "192.168.50.87"
build_virtual_machine 207 "al2023-kvm-2023.8.20250915.0-kernel-6.1-x86_64.xfs.gpt.qcow2" "ec2-user" "brazil"   "192.168.50.88"