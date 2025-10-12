#!/usr/bin/env bash
node=bluep

for v in {200..207}; do
  echo "Deleting VM VMID $v"
  ssh $node qm set $v --protection 0
  ssh $node qm stop $v
  ssh $node qm destroy $v --purge
done
echo "All VMs deleted."