# 1. Existing Enterprise Networks
data "docker_network" "backend" {
  name = "net-backend"
}

data "docker_network" "frontend" {
  name = "net-frontend"
}

# 2. Scaffolding for Config Folders (Homarr paths removed)
resource "null_resource" "arr_scaffolding" {
  connection {
    type        = "ssh"
    user        = "afterhours"
    private_key = file("~/.ssh/id_ed25519")
    host        = "192.168.1.170"
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/apps/arr/config/sonarr ~/apps/arr/config/radarr ~/apps/arr/config/prowlarr ~/apps/arr/config/qbittorrent ~/apps/arr/config/bazarr ~/apps/arr/config/seerr ~/apps/arr/config/jellyfin ~/apps/arr/config/flaresolverr ~/apps/arr/config/recyclarr ~/apps/arr/config/maintainerr ~/apps/arr/config/suggestarr ~/apps/arr/config/decluttarr ~/apps/arr/config/chaptarr ~/apps/arr/config/shelfarr"
    ]
  }
}

# 3. Native Network Volume
resource "docker_volume" "usb_datastore" {
  name   = "usb_datastore"
  driver = "local"
  driver_opts = {
    type   = "cifs"
    device = "//192.168.1.169/Proxmox-USB"
    o      = "username=afterhours,password=${var.usb_samba_password},uid=1000,gid=1000,vers=3.0,iocharset=utf8"
  }
}

# -------------------------------------------------------------
# 4. BACKEND APPLICATIONS (net-backend only)
# -------------------------------------------------------------

resource "docker_container" "prowlarr" {
  name    = "prowlarr"
  image   = "lscr.io/linuxserver/prowlarr:latest"
  restart = "unless-stopped"
  env     = ["PUID=1000", "PGID=1000", "TZ=Asia/Manila"]
  ports {
    internal = 9696
    external = 9696
  }
  volumes {
    host_path      = "/home/afterhours/apps/arr/config/prowlarr"
    container_path = "/config"
  }
  networks_advanced { name = data.docker_network.backend.name }
  depends_on = [null_resource.arr_scaffolding]
}

resource "docker_container" "flaresolverr" {
  name    = "flaresolverr"
  image   = "ghcr.io/flaresolverr/flaresolverr:latest"
  restart = "unless-stopped"
  env     = ["TZ=Asia/Manila", "LOG_LEVEL=info"]
  ports {
    internal = 8191
    external = 8191
  }
  networks_advanced { name = data.docker_network.backend.name }
}

resource "docker_container" "qbittorrent" {
  name    = "qbittorrent"
  image   = "lscr.io/linuxserver/qbittorrent:latest"
  restart = "unless-stopped"
  env     = ["PUID=1000", "PGID=1000", "TZ=Asia/Manila", "WEBUI_PORT=8090"]
  ports {
    internal = 8090
    external = 8090
  }
  ports {
    internal = 6881
    external = 6881
  }
  volumes {
    host_path      = "/home/afterhours/apps/arr/config/qbittorrent"
    container_path = "/config"
  }
  volumes {
    volume_name    = docker_volume.usb_datastore.name
    container_path = "/data"
  }
  networks_advanced { name = data.docker_network.backend.name }
  depends_on = [null_resource.arr_scaffolding]
}

resource "docker_container" "unpackerr" {
  name    = "unpackerr"
  image   = "golift/unpackerr:latest"
  restart = "unless-stopped"
  env = [
    "UN_DEBUG=false",
    "UN_QBITTORRENT_0_URL=http://qbittorrent:8090",
    "UN_QBITTORRENT_0_USER=admin",
    "UN_QBITTORRENT_0_PASS=${var.qbit_password}"
  ]
  volumes {
    volume_name    = docker_volume.usb_datastore.name
    container_path = "/data"
  }
  networks_advanced { name = data.docker_network.backend.name }
  depends_on = [docker_container.qbittorrent]
}

resource "docker_container" "sonarr" {
  name    = "sonarr"
  image   = "lscr.io/linuxserver/sonarr:latest"
  restart = "unless-stopped"
  env     = ["PUID=1000", "PGID=1000", "TZ=Asia/Manila"]
  ports {
    internal = 8989
    external = 8989
  }
  volumes {
    host_path      = "/home/afterhours/apps/arr/config/sonarr"
    container_path = "/config"
  }
  volumes {
    volume_name    = docker_volume.usb_datastore.name
    container_path = "/data"
  }
  networks_advanced { name = data.docker_network.backend.name }
  depends_on = [null_resource.arr_scaffolding]
}

resource "docker_container" "radarr" {
  name    = "radarr"
  image   = "lscr.io/linuxserver/radarr:latest"
  restart = "unless-stopped"
  env     = ["PUID=1000", "PGID=1000", "TZ=Asia/Manila"]
  ports {
    internal = 7878
    external = 7878
  }
  volumes {
    host_path      = "/home/afterhours/apps/arr/config/radarr"
    container_path = "/config"
  }
  volumes {
    volume_name    = docker_volume.usb_datastore.name
    container_path = "/data"
  }
  networks_advanced { name = data.docker_network.backend.name }
  depends_on = [null_resource.arr_scaffolding]
}

resource "docker_container" "bazarr" {
  name    = "bazarr"
  image   = "lscr.io/linuxserver/bazarr:latest"
  restart = "unless-stopped"
  env     = ["PUID=1000", "PGID=1000", "TZ=Asia/Manila"]
  ports {
    internal = 6767
    external = 6767
  }
  volumes {
    host_path      = "/home/afterhours/apps/arr/config/bazarr"
    container_path = "/config"
  }
  volumes {
    volume_name    = docker_volume.usb_datastore.name
    container_path = "/data"
  }
  networks_advanced { name = data.docker_network.backend.name }
  depends_on = [null_resource.arr_scaffolding]
}

resource "docker_container" "recyclarr" {
  name    = "recyclarr"
  image   = "ghcr.io/recyclarr/recyclarr:latest"
  restart = "unless-stopped"
  user    = "1000:1000"
  env     = ["TZ=Asia/Manila"]
  volumes {
    host_path      = "/home/afterhours/apps/arr/config/recyclarr"
    container_path = "/config"
  }
  networks_advanced { name = data.docker_network.backend.name }
  depends_on = [null_resource.arr_scaffolding]
}

resource "docker_container" "maintainerr" {
  name    = "maintainerr"
  image   = "ghcr.io/maintainerr/maintainerr:latest"
  restart = "unless-stopped"
  env     = ["TZ=Asia/Manila"]
  ports {
    internal = 6246
    external = 6246
  }
  volumes {
    host_path      = "/home/afterhours/apps/arr/config/maintainerr"
    container_path = "/opt/data"
  }
  networks_advanced { name = data.docker_network.backend.name }
  depends_on = [null_resource.arr_scaffolding]
}

resource "docker_container" "decluttarr" {
  name    = "decluttarr"
  image   = "ghcr.io/manimatter/decluttarr:latest"
  restart = "unless-stopped"
  env     = ["PUID=1000", "PGID=1000", "TZ=Asia/Manila"]

  volumes {
    host_path      = "/home/afterhours/apps/arr/config/decluttarr"
    container_path = "/app/config"
  }

  volumes {
    volume_name    = docker_volume.usb_datastore.name
    container_path = "/data"
  }

  networks_advanced { name = data.docker_network.backend.name }
  
  depends_on = [
    null_resource.arr_scaffolding,
    docker_container.qbittorrent,
    docker_container.radarr,
    docker_container.sonarr
  ]
}

# -------------------------------------------------------------
# 5. FRONTEND APPLICATIONS (Attached to both Frontend & Backend)
# -------------------------------------------------------------

resource "docker_container" "seerr" {
  name    = "seerr"
  image   = "seerr/seerr:latest"
  restart = "unless-stopped"
  env     = ["TZ=Asia/Manila"]
  ports {
    internal = 5055
    external = 5055
  }
  volumes {
    host_path      = "/home/afterhours/apps/arr/config/seerr"
    container_path = "/app/config"
  }
  networks_advanced { name = data.docker_network.backend.name }
  networks_advanced { name = data.docker_network.frontend.name }
  depends_on = [null_resource.arr_scaffolding]
}

# resource "docker_container" "jellyfin" {
#   name    = "jellyfin"
#   image   = "lscr.io/linuxserver/jellyfin:latest"
#   restart = "unless-stopped"
#   group_add = ["44", "990"]
#   env     = ["PUID=1000", "PGID=1000", "TZ=Asia/Manila",
#             "DOCKER_MODS=linuxserver/mods:jellyfin-amd"]
#   ports {
#     internal = 8096
#     external = 8096
#   }
#   volumes {
#     host_path      = "/home/afterhours/apps/arr/config/jellyfin"
#     container_path = "/config"
#   }
#   volumes {
#     volume_name    = docker_volume.usb_datastore.name
#     container_path = "/data"
#   }
  
#   devices {
#     host_path      = "/dev/dri/renderD128"
#     container_path = "/dev/dri/renderD128"
#   }

#   devices {
#     host_path      = "/dev/kfd"
#     container_path = "/dev/kfd"
#   }

#   networks_advanced { name = data.docker_network.backend.name }
#   networks_advanced { name = data.docker_network.frontend.name }
#   depends_on = [null_resource.arr_scaffolding]
# }

# -------------------------------------------------------------
# Chaptarr - Audiobook + eBook Collection Manager
#
# Web UI:
#   http://192.168.1.170:8789
#
# Storage:
#   /data/books/downloads
#   /data/books/audiobooks
#   /data/books/ebooks
#
# qBittorrent:
#   Category:  chaptarr
#   Save Path: /data/books/downloads
# -------------------------------------------------------------

resource "docker_container" "chaptarr" {
  name    = "chaptarr"
  image   = "chaptarr/chaptarr:latest"
  restart = "unless-stopped"

  env = [
    "PUID=1000",
    "PGID=1000",
    "UMASK=002",
    "TZ=Asia/Manila"
  ]

  ports {
    internal = 8789
    external = 8789
  }

  # Chaptarr persistent config
  volumes {
    host_path      = "/home/afterhours/apps/arr/config/chaptarr"
    container_path = "/config"
  }

  # Shared datastore
  volumes {
    volume_name    = docker_volume.usb_datastore.name
    container_path = "/data"
  }

  networks_advanced {
    name = data.docker_network.backend.name
  }

  networks_advanced {
    name = data.docker_network.frontend.name
  }

  depends_on = [
    null_resource.arr_scaffolding,
    docker_container.qbittorrent,
    docker_container.prowlarr
  ]
}


resource "docker_container" "shelfarr" {
  name    = "shelfarr"
  image   = "ghcr.io/pedro-revez-silva/shelfarr:latest"
  restart = "unless-stopped"

  env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=Asia/Manila",
    "SOLID_QUEUE_IN_PUMA=1",
    "CHOWN_ON_START=never",
    "HTTP_PORT=5056"
  ]

  ports {
    internal = 5056
    external = 5056
  }

  # IMPORTANT:
  # Shelfarr database, users, settings, secrets, routing rules, etc.
  volumes {
    host_path      = "/home/afterhours/apps/arr/config/shelfarr"
    container_path = "/rails/storage"
  }

  # Dedicated CIFS view with Shelfarr-compatible permissions
  volumes {
    volume_name    = docker_volume.shelfarr_datastore.name
    container_path = "/data"
  }

  networks_advanced {
    name = data.docker_network.backend.name
  }

  networks_advanced {
    name = data.docker_network.frontend.name
  }

  depends_on = [
    null_resource.arr_scaffolding,
    docker_container.prowlarr,
    docker_container.qbittorrent
  ]
}


resource "docker_volume" "shelfarr_datastore" {
  name   = "shelfarr_datastore"
  driver = "local"

  driver_opts = {
    type   = "cifs"
    device = "//192.168.1.169/Proxmox-USB"
    o      = "username=afterhours,password=${var.usb_samba_password},uid=1000,gid=1000,file_mode=0640,dir_mode=0750,vers=3.0,iocharset=utf8"
  }
}
# resource "docker_container" "suggestarr" {
#   name    = "suggestarr"
#   image   = "ciuse99/suggestarr:latest"
#   restart = "unless-stopped"
  
#   ports {
#     internal = 5000
#     external = 5000
#   }

#   volumes {
#     host_path      = "/home/afterhours/apps/arr/config/suggestarr"
#     container_path = "/app/config/config_files"
#   }

#   networks_advanced { name = data.docker_network.backend.name }
#   networks_advanced { name = data.docker_network.frontend.name }
#   depends_on         = [null_resource.arr_scaffolding]
# }

resource "docker_container" "jellyfin_proxy" {
  name    = "jellyfin"
  image   = "caddy:2-alpine"
  restart = "unless-stopped"

  command = [
  "caddy",
  "reverse-proxy",
  "--from", ":8096",
  "--to", "http://192.168.1.174:8096"
]

  networks_advanced {
    name = data.docker_network.backend.name
  }

  networks_advanced {
    name = data.docker_network.frontend.name
  }
}