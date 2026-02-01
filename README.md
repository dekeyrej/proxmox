# 🛡️ Proxmox-VE Administration Guide: Modular Stewardship for Sysadmins
## 1. Introduction
- **Proxmox-VE** (hereinafter referred to as 'proxmox') is a purpose built linux distribution built on top of Debian with a specially tuned kernel, and components that allow it to act as a private cloud - hosting both KVM Virtual Machines and LXC Containers.
- **Purpose and scope of the guide**. The intent of this document is to provide some practical guidance to accelerate the creation of Virtual Machines and Containers, and to perform basic maintenance on the Proxmox installation.  Most of this guidance will be accompanied with references to, or excerpts from various github repositories.
- **Audience assumptions.** Throughout this guide the author will assume a moderate level of Linux familiarity and some sysadmin experience.  
- **Philosophy: modular, repeatable infrastructure.** The guiding principal throughout the guide is that handcrafting a 'machine' once is nice, but being able to confidently provision, configure, and teardown a machine is best.
- **Overview of supporting GitHub repositories.** There are four GitHub repositories that provide tools to streamline repeatable infrastructure:  
  - [Terraform](https://github.com/dekeyrej/Terraform): Contains modules for provisioning Virtual Machines and LXC Containers respectively.  A few examples of their use are also provided.  The Virtual Machine module works with a variety of Linux distributions and has been tested with Ubuntu (22.04, 24.04 & 25.04), Debian (12 & 13), RockyLinux (9 & 10), CentOS (9 & 10), and Amazon linux (2 & 2023). Because of some implementation decisions in proxmox, the LXC Container module works 'best' with images _lightly customized_ (see custom-container-images below) from those published at [linuxcontainers.org](https://images.linuxcontainers.org/).
  - [custom-container-images](https://github.com/dekeyrej/custom-container-images): Provides source and instructions for these custom LXC container images (Ubuntu (22.04, 24.04 & 25.04), Debian (12 & 13), RockyLinux (9 & 10), CentOS (9 & 10), and AmazonLinux 2023) which enable openssh-server, create the default non-root user for the OS, grant passwordless sudo to that non-root user, and finally prepopulate authorized_keys for the non-root user - all of which mean that the container is immediately ready to manage via ansible.
  - [ansible](https://github.com/dekeyrej/ansible): Offers dozens of parameterized ansible roles and playbooks for configuring virtual machines and containers.
  - [ansible-vault-keys](https://github.com/dekeyrej/ansible-vault-keys): A companion utility to ansible-vault to keep sensitive ansible variables safe _and_ the YAML _maintainable_.

## 2. Getting Started with Proxmox-VE

- **Installation and Initial Configuration**  
  Proxmox-VE 9.0.14 is installed on three nodes named `bluep`, `bluep02`, and `bluep03`.
  
| Node     | CPU                      | Motherboard                 | RAM        | Storage                                   | Extras                                   |
|----------|--------------------------|-----------------------------|------------|-------------------------------------------|------------------------------------------|
| `bluep`  | AMD 7985WX<br>(64C/128T) | Pro WS WRX90E‑SAGE SE<br>2× 10GbE | 512GB DDR5 | 4TB + 2× 8TB NVMe,<br>2× 10TB HDD   | RTX PRO 6000 (96GB),<br>RTX 4060 Ti (16GB),<br>Mellanox 100GbE |
| `bluep02`| AMD 9950X3D<br>(16C/32T) | X870E Taichi<br>5GbE        | 256GB DDR5 | 2× 4TB + 2× 8TB NVMe,<br>2× 10TB HDD      | Mellanox 100GbE                           |
| `bluep03`| AMD 9950X3D<br>(16C/32T) | X870E Taichi<br>5GbE        | 256GB DDR5 | 4TB + 2× 8TB NVMe,<br>2× 10TB HDD         | Mellanox 100GbE                           |

  The three nodes are joined together as a proxmox Datacenter named `BluePolaris`.

- **Networking Setup**  
  Networking is configured with bridges, VLANs, and static IPs to support flexible provisioning and isolation.
  In addition to the built-in _physical_ Ethernet interfaces of the three nodes which are connected to a 10G/5G/2.5G/1G switch for corosync, external access, and inter-VM/CT communications, each of the nodes is also connected to 100G switch which supports Proxmox migration, and the linstor DRBD (Distributed Raw Block Device) storage. These physical interfaces are virtualized as `vmbr0` and `vbr100` for use by Virtual Machines and Containers.  The 100GeB network is configured for MTU=9000.

| Endpoint | 10/5/2.5/1GbE IP4 | 100GbE IP4 |
|---|---|---|
| `bluep` | 192.168.50.2 | 10.10.10.11 |
| `bluep` | 192.168.50.5 | 10.10.10.12 |
| `bluep` | 192.168.50.6 | 10.10.10.14 |
| `bluep-pbs` (VM7777) | 192.168.50.10 | 10.10.10.10 |
| `cib` (VM99998)| 192.168.50.124 | 10.10.10.124 |
    
  (Details may be expanded in a later section or appendix if needed.)

- **Storage Configuration**  
  Each of the nodes offers a mix of NVMe and spinning disk storage, organized across several pools:
  - `local` (100GB NVMe): Per-node. Non-shared. Used for CT templates, imported VM images, and ISO files.
  - `local-lvm` (3,800GB NVMe): Per-node. Non-shared. Storage for VM disks and CT volumes.
  - `vmdata` (7,850GB NVMe): Per-node. Non-shared. High-performance storage for VM disks and CT volumes.
  - `cold` (9,200GB RAID1 HDD array): Per-node. Non-shared. Bulk storage for Backups, ISO Images, CT Templates, and Imported VM Images.
  - `pbs` (3,940GB NVMe): Hosted by VM 7777 `bluep-pbs`, pinned to `bluep02`. Shared. Centralized backup target for VMs and CTs.
  - `linstor` (7,600GB NVMe-backed, 3-place DRBD): Shared. High-performance, distributed storage for VM disks and CT volumes.

- **Access Control and User Roles**  
  In recent versions of proxmox, most day-to-day operations—provisioning, configuration, backup, and teardown—can be performed by non-root users with appropriate permissions.  
  Root access is only required for:
  - Server OS updates
  - Rebooting the host

  Current user roles:
  - `ryan@pve`, `sachin@pve`, `carlos@pve`, and `joe@pve`: Full administrative rights across the server.
  - `aditya@pve`: Scoped rights to manage VMs and containers within the `Demos` resource pool.

## 3. Quick Starts
- Scriptable commandline tools:
  - `qm` allows you the create, modify, stop, start and destroy QEMU virtual machines
    example in (build_vm.sh)[build_vm.sh]
  - `pct` allows you the create, modify, stop, start and destroy lxc containers
    this example - (build_container.sh)[build_container.sh] is based on `custom-container-images` as described above.
    
## 4. Modular Foundations
- Inventory-driven provisioning: dynamic inventories and tagging.
- Terraform + Proxmox provider: declarative VM orchestration
- Ansible integration: imperative configuration and lifecycle management
- Vault key management: secrets, encryption, and secure handoff

## 5. Long-Lived Developer Machines
- Use case definition and lifecycle expectations
- Provisioning flow:
- Terraform VM creation
- Ansible post-boot configuration
- Vault key injection and secrets handling
- Custom container images: embedded tooling, dev environments
- Backup, snapshot, and rollback strategies
- Monitoring and logging (Proxmox metrics, syslog, optional Prometheus/Grafana)

## 6. Ephemeral Demonstration Environments
- Use case definition: demos, workshops, short-lived sandboxes
- Provisioning flow:
- Terraform + Ansible orchestration
- Lightweight container-based setups
- MOTD banners and poetic log lines for demo clarity
- Auto-expiry, cleanup, and resource reclamation
- Optional: templated scenarios or "demo packs"

## 7. Advanced Topics
- Nested virtualization and CI/CD runners
- PCI passthrough and GPU provisioning
- Network quirks and container edge cases (CentOS 10-Stream, NetworkManager)
- Proxmox clustering and HA
- Expressive naming conventions and lore-aware tagging

## 8. Operational Rituals
- Fire sale / Creation Saga: archiving, snapshotting, and renewal
- Update flows: kernel, Proxmox packages, Terraform/Ansible modules
- Troubleshooting: mythic debugging patterns and expressive logs
- Documentation and README stewardship

## 9. Appendices
- GitHub repo summaries and usage patterns
- Sample inventories and playbooks
- Terraform module references
- Container image recipes and build flows
