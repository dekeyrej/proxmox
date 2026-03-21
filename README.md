# 🛡️ Proxmox‑VE Administration Guide: Modular Stewardship for Sysadmins

## 1. Introduction

- **Proxmox‑VE** (hereinafter referred to as *proxmox*) is a purpose‑built Linux distribution based on Debian, featuring a tuned kernel and components that enable it to function as a private cloud — hosting both KVM virtual machines and LXC containers.

- **Purpose and scope of this guide.**  
  This document provides practical guidance for provisioning virtual machines and containers, and for performing basic maintenance on a proxmox installation. Most examples reference or excerpt from supporting GitHub repositories.

- **Audience assumptions.**  
  The guide assumes moderate Linux familiarity and some sysadmin experience.

- **Philosophy: modular, repeatable infrastructure.**  
  Handcrafting a machine once is fine; being able to confidently provision, configure, and tear down machines *repeatedly* is better. This guide emphasizes reproducibility, automation, and clean separation of concerns.

- **Supporting GitHub repositories.**  
  Four repositories provide the tooling foundation for repeatable infrastructure:

  - **[Terraform](https://github.com/dekeyrej/Terraform)** — Modules for provisioning VMs and LXC containers. The VM module supports Ubuntu (22.04, 24.04, 25.10), Debian (12, 13, 14), RockyLinux (9, 10), CentOS (9, 10), and Amazon Linux (2, 2023).  
    Due to proxmox implementation details, the LXC module works best with *lightly customized* images (see below) derived from [linuxcontainers.org](https://images.linuxcontainers.org/).

  - **[custom-container-images](https://github.com/dekeyrej/custom-container-images)** — Source and build instructions for custom LXC images (Ubuntu, Debian, RockyLinux, CentOS, AmazonLinux 2023). These images enable `openssh-server`, create a default non‑root user, grant passwordless sudo, and prepopulate `authorized_keys`, making them immediately Ansible‑ready.

  - **[ansible](https://github.com/dekeyrej/ansible)** — Dozens of parameterized roles and playbooks for configuring VMs and containers.

  - **[ansible-vault-keys](https://github.com/dekeyrej/ansible-vault-keys)** — A companion utility to `ansible-vault` that keeps sensitive variables secure *and* YAML maintainable.

---

## 2. Getting Started with Proxmox‑VE

### **Installation and Initial Configuration**

Proxmox‑VE 9.0.14 is installed on three nodes: `bluep`, `bluep02`, and `bluep03`.

| Node      | CPU                       | Motherboard                     | RAM        | Storage                                     | Extras                                      |
|-----------|---------------------------|----------------------------------|------------|----------------------------------------------|---------------------------------------------|
| `bluep`   | AMD 7985WX<br>(64C/128T)  | Pro WS WRX90E‑SAGE SE<br>2×10GbE | 512GB DDR5 | 4TB + 2×8TB NVMe,<br>2×10TB HDD              | RTX PRO 6000 (96GB),<br>RTX 4060 Ti (16GB),<br>Mellanox 100GbE |
| `bluep02` | AMD 9950X3D<br>(16C/32T)  | X870E Taichi<br>5GbE            | 256GB DDR5 | 2×4TB + 2×8TB NVMe,<br>2×10TB HDD            | Mellanox 100GbE                              |
| `bluep03` | AMD 9950X3D<br>(16C/32T)  | X870E Taichi<br>5GbE            | 256GB DDR5 | 4TB + 2×8TB NVMe,<br>2×10TB HDD              | Mellanox 100GbE                              |

These nodes form the proxmox datacenter **`BluePolaris`**.

---

### **Networking Setup**

Networking uses bridges, VLANs, and static IPs to support flexible provisioning and isolation.

Each node has:

- Built‑in Ethernet interfaces connected to a 10G/5G/2.5G/1G switch for corosync, external access, and inter‑VM/CT communication.
- A 100GbE NIC connected to a dedicated switch for:
  - Proxmox migration traffic  
  - LINSTOR DRBD replication  
  - High‑bandwidth backend operations  

These interfaces are virtualized as:

- `vmbr0` — primary bridge for general VM/CT networking  
- `vmbr100` — high‑speed 100GbE backend (MTU 9000)

| Endpoint              | 10/5/2.5/1GbE IPv4 | 100GbE IPv4 |
|----------------------|---------------------|-------------|
| `bluep`              | 192.168.50.2        | 10.10.10.11 |
| `bluep02`            | 192.168.50.5        | 10.10.10.12 |
| `bluep03`            | 192.168.50.6        | 10.10.10.14 |
| `bluep-pbs` (VM7777) | 192.168.50.10       | 10.10.10.10 |
| `cib` (VM99998)      | 192.168.50.124      | 10.10.10.124 |

(Additional details may be expanded in a later section or appendix.)

---

### **Storage Configuration**

Each node provides a mix of NVMe and HDD storage, organized into several pools:

- **`local`** (100GB NVMe): Per‑node, non‑shared. CT templates, imported VM images, ISOs.
- **`local-lvm`** (3.8TB NVMe): Per‑node, non‑shared. VM disks and CT volumes.
- **`vmdata`** (7.85TB NVMe): Per‑node, non‑shared. High‑performance VM/CT storage.
- **`cold`** (9.2TB RAID1 HDD): Per‑node, non‑shared. Backups, ISOs, CT templates, imported images.
- **`pbs`** (3.94TB NVMe): Hosted by VM 7777 `bluep-pbs`, pinned to `bluep02`. Shared backup target.
- **`linstor`** (7.6TB NVMe‑backed, 3‑replica DRBD): Shared, distributed (over 100GbE), high‑performance storage.

---

### **Access Control and User Roles**

Modern proxmox versions allow most day‑to‑day operations to be performed by non‑root users with appropriate permissions.

Root access is only required for:

- Host OS updates  
- Rebooting the node  

Current roles:

- `ryan@pve`, `sachin@pve`, `carlos@pve`, `joe@pve` — Full administrative rights.
- `aditya@pve` — Scoped rights to manage VMs/CTs within the **`Demos`** resource pool.

---

## 3. Quick Starts

- **Command‑line tools**
  - `qm` — create, modify, start, stop, and destroy QEMU virtual machines  
    Example: `build_vm.sh`
  - `pct` — create, modify, start, stop, and destroy LXC containers  
    Example: `build_container.sh` (based on `custom-container-images`)

- **Customization**
  - hardcoding - edit the headers of build_container.sh and build_vm.sh to adjust the defaults for your environment (deprecated)
  - environmental overrides (new & preferred)
    - PVENODE="iluvatar"                                     # remote node (build_vm.sh and build_container.sh)
    - GATEWAY="192.168.86.1"                                 # network gateway address (build_vm.sh and build_container.sh)
    - STORAGE_POOL="nvme_pool"                               # default storage pool (build_vm.sh and build_container.sh)
    - SSHKEYS="/root/.ssh/authorized_keys"                   # text file with public keys, one per line, OPENSSH format _ON the NODE_!!! (build_vm.sh and build_container.sh)
    - LOGICAL_IMPORT_PATH="ssd_backup:import"                # PVESM path to cloud images on the node, e.g., local:import (build_vm.sh)
    - PHYSICAL_IMPORT_PATH="/mnt/ssd_backup/import"          # physical path on the node where images are stored (build_vm.sh)
    - LOGICAL_IMAGE_PATH="ssd_backup:vztmpl"                 # PVESM path to lxc templates on the node, e.g., local:import (build_container.sh)
    - PHYSICAL_IMAGE_PATH="/mnt/ssd_backup/template/cache"   # physical path on the node where lxc templates are stored (build_container.sh)

---

## 4. Modular Foundations

- Inventory‑driven provisioning: dynamic inventories and tagging  
- Terraform + proxmox provider: declarative VM orchestration  
- Ansible integration: imperative configuration and lifecycle management  
- Vault key management: secrets, encryption, secure handoff  

---

## 5. Long‑Lived Developer Machines

- Use case definition and lifecycle expectations  
- Provisioning flow  
- Terraform VM creation  
- Ansible post‑boot configuration  
- Vault key injection and secrets handling  
- Custom container images for embedded tooling  
- Backup, snapshot, rollback strategies  
- Monitoring and logging (Proxmox metrics, syslog, optional Prometheus/Grafana)  

---

## 6. Ephemeral Demonstration Environments

- Use case definition: demos, workshops, short‑lived sandboxes  
- Provisioning flow  
- Terraform + Ansible orchestration  
- Lightweight container‑based setups  
- MOTD banners and expressive log lines for clarity  
- Auto‑expiry, cleanup, resource reclamation  
- Optional: templated scenarios or “demo packs”  

---

## 7. Advanced Topics

- Nested virtualization and CI/CD runners  
- PCI passthrough and GPU provisioning  
- Network quirks and container edge cases (CentOS Stream 10, NetworkManager)  
- Proxmox clustering and HA  
- Expressive naming conventions and lore‑aware tagging  

---

## 8. Operational Rituals

- Fire sale / Creation Saga: archiving, snapshotting, renewal  
- Update flows: kernel, proxmox packages, Terraform/Ansible modules  
- Troubleshooting: mythic debugging patterns and expressive logs  
- Documentation and README stewardship  

---

## 9. Appendices

- GitHub repo summaries and usage patterns  
- Sample inventories and playbooks  
- Terraform module references  
- Container image recipes and build flows  

---
