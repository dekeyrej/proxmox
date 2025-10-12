# 🛡️ Proxmox-VE Administration Guide: Modular Stewardship for Sysadmins
## 1. Introduction
- **Proxmox-VE** (hereinafter referred to as 'proxmox') is a purpose built linux distribution built on top of Debian with a specially tuned kernel, and components that allow it to act as a private cloud - hosting both KVM Virtual Machines and LXC Containers.
- **Purpose and scope of the guide**. The intent of this document is to provide some practical guidance to accelerate the creation of Virtual Machines and Containers, and to perform basic maintenance on the Proxmox installation.  Most of this guidance will be accompanied with references to, or excerpts from various github repositories.
- **Audience assumptions.** Throughout this guide the author will assume a moderate level of Linux familiarity and some sysadmin experience.  
- **Philosophy: modular, repeatable infrastructure.** The guiding principal throughout the guide is that handcrafting a 'machine' once is nice, but being able to confidently provision, configure, and teardown a machine is best.
- **Overview of supporting GitHub repositories.** There are four GitHub repositories that provide tools to streamline repeatable infrastructure:  
  - [Terraform](https://github.com/dekeyrej/Terraform): Contains modules for provisioning Virtual Machines and LXC Containers respectively.  A few examples of their use are also provided.  The Virtual Machine module works with a variety of Linux distributions and has been tested with Ubuntu (24.04 & 25.04), Debian (12 & 13), CentOS (9 & 10), and Amazon linux (2 & 2023). Because of some implementation decisions in proxmox, the LXC Container module works 'best' with images _lightly customized_ (see custom-container-images below) from those published at [linuxcontainers.org](https://images.linuxcontainers.org/).
  - [custom-container-images](https://github.com/dekeyrej/custom-container-images): Provides source and instructions for these custom LXC container images (Ubuntu (24.04 & 25.04), Debian (12 & 13), and CentOS (9 & 10)) which enable openssh-server, create the default non-root user for the OS, grant passwordless sudo to that non-root user, and finally prepopulate authorized_keys for the non-root user - all of which mean that the container is immediately ready to manage via ansible.
  - [ansible](https://github.com/dekeyrej/ansible): Offers dozens of parameterized ansible roles and playbooks for configuring virtual machines and containers.
  - [ansible-vault-keys](https://github.com/dekeyrej/ansible-vault-keys): A companion utility to ansible-vault to keep sensitive ansible variables safe _and_ the YAML _maintainable_.

## 2. Getting Started with Proxmox-VE

- **Installation and Initial Configuration**  
  Proxmox-VE 9.0.10 is installed on the server named `bluep`, accessible at `192.168.50.2` via the provided OpenVPN connection.  
  The server is built on an AMD Threadripper CPU (64 cores / 128 threads) with 512GB of DDR5 RAM—ample capacity for both long-lived developer environments and ephemeral demos.

- **Networking Setup**  
  Networking is configured with bridges, VLANs, and static IPs to support flexible provisioning and isolation.  
  (Details may be expanded in a later section or appendix if needed.)

- **Storage Configuration**  
  `bluep` offers a mix of NVMe and spinning disk storage, organized across several pools:
  - `local` (100GB NVMe): Used for CT templates, imported VM images, and ISO files.
  - `local-lvm` (3,800GB NVMe): Primary storage for VM disks and CT volumes.
  - `nvme_pool` (7,850GB ZFS-backed NVMe): High-performance storage for VM disks and CT volumes.
  - `hdd_pool` (19,840GB ZFS-backed HDD): Bulk storage for VM disks and CT volumes.
  - `hdd_backups`: Dedicated backup target for VMs and CTs, backed by `hdd_pool`.

- **Access Control and User Roles**  
  In recent versions of proxmox, most day-to-day operations—provisioning, configuration, backup, and teardown—can be performed by non-root users with appropriate permissions.  
  Root access is only required for:
  - Server OS updates
  - Rebooting the host
  - Posting updated VM and container base images

  Current user roles:
  - `ryan@pve`, `sachin@pve`, and `carlos@pve`: Full administrative rights across the server.
  - `aditya@pve`: Scoped rights to manage VMs and containers within the `Demos` resource pool.
## 3. Quick Starts
- Scriptable commandline tools:
  - `qm` allows you the create, modify, stop, start and destroy QEMU virtual machines
    example in (qm_test.sh)[qm_test.sh]
  - `pct` allows you the create, modify, stop, start and destroy lxc containers
    this example - (pct_test.sh)[pct_test.sh] is based on `custom-container-images` as described above.
    
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
