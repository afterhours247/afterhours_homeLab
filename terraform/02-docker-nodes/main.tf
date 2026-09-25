# 1. Automate the Download 
resource "proxmox_download_file" "ubuntu_cloud_image" {
  content_type = "iso" 
  datastore_id = "local"
  node_name    = "sproxmox01"
  url          = "https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img"
  file_name    = "ubuntu-26.04-cloudimg.iso"
  overwrite = false
}

# 1. Define the Cloud-Init configuration text
locals {
  vendor_cloud_config = <<EOF
#cloud-config
hostname: vm-docker01
manage_etc_hosts: true
package_update: true
package_upgrade: true

# 1. Setup your user profile and load your working ED25519 key text
users:
  - default
  - name: afterhours
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - "${var.afterhours_pub_key}"

# 2. Keep your package installation commands
packages:
  - qemu-guest-agent
  - curl

runcmd:
  - systemctl enable --now qemu-guest-agent
  - curl -fsSL https://get.docker.com -o get-docker.sh
  - sh get-docker.sh
  - usermod -aG docker afterhours
  - rm get-docker.sh
EOF
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "sproxmox01"

  source_raw {
    data      = local.vendor_cloud_config
    file_name = "vm-docker01.yaml"
  }
}

# 2. Build the Dual-Homed Docker VM
resource "proxmox_virtual_environment_vm" "vm-docker01" {
  name        = "vm-docker01"
  description = "Managed by Terraform - Primary Docker Node"
  tags        = ["terraform", "docker", "vm"]
  node_name   = "sproxmox01"
  vm_id       = 101

  started = true
  on_boot = true
  machine = "q35"

  cpu {
    cores = 8
    type  = "host"#"x86-64-v2-AES"
  }

  

  memory {
    dedicated = 8192 # 8GB RAM
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id = "local-lvm" 
    file_id      = proxmox_download_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    size         = 100
    file_format  = "raw" # 👈 FIXED: Force raw format for local-lvm compatibility
  }

  # Card 1: Public Home Network
  network_device {
    bridge = "vmbr0"
  }

  # Card 2: Custom Joke Network
  network_device {
    bridge = "vnet0"
  }

  initialization {
    datastore_id = "local-lvm"
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
    type = "nocloud"

    ip_config {
      ipv4 {
        address = "192.168.1.170/24"
        gateway = "192.168.1.1"
      }
    }
    
    ip_config {
      ipv4 {
        address = "10.6.7.170/24"
      }
    }

    user_account {
      username = "afterhours"
      keys     = [var.afterhours_pub_key] # 🔑 Is this line still here?
    }
  }
}
