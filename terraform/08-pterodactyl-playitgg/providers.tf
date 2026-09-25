terraform {
  required_version = ">= 1.5.0"

  cloud {
    organization = "afterhours-homeLab"

    workspaces {
      name = "afterhours-pterodactyl-nodes" # Inherits Local mode automatically thanks to your global change!
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
    agent       = false
    username    = "root"
    private_key = file("~/.ssh/id_ed25519")
  }
}

provider "docker" {
  host     = "ssh://afterhours@192.168.1.175:22"
  ssh_opts = ["-o", "StrictHostKeyChecking=no", "-i", pathexpand("~/.ssh/id_ed25519")]
}
