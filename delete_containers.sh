#!/usr/bin/env bash
node=bluep

for v in {300..305}; do
  echo "Deleting CT VMID $v"
  ssh $node pct set $v --protection 0
  ssh $node pct stop $v
  ssh $node pct destroy $v --purge
done
echo "All CTs deleted."