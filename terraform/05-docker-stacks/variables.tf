variable "proxmox_api_url" {
  description = "The URL for the Proxmox API"
  type        = string
}

variable "proxmox_api_token" {
  description = "The API token for the Proxmox user"
  type        = string
  sensitive   = true
}

variable "afterhours_pub_key" {
  type        = string
  description = "The public SSH key for the afterhours user account"
}

variable "vm-docker01_ip" {
  type        = string
  description = "The IP address for the docker01 VM"
}

variable "portainer_api_key" {
  description = "API Token for Portainer REST calls"
  type        = string
  sensitive   = true
}

variable "usb_samba_password" {
  type        = string
  description = "The password for backupuser to access the Proxmox Samba share"
  sensitive   = true
}

variable "qbit_password" {
  type        = string
  description = "The WebUI password for qBittorrent (used by Unpackerr)"
  sensitive   = true
}

variable "nocodb_jwt_secret" {
  description = "JWT secret for NocoDB"
  type        = string
  sensitive   = true
}

variable "dify_db_pass" {
  description = "Password for the Dify database"
  type        = string
  sensitive   = true
}

variable "dify_plugin_token" {
  description = "Plugin token for Dify"
  type        = string
  sensitive   = true
}

variable "dify_secret_key" {
  type        = string
  description = "Internal secret key for Dify session and cookie encryption"
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Password for the Grafana admin user"
  type        = string
  sensitive   = true
}

variable "langfuse_db_password" {
  description = "Postgres password for Langfuse database"
  type        = string
  sensitive   = true
}

variable "langfuse_nextauth_secret" {
  description = "NextAuth.js secret key for Langfuse session signing"
  type        = string
  sensitive   = true
}

variable "langfuse_salt" {
  description = "Salt value for Langfuse encryption"
  type        = string
  sensitive   = true
}

variable "langfuse_bcrypt_password" {
  description = "Bcrypt password hash for Langfuse admin user"
  type        = string
  sensitive   = true
}

variable "flowise_password" {
  description = "Password for Flowise basic authentication"
  type        = string
  sensitive   = true
}

variable "cloudflare_tunnel_token" {
  description = "Cloudflare Tunnel token"
  type        = string
  sensitive   = true
}

variable "browserless_token" {
  description = "Token for Browserless authentication"
  type        = string
  sensitive   = true
}

variable "minio_root_user" {
  description = "Root user for MinIO"
  type        = string
  sensitive   = true
}

variable "minio_root_password" {
  description = "Root password for MinIO"
  type        = string
  sensitive   = true
}

variable "minio_s3_access_key" {
  description = "S3 access key for MinIO"
  type        = string
  sensitive   = true
}

variable "minio_s3_secret_key" {
  description = "S3 secret key for MinIO"
  type        = string
  sensitive   = true
}

variable "playit_secret_key" {
  description = "Secret key for Playit"
  type        = string
  sensitive   = true
}

variable "windrose_server_password" {
  description = "Password for the Windrose server"
  type        = string
  sensitive   = true
}

variable "windrose_invite_code" {
  description = "Optional invite code for the Windrose server"
  type        = string
  sensitive   = true
}

variable "stacks_username" {
  description = "Username for Stacks"
  type        = string
}

variable "stacks_password" {
  description = "Password for Stacks"
  type        = string
  sensitive   = true
}