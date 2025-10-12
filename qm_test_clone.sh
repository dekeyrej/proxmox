#!/bin/bash
node=bluep
resource_pool=CloudFish # or BluePolaris or Demos
storage_pool=nvme_pool # or local-lvm or hdd_pool

clone_virtual_machine() {
  local vmid=$1
  local template_id=$2
  local hostname=$3
  local ipaddress=$4

  ssh $node qm clone $template_id $vmid --full 1 --storage $storage_pool --name $hostname --pool $resource_pool

  case "$template_id" in 
    # temaplate_ids for ubuntu and debian templates which need rootfs resized
    900|901|902|903)
      echo "Resizing rootfs."
      ssh $node qm disk resize $vmid scsi0 +10G
      ;;
    *)
      echo "No resizing needed."
      ;;
  esac

  ssh $node qm set $vmid --ipconfig0 ip=$ipaddress/24,gw=192.168.86.1
  ssh $node qm start $vmid

  if [[ $? -ne 0 ]]; then
      echo "❌ Test failed for VMID $vmid ($hostname)"
      exit 1
  fi

  echo "✅ Test succeeded for VMID $vmid ($hostname)"
}

# ubuntu and debian start with ~3GB rootfs, so they need to be resized - even for relatively simple tests
clone_virtual_machine 200 900    "india"    "192.168.50.80"
clone_virtual_machine 201 901    "thailand" "192.168.50.81"
clone_virtual_machine 202 902    "mexico"   "192.168.50.82"
clone_virtual_machine 203 903    "panama"   "192.168.50.83"
# CentOS starts with a 10G rootfs, so no need to resize for a simple test
clone_virtual_machine 204 904    "spain"    "192.168.50.85"
clone_virtual_machine 205 905    "ireland"  "192.168.50.86"
# Amazon Linux starts with an 25G rootfs, so no need to resize for a simple test
clone_virtual_machine 206 906    "colombia" "192.168.50.87"
clone_virtual_machine 207 907    "brazil"   "192.168.50.88"
