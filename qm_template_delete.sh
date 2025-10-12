#!/usr/bin/env bash
node=bluep
for t in {900..907}; do
  echo "Deleting template VMID $t"
  ssh $node qm set $t --protection 0
  ssh $node qm destroy $t --purge
done
echo "All templates deleted."