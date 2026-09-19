locals {
  kindle_sync_script_raw = <<-SCRIPT
    #!/bin/sh
    set -eu

    touch /state/sent.txt

    echo "Kindle ingest sync started"

    while true; do
      now="$(date +%s)"

      find /source -type f \
        \( \
          -iname '*.epub' -o \
          -iname '*.mobi' -o \
          -iname '*.azw' -o \
          -iname '*.azw3' -o \
          -iname '*.pdf' \
        \) \
        -exec sh -c '
          now="$1"
          shift

          for f do
            mtime="$(stat -c %Y "$f")"
            size="$(stat -c %s "$f")"
            age=$((now - mtime))

            [ "$age" -lt 60 ] && continue

            key="$(
              printf "%s|%s|%s" "$f" "$size" "$mtime" \
                | sha256sum \
                | cut -d" " -f1
            )"

            grep -qxF "$key" /state/sent.txt && continue

            short="$(printf "%s" "$key" | cut -c1-12)"
            base="$(basename "$f")"

            tmp="/ingest/.$short-$base.tmp"
            dest="/ingest/$short-$base"

            echo "Copying to CWA ingest: $f"

            if cp "$f" "$tmp" && mv "$tmp" "$dest"; then
              echo "$key" >> /state/sent.txt
              echo "Queued for Kindle: $dest"
            else
              rm -f "$tmp"
            fi
          done
        ' sh "$now" {} +

      sleep 30
    done
  SCRIPT

  kindle_sync_script = replace(
    local.kindle_sync_script_raw,
    "\r\n",
    "\n"
  )
}


resource "null_resource" "calibre_web_automated_scaffolding" {
  triggers = {
    host        = "192.168.1.170"
    sync_script = sha256(local.kindle_sync_script)
  }

  connection {
    type        = "ssh"
    host        = "192.168.1.170"
    user        = "afterhours"
    private_key = file(pathexpand("~/.ssh/id_ed25519"))
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/apps/arr/config/calibre-web-automated",
      "mkdir -p ~/apps/arr/config/kindle-sync",

      # LOCAL filesystem for CWA's SQLite-backed Calibre library
      "mkdir -p ~/apps/arr/data/calibre-web-automated/library",

      # NAS-backed ingest remains fine
      "mkdir -p /mnt/usb-datastore/books/kindle-ingest",

      "chmod 750 ~/apps/arr/config/calibre-web-automated",
      "chmod 750 ~/apps/arr/config/kindle-sync",
      "chmod 750 ~/apps/arr/data/calibre-web-automated",
      "chmod 750 ~/apps/arr/data/calibre-web-automated/library",

      "touch ~/apps/arr/config/kindle-sync/sent.txt",

      "printf '%s' '${base64encode(local.kindle_sync_script)}' | base64 -d > ~/apps/arr/config/kindle-sync/sync.sh",
      "chmod 750 ~/apps/arr/config/kindle-sync/sync.sh"
    ]
  }
}


resource "docker_container" "calibre_web_automated" {
  name    = "calibre-web-automated"
  image   = "crocodilestick/calibre-web-automated:latest"
  restart = "unless-stopped"

  env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=Asia/Manila",
    "NETWORK_SHARE_MODE=true",
    "CWA_PORT_OVERRIDE=8083"
  ]

  ports {
    internal = 8083
    external = 8083
  }

  volumes {
    host_path      = "/home/afterhours/apps/arr/config/calibre-web-automated"
    container_path = "/config"
  }

  volumes {
    host_path      = "/mnt/usb-datastore/books/kindle-ingest"
    container_path = "/cwa-book-ingest"
  }

  # Keep Calibre metadata.db on the VM's local filesystem.
  volumes {
    host_path      = "/home/afterhours/apps/arr/data/calibre-web-automated/library"
    container_path = "/calibre-library"
  }

  networks_advanced {
    name = data.docker_network.frontend.name
  }

  networks_advanced {
    name = data.docker_network.backend.name
  }

  depends_on = [
    null_resource.calibre_web_automated_scaffolding,
    docker_container.shelfarr
  ]
}

resource "docker_container" "kindle_ingest_sync" {
  name    = "kindle-ingest-sync"
  image   = "alpine:3.22"
  restart = "unless-stopped"

  command = [
    "/bin/sh",
    "/state/sync.sh"
  ]

  volumes {
    host_path      = "/mnt/usb-datastore/books/ebooks"
    container_path = "/source"
    read_only      = true
  }

  volumes {
    host_path      = "/mnt/usb-datastore/books/kindle-ingest"
    container_path = "/ingest"
  }

  volumes {
    host_path      = "/home/afterhours/apps/arr/config/kindle-sync"
    container_path = "/state"
  }

  networks_advanced {
    name = data.docker_network.backend.name
  }

  depends_on = [
    null_resource.calibre_web_automated_scaffolding,
    docker_container.shelfarr,
    docker_container.calibre_web_automated
  ]
}