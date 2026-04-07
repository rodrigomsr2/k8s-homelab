variable "vm_name" {
  description = "Nome da VM"
  type        = string
  default     = "k8s-node-01"
}

variable "vm_user" {
  description = "Usuário padrão da VM"
  type        = string
  default     = "devops"
}

variable "memory_mb" {
  description = "RAM em MB"
  type        = number
  default     = 8192 # 8 GB
}

variable "vcpu" {
  description = "Número de vCPUs"
  type        = number
  default     = 4
}

variable "disk_size_bytes" {
  description = "Tamanho do disco em bytes"
  type        = number
  default     = 42949672960 # 40 GB
}

variable "storage_pool" {
  description = "Pool de armazenamento do libvirt"
  type        = string
  default     = "default"
}

variable "ubuntu_image_url" {
  description = "URL ou caminho local da imagem cloud do Ubuntu 24.04"
  type        = string
  default     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}
