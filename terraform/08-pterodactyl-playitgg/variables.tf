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

variable "playit_secret_key" {
  description = "Secret key for a dedicated Playit agent on vm-pterodactyl01"
  type        = string
  sensitive   = true
}

variable "pterodactyl_db_password" {
  description = "MariaDB application user password"
  type        = string
  sensitive   = true
}

variable "pterodactyl_db_root_password" {
  description = "MariaDB root password"
  type        = string
  sensitive   = true
}

variable "valheim_server_name" {
  description = "Name shown to players for the Valheim server"
  type        = string
  default     = "Afterhours Valheim"
}

variable "valheim_server_password" {
  description = "Valheim join password (5-20 characters)"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.valheim_server_password) >= 5 && length(var.valheim_server_password) <= 20
    error_message = "The Valheim server password must be between 5 and 20 characters."
  }
}

variable "valheim_world" {
  description = "Valheim world save name"
  type        = string
  default     = "Afterhours"
}
