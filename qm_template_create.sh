#!/bin/bash

node=bluep
# the sshkey file must be on the node (not local)
sshkey=/root/.ssh/authorized_keys
# sshkey=/root/manwe.pub
resource_pool=CloudFish # or BluePolaris or Demos
storage_pool=hdd_pool # or local-lvm or nvme_pool

build_vm_template() {
    local vmid=$1
    local image=$2
    local user=$3
    local hostname=$4

    # Notes: 
    # - CentOS 9 & 10, and Amazon Linux 2023 are sensitive to the cputype so '--cpu cputype=host'
    # - Especially for ubuntu and debian cloud-init, a serial port is required for cloud-init so '--serial0 socket'

    ssh $node qm create $vmid --name $hostname --pool $resource_pool \
                --cores 2 --cpu cputype=host --memory 2048 --balloon 2048 \
                --net0 virtio,bridge=vmbr0 --serial0 socket --ostype l26 \
                --scsihw virtio-scsi-pci --boot order=scsi0 --ide2 $storage_pool:cloudinit \
                --citype nocloud --ciupgrade true --ciuser $user --sshkeys $sshkey

    ssh $node qm disk import $vmid /var/lib/vz/import/$image $storage_pool --target-disk scsi0
    ssh $node qm set $vmid --template 1 --protection 1



    if [[ $? -ne 0 ]]; then
        echo "❌ Template creation failed for VMID $vmid ($image)"
        exit 1
    fi

    echo "✅ Template creation succeeded for VMID $vmid ($image)"
}

build_vm_template 900 "ubuntu-24.04-server-cloudimg-amd64.qcow2"                     "ubuntu"   "uduntu24"
build_vm_template 901 "ubuntu-25.04-server-cloudimg-amd64.qcow2"                     "ubuntu"   "uduntu25"
build_vm_template 902 "debian-12-generic-amd64.qcow2"                                "debian"   "debian12"
build_vm_template 903 "debian-13-generic-amd64.qcow2"                                "debian"   "debian13"
build_vm_template 904 "centos-9-stream-generic-cloud.qcow2"                          "centos"   "centos9"
build_vm_template 905 "centos-10-stream-generic-cloud.qcow2"                         "centos"   "centos10"
build_vm_template 906 "amzn2-kvm-2.0.20250915.0-x86_64.xfs.gpt.qcow2"                "ec2-user" "amzn2"
build_vm_template 907 "al2023-kvm-2023.8.20250915.0-kernel-6.1-x86_64.xfs.gpt.qcow2" "ec2-user" "amzn2023"
