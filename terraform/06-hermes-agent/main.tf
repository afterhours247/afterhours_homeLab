# 1. Automate the Download 
resource "proxmox_download_file" "ubuntu_cloud_image" {
  content_type        = "iso" 
  datastore_id        = "local"
  node_name           = "sproxmox01"
  url                 = "https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img"
  file_name           = "ubuntu-26.04-cloudimg.iso"
  overwrite_unmanaged = true
  overwrite = false
}

# 2. Define the Cloud-Init configuration text
locals {
  vendor_cloud_config = <<EOF
#cloud-config
hostname: vm-hermes01
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

# Required system prerequisites for the native builder
packages:
  - qemu-guest-agent
  - curl
  - git

runcmd:
  # Start the Proxmox Guest monitoring link immediately
  - systemctl enable --now qemu-guest-agent
  
  # Execute the official installer as the non-root user and skip the interactive wizard
  - sudo -u afterhours bash -c "curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --skip-setup"
EOF
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "sproxmox01"

  source_raw {
    data      = local.vendor_cloud_config
    file_name = "vm-hermes01.yaml"
  }
}

# 3. Build the Dedicated Native Hermes VM
resource "proxmox_virtual_environment_vm" "vm-hermes01" {
  name        = "vm-hermes01"
  description = "Managed by Terraform - Native Hermes Agent Node"
  tags        = ["terraform", "vm", "hermes"]
  node_name   = "sproxmox01"
  
  # Aesthetic alignment: 100 range for VMs, 200 range for LXCs
  vm_id       = 100

  started = true
  on_boot = true
  machine = "q35"

  cpu {
    cores = 4
    type  = "host" #"x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
  }

  lifecycle {
    ignore_changes = [
      disk[0].file_id,initialization[0].user_data_file_id
    ]
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id = "local" 
    file_id      = proxmox_download_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    size         = 50
    file_format  = "qcow2"
  }

  # Card 1: Public Home Network
  network_device {
    bridge = "vmbr0"
  }

  # Card 2: Custom Private Network
  network_device {
    bridge = "vnet0"
  }

  initialization {
    datastore_id      = "local-lvm"
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
    type              = "nocloud"

    ip_config {
      ipv4 {
        address = "192.168.1.173/24"
        gateway = "192.168.1.1"
      }
    }
    
    ip_config {
      ipv4 {
        address = "10.6.7.173/24"
      }
    }
  }
}