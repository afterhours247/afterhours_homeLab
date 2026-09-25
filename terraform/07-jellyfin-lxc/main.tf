resource "proxmox_virtual_environment_container" "lxc_jellyfin01" {
  node_name   = "sproxmox01"
  vm_id       = 202
  description = "Managed by Terraform - Jellyfin Media Server"
  tags        = ["terraform", "docker", "jellyfin", "media"]

  unprivileged = true

  started       = true
  start_on_boot = true

  features {
    nesting = true
  }

  lifecycle {
    ignore_changes = [
      features,
      mount_point,
      device_passthrough
    ]
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
    type             = "debian"
  }

  cpu {
    cores = 4
  }

  memory {
    dedicated = 4096
    swap      = 512
  }

  disk {
    datastore_id = "local-lvm"
    size         = 10
  }

  # LAN
  network_interface {
    name     = "eth0"
    bridge   = "vmbr0"
    firewall = false
  }

  # Internal SDN
  network_interface {
    name     = "eth1"
    bridge   = "vnet0"
    firewall = false
  }

  initialization {
    hostname = "lxc-jellyfin01"

    ip_config {
      ipv4 {
        address = "192.168.1.174/24"
        gateway = "192.168.1.1"
      }
    }

    ip_config {
      ipv4 {
        address = "10.6.7.174/24"
      }
    }

    user_account {
      keys = [var.afterhours_pub_key]
    }
  }

  startup {
    order      = 3
    up_delay   = 10
    down_delay = 30
  }
}


# -------------------------------------------------------------
# Install Docker inside Jellyfin LXC
# -------------------------------------------------------------

resource "null_resource" "jellyfin_docker_install" {
  depends_on = [
    proxmox_virtual_environment_container.lxc_jellyfin01
  ]

  connection {
    type        = "ssh"
    user        = "root"
    host        = "192.168.1.174"
    private_key = file("~/.ssh/id_ed25519")
  }

  provisioner "remote-exec" {
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",

      "apt-get update",

      "apt-get install -y curl ca-certificates rsync",

      "curl -fsSL https://get.docker.com -o /tmp/get-docker.sh",

      "sh /tmp/get-docker.sh",

      "rm -f /tmp/get-docker.sh",

      "systemctl enable --now docker",

      "mkdir -p /opt/jellyfin/config",

      "docker --version"
    ]
  }
}

resource "null_resource" "jellyfin_lxc_features" {
  depends_on = [
    proxmox_virtual_environment_container.lxc_jellyfin01
  ]

  connection {
    type        = "ssh"
    host        = "192.168.1.169" # sproxmox01
    user        = "root"
    private_key = file("~/.ssh/id_ed25519")
  }

  provisioner "remote-exec" {
    inline = [
      "pct set 202 -features nesting=1,keyctl=1"
    ]
  }
}

resource "null_resource" "jellyfin_media_mount" {
  depends_on = [
    null_resource.jellyfin_lxc_features
  ]

  triggers = {
    source = "/mnt/pve/usb-datastore"
    target = "/data"
  }

  connection {
    type        = "ssh"
    host        = "192.168.1.169" # sproxmox01
    user        = "root"
    private_key = file("~/.ssh/id_ed25519")
  }

  provisioner "remote-exec" {
    inline = [
      "pct set 202 -mp0 /mnt/pve/usb-datastore,mp=/data,ro=1",
      "pct reboot 202"
    ]
  }
}


resource "docker_image" "jellyfin" {
  name = "lscr.io/linuxserver/jellyfin@sha256:4f6d8dfc53ec5a1ddf7a90e4338972d57d7b0adff6dc88b53184f8285d0b594f"

  keep_locally = true

  depends_on = [
    null_resource.jellyfin_docker_install,
    null_resource.jellyfin_media_mount
  ]
}


resource "docker_container" "jellyfin" {
  name    = "jellyfin"
  image   = docker_image.jellyfin.image_id
  restart = "unless-stopped"

  env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=Asia/Manila"
  ]

  ports {
    internal = 8096
    external = 8096
    protocol = "tcp"
  }

  volumes {
    host_path      = "/opt/jellyfin/jellyfin"
    container_path = "/config"
  }

  volumes {
    host_path      = "/data"
    container_path = "/data"
    read_only      = true
  }

  devices {
    host_path      = "/dev/dri/renderD128"
    container_path = "/dev/dri/renderD128"
  }

  depends_on = [
    docker_image.jellyfin,
    null_resource.jellyfin_media_mount,
    null_resource.jellyfin_gpu_device
  ]
}

resource "null_resource" "jellyfin_gpu_device" {
  depends_on = [
    null_resource.jellyfin_lxc_features
  ]

  triggers = {
    device = "/dev/dri/renderD128"
    gid    = "1000"
    mode   = "0660"
  }

  connection {
    type        = "ssh"
    host        = "192.168.1.169" # sproxmox01
    user        = "root"
    private_key = file("~/.ssh/id_ed25519")
  }

  provisioner "remote-exec" {
    inline = [
      "test -c /dev/dri/renderD128",
      "pct set 202 -dev0 /dev/dri/renderD128,gid=1000,mode=0660",
      "pct reboot 202",
      "until pct exec 202 -- test -c /dev/dri/renderD128; do sleep 2; done",
      "pct exec 202 -- stat -c '%U:%G %u:%g %a %n' /dev/dri/renderD128"
    ]
  }
}