resource "docker_network" "pterodactyl_backend" {
  name   = "pterodactyl-backend"
  driver = "bridge"
}

resource "docker_network" "pterodactyl_wings" {
  name   = "pterodactyl-wings"
  driver = "bridge"

  ipam_config {
    subnet      = "172.21.0.0/16"
    gateway     = "172.21.0.1"
    aux_address = {}
  }

}

resource "docker_image" "pterodactyl_panel" {
  name         = "ghcr.io/pterodactyl/panel:latest"
  keep_locally = true
}

resource "docker_image" "pterodactyl_mariadb" {
  name         = "mariadb:11"
  keep_locally = true
}

resource "docker_image" "pterodactyl_redis" {
  name         = "redis:7-alpine"
  keep_locally = true
}

resource "docker_image" "pterodactyl_wings" {
  name         = "ghcr.io/pterodactyl/wings:latest"
  keep_locally = true
}

resource "docker_volume" "pterodactyl_database" {
  name = "pterodactyl-database"
}

resource "docker_volume" "pterodactyl_panel_var" {
  name = "pterodactyl-panel-var"
}

resource "docker_volume" "pterodactyl_panel_nginx" {
  name = "pterodactyl-panel-nginx"
}

resource "docker_volume" "pterodactyl_panel_certs" {
  name = "pterodactyl-panel-certs"
}

resource "docker_volume" "pterodactyl_panel_logs" {
  name = "pterodactyl-panel-logs"
}

resource "docker_container" "pterodactyl_database" {
  name    = "pterodactyl-database"
  image   = docker_image.pterodactyl_mariadb.image_id
  restart = "unless-stopped"

  env = [
    "MYSQL_DATABASE=panel",
    "MYSQL_USER=pterodactyl",
    "MYSQL_PASSWORD=${var.pterodactyl_db_password}",
    "MYSQL_ROOT_PASSWORD=${var.pterodactyl_db_root_password}",
  ]

  volumes {
    volume_name    = docker_volume.pterodactyl_database.name
    container_path = "/var/lib/mysql"
  }

  networks_advanced {
    name = docker_network.pterodactyl_backend.name
  }
}

resource "docker_container" "pterodactyl_cache" {
  name    = "pterodactyl-cache"
  image   = docker_image.pterodactyl_redis.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.pterodactyl_backend.name
  }
}

resource "docker_container" "pterodactyl_panel" {
  name    = "pterodactyl-panel"
  image   = docker_image.pterodactyl_panel.image_id
  restart = "unless-stopped"

  env = [
    "APP_URL=http://192.168.1.175",
    "APP_TIMEZONE=Asia/Manila",
    "APP_SERVICE_AUTHOR=afterhours@localhost",
    "APP_ENV=production",
    "APP_ENVIRONMENT_ONLY=false",
    "CACHE_DRIVER=redis",
    "SESSION_DRIVER=redis",
    "QUEUE_DRIVER=redis",
    "REDIS_HOST=pterodactyl-cache",
    "DB_HOST=pterodactyl-database",
    "DB_PORT=3306",
    "DB_DATABASE=panel",
    "DB_USERNAME=pterodactyl",
    "DB_PASSWORD=${var.pterodactyl_db_password}",
    "MAIL_FROM=afterhours@localhost",
    "MAIL_DRIVER=log",
    "MAIL_HOST=localhost",
    "MAIL_PORT=1025",
    "MAIL_USERNAME=",
    "MAIL_PASSWORD=",
    "MAIL_ENCRYPTION=false",
    "HASHIDS_LENGTH=8",
  ]

  ports {
    internal = 80
    external = 80
  }

  volumes {
    volume_name    = docker_volume.pterodactyl_panel_var.name
    container_path = "/app/var"
  }

  volumes {
    volume_name    = docker_volume.pterodactyl_panel_nginx.name
    container_path = "/etc/nginx/http.d"
  }

  volumes {
    volume_name    = docker_volume.pterodactyl_panel_certs.name
    container_path = "/etc/letsencrypt"
  }

  volumes {
    volume_name    = docker_volume.pterodactyl_panel_logs.name
    container_path = "/app/storage/logs"
  }

  networks_advanced {
    name = docker_network.pterodactyl_backend.name
  }

  depends_on = [
    docker_container.pterodactyl_database,
    docker_container.pterodactyl_cache,
  ]
}

resource "docker_container" "pterodactyl_wings" {
  name     = "pterodactyl-wings"
  image    = docker_image.pterodactyl_wings.image_id
  restart  = "unless-stopped"
  start    = true
  must_run = true
  tty      = true
  env      = ["TZ=Asia/Manila"]

  ports {
    internal = 8080
    external = 8080
  }

  ports {
    internal = 2022
    external = 2022
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }

  volumes {
    host_path      = "/var/lib/docker/containers"
    container_path = "/var/lib/docker/containers"
  }

  volumes {
    host_path      = "/etc/pterodactyl"
    container_path = "/etc/pterodactyl"
  }

  volumes {
    host_path      = "/var/lib/pterodactyl"
    container_path = "/var/lib/pterodactyl"
  }

  volumes {
    host_path      = "/var/log/pterodactyl"
    container_path = "/var/log/pterodactyl"
  }

  volumes {
    host_path      = "/tmp/pterodactyl"
    container_path = "/tmp/pterodactyl"
  }

  volumes {
    host_path      = "/etc/ssl/certs"
    container_path = "/etc/ssl/certs"
    read_only      = true
  }

  volumes {
    host_path      = "/run/wings"
    container_path = "/run/wings"
  }

  networks_advanced {
    name = docker_network.pterodactyl_wings.name
  }

  depends_on = [null_resource.pterodactyl_bootstrap]
}

# Follow the existing Docker-stack pattern: create host paths, transfer the
# pinned egg and bootstrap script, then configure Panel/Wings over SSH.
resource "null_resource" "pterodactyl_bootstrap" {
  triggers = {
    bootstrap_sha256 = filesha256("${path.module}/scripts/provision-pterodactyl.php")
    egg_sha256       = filesha256("${path.module}/assets/egg-valheim.json")
    panel_image      = docker_image.pterodactyl_panel.image_id
  }

  connection {
    type        = "ssh"
    user        = "afterhours"
    private_key = file(pathexpand("~/.ssh/id_ed25519"))
    host        = "192.168.1.175"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/provision-pterodactyl.php"
    destination = "/tmp/provision-pterodactyl.php"
  }

  provisioner "file" {
    source      = "${path.module}/assets/egg-valheim.json"
    destination = "/tmp/egg-valheim.json"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eu",
      "mkdir -p /tmp/pterodactyl-bootstrap",
      "sudo mkdir -p /etc/pterodactyl /var/lib/pterodactyl/volumes /var/log/pterodactyl /tmp/pterodactyl /run/wings",
      "sudo chmod 700 /etc/pterodactyl",
      "printf '%s' '${base64encode(jsonencode({ create_server = false }))}' | base64 -d | sudo tee /tmp/pterodactyl-bootstrap.json >/dev/null",
      "sudo chmod 600 /tmp/pterodactyl-bootstrap.json",
      "until curl -fsS http://127.0.0.1/login >/dev/null; do sleep 5; done",
      "sudo docker cp /tmp/provision-pterodactyl.php pterodactyl-panel:/tmp/provision-pterodactyl.php",
      "sudo docker cp /tmp/egg-valheim.json pterodactyl-panel:/tmp/egg-valheim.json",
      "sudo docker cp /tmp/pterodactyl-bootstrap.json pterodactyl-panel:/tmp/pterodactyl-bootstrap.json",
      "sudo docker exec pterodactyl-panel php /tmp/provision-pterodactyl.php",
      "sudo docker cp pterodactyl-panel:/tmp/wings-config.yml /tmp/wings-config.yml",
      "sudo install -o root -g root -m 600 /tmp/wings-config.yml /etc/pterodactyl/config.yml",
      "sudo rm -f /tmp/pterodactyl-bootstrap.json /tmp/provision-pterodactyl.php /tmp/egg-valheim.json /tmp/wings-config.yml",
      "sudo docker exec pterodactyl-panel rm -f /tmp/pterodactyl-bootstrap.json /tmp/provision-pterodactyl.php /tmp/egg-valheim.json /tmp/wings-config.yml",
    ]
  }

  depends_on = [
    docker_container.pterodactyl_panel,
  ]
}

# Create/update the game server only after Wings is running and registered.
resource "null_resource" "pterodactyl_valheim" {
  triggers = {
    bootstrap_sha256 = filesha256("${path.module}/scripts/provision-pterodactyl.php")
    egg_sha256       = filesha256("${path.module}/assets/egg-valheim.json")
    panel_image      = docker_image.pterodactyl_panel.image_id
    server_name      = var.valheim_server_name
    server_password  = sha256(var.valheim_server_password)
    world_name       = var.valheim_world
  }

  connection {
    type        = "ssh"
    user        = "afterhours"
    private_key = file(pathexpand("~/.ssh/id_ed25519"))
    host        = "192.168.1.175"
    timeout     = "20m"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/provision-pterodactyl.php"
    destination = "/tmp/provision-pterodactyl.php"
  }

  provisioner "file" {
    source      = "${path.module}/assets/egg-valheim.json"
    destination = "/tmp/egg-valheim.json"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eu",
      "printf '%s' '${base64encode(jsonencode({ create_server = true, server_name = var.valheim_server_name, server_password = var.valheim_server_password, world_name = var.valheim_world }))}' | base64 -d | sudo tee /tmp/pterodactyl-bootstrap.json >/dev/null",
      "sudo chmod 600 /tmp/pterodactyl-bootstrap.json",
      "until curl --silent --output /dev/null http://127.0.0.1:8080; do sleep 5; done",
      "sudo docker cp /tmp/provision-pterodactyl.php pterodactyl-panel:/tmp/provision-pterodactyl.php",
      "sudo docker cp /tmp/egg-valheim.json pterodactyl-panel:/tmp/egg-valheim.json",
      "sudo docker cp /tmp/pterodactyl-bootstrap.json pterodactyl-panel:/tmp/pterodactyl-bootstrap.json",
      "sudo docker exec pterodactyl-panel php /tmp/provision-pterodactyl.php",
      "sudo rm -f /tmp/pterodactyl-bootstrap.json /tmp/provision-pterodactyl.php /tmp/egg-valheim.json",
      "sudo docker exec pterodactyl-panel rm -f /tmp/pterodactyl-bootstrap.json /tmp/provision-pterodactyl.php /tmp/egg-valheim.json /tmp/wings-config.yml",
    ]
  }

  depends_on = [
    docker_container.pterodactyl_wings,
  ]
}