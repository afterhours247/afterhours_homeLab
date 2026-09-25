resource "docker_image" "playit" {
  name         = "ghcr.io/playit-cloud/playit-agent:latest"
  keep_locally = true
}

resource "null_resource" "playit_scaffolding" {
  triggers = {
    host            = "192.168.1.175"
    data_path       = "/home/afterhours/apps/playit/data"
    source_data     = docker_volume.playit_data.name
    scaffold_sha256 = filesha256("${path.module}/stack_playitgg.tf")
  }

  connection {
    type        = "ssh"
    user        = "afterhours"
    private_key = file(pathexpand("~/.ssh/id_ed25519"))
    host        = "192.168.1.175"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /home/afterhours/apps/playit/data",
      "sudo docker run --rm --volume pterodactyl-playit-data:/source:ro --volume /home/afterhours/apps/playit/data:/target busybox:1.36 sh -c 'cp -an /source/. /target/ && chown -R 1000:1000 /target'",
      "sudo chown -R 1000:1000 /home/afterhours/apps/playit/data",
      "sudo chmod 700 /home/afterhours/apps/playit/data",
    ]
  }

  depends_on = [docker_volume.playit_data]
}

resource "docker_volume" "playit_data" {
  name = "pterodactyl-playit-data"
}

resource "docker_container" "playit" {
  name         = "pterodactyl-playit"
  image        = docker_image.playit.image_id
  restart      = "unless-stopped"
  network_mode = "host"

  # Configure or recover the Playit key in Playit's Docker setup wizard:
  # https://playit.gg/account/setup/wizard/new-account/docker/docker-name
  # Store the generated SECRET_KEY in the ignored terraform.tfvars as
  # playit_secret_key, then replace this container with Terraform.

  env = [
    "SECRET_KEY=${var.playit_secret_key}"
  ]
  # Note: No 'ports' block is needed!
  # Playit creates an outbound reverse-tunnel to their cloud, completely bypassing your ISP's CGNAT.

  volumes {
    # Maps the local folder we created in the scaffolding to Playit's internal config directory.
    # This ensures your secret key and claim link persist across container rebuilds/restarts.
    host_path      = "/home/afterhours/apps/playit/data"
    container_path = "/etc/playit"
  }

  depends_on = [null_resource.playit_scaffolding]
}
