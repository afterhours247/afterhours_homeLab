# 1. Automate the Download 
resource "proxmox_download_file" "ubuntu_cloud_image" {
  content_type        = "iso"
  datastore_id        = "local"
  node_name           = "sproxmox01"
  url                 = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  file_name           = "ubuntu-24.04-cloudimg.img"
  overwrite_unmanaged = true
  overwrite           = false
}

# 2. Install the base Docker runtime on the dedicated VM
locals {
  vendor_cloud_config = <<EOF
#cloud-config
hostname: vm-pterodactyl01
manage_etc_hosts: true
package_update: true
package_upgrade: true

# Setup your user profile cleanly with perfect alignment
users:
  - default
  - name: afterhours
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - "${var.afterhours_pub_key}"

# Docker is the runtime for the Pterodactyl stack and game servers.
packages:
  - qemu-guest-agent
  - curl
  - git
  - ca-certificates
  - docker.io
  - docker-compose-v2

runcmd:
  # Start the guest agent and Docker runtime; Terraform manages the containers.
  - systemctl enable --now qemu-guest-agent
  - systemctl enable --now docker
  - usermod -aG docker afterhours
EOF

  network_cloud_config = <<EOF
version: 2
ethernets:
  lan:
    match:
      macaddress: "bc:24:11:23:b2:b5"
    addresses:
      - "192.168.1.175/24"
    routes:
      - to: default
        via: "192.168.1.1"
    nameservers:
      addresses:
        - "8.8.8.8"
        - "1.1.1.1"
        - "8.8.4.4"
      search:
        - "win.local"
  sdn:
    match:
      macaddress: "bc:24:11:a8:80:c8"
    addresses:
      - "10.6.7.175/24"
    nameservers:
      addresses:
        - "8.8.8.8"
        - "1.1.1.1"
        - "8.8.4.4"
      search:
        - "win.local"
EOF
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "sproxmox01"

  source_raw {
    data      = local.vendor_cloud_config
    file_name = "vm-pterodactyl01.yaml"
  }
}

resource "proxmox_virtual_environment_file" "network_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "sproxmox01"

  source_raw {
    data      = local.network_cloud_config
    file_name = "vm-pterodactyl01-network.yaml"
  }
}

# 3. Build the Pterodactyl Panel and Wings VM
resource "proxmox_virtual_environment_vm" "vm-pterodactyl01" {
  name        = "vm-pterodactyl01"
  description = "Managed by Terraform - Pterodactyl Game Server VM with Playit.gg Tunnel"
  tags        = ["terraform", "vm", "pterodactyl", "playit.gg"]
  node_name   = "sproxmox01"

  # Aesthetic alignment: 100 range for VMs, 200 range for LXCs
  vm_id = 102

  started = true
  on_boot = true
  machine = "q35"

  cpu {
    cores = 4
    type  = "host" #"x86-64-v2-AES"
  }

  memory {
    dedicated = 8192
  }

  lifecycle {
    ignore_changes = [
      disk[0].file_id, initialization[0].user_data_file_id
    ]
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_download_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    size         = 50
    file_format  = "raw"
  }

  # Card 1: Public Home Network
  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:11:23:B2:B5"
  }

  # Card 2: Custom Private Network
  network_device {
    bridge      = "vnet0"
    mac_address = "BC:24:11:A8:80:C8"
  }

  initialization {
    datastore_id      = "local-lvm"
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
    type              = "nocloud"

    network_data_file_id = proxmox_virtual_environment_file.network_config.id
  }
}
