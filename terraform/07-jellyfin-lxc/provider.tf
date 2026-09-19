terraform {
  required_version = ">= 1.5.0"

  cloud {
    organization = "afterhours-homeLab"

    workspaces {
      name = "afterhours-lxc-jellyfin"
    }
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.107.0"
    }

    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.4.0"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = true

  ssh {
    agent = true
  }
}

provider "docker" {
  host = "ssh://root@192.168.1.174:22"

  ssh_opts = [
    "-o", "StrictHostKeyChecking=no",
    "-i", pathexpand("~/.ssh/id_ed25519")
  ]
}