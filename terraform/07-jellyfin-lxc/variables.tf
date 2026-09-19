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
  description = "Public SSH key"
  type        = string
}