resource "docker_image" "playit" {
  name         = "ghcr.io/playit-cloud/playit-agent:latest"
  keep_locally = true
}

resource "docker_volume" "playit_data" {
  name = "pterodactyl-playit-data"
}

resource "docker_container" "playit" {
  name         = "pterodactyl-playit"
  image        = docker_image.playit.image_id
  restart      = "unless-stopped"
  network_mode = "host"

  env = [
    "SECRET_KEY=${var.playit_secret_key}",
  ]

  volumes {
    volume_name    = docker_volume.playit_data.name
    container_path = "/etc/playit"
  }
}
