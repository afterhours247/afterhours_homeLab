resource "null_resource" "stacks_scaffolding" {
  triggers = {
    host = "192.168.1.170"
  }

  connection {
    type        = "ssh"
    host        = "192.168.1.170"
    user        = "afterhours"
    private_key = file(pathexpand("~/.ssh/id_ed25519"))
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/apps/arr/config/stacks",
      "mkdir -p ~/apps/arr/logs/stacks",
      "mkdir -p /mnt/usb-datastore/books/stacks-downloads",

      "sudo chown -R 1000:1000 ~/apps/arr/config/stacks",
      "sudo chown -R 1000:1000 ~/apps/arr/logs/stacks",

      "sudo chmod -R u+rwX,g+rX,o-rwx ~/apps/arr/config/stacks",
      "sudo chmod -R u+rwX,g+rX,o-rwx ~/apps/arr/logs/stacks"
    ]
  }
}


resource "docker_container" "stacks" {
  name    = "stacks"
  image   = "zelest/stacks:latest"
  restart = "unless-stopped"

  user = "1000:1000"

  env = [
    "TZ=Asia/Manila",
    "USERNAME=${var.stacks_username}",
    "PASSWORD=${var.stacks_password}"
  ]

  ports {
    internal = 7788
    external = 7788
  }

  volumes {
    host_path      = "/home/afterhours/apps/arr/config/stacks"
    container_path = "/opt/stacks/config"
  }

  volumes {
    host_path      = "/mnt/usb-datastore/books/stacks-downloads"
    container_path = "/opt/stacks/download"
  }

  volumes {
    host_path      = "/home/afterhours/apps/arr/logs/stacks"
    container_path = "/opt/stacks/logs"
  }

  networks_advanced {
    name = data.docker_network.backend.name
  }

  networks_advanced {
    name = data.docker_network.frontend.name
  }
}