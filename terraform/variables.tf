variable "storage_pool" {
  description = "Pool de armazenamento do libvirt usado por todas as VMs e pela imagem base"
  type        = string
  default     = "default"
}

variable "ubuntu_image_url" {
  description = "URL da imagem cloud Ubuntu 24.04 (baixada uma vez, compartilhada via CoW)"
  type        = string
  default     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}
