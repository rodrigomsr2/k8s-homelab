variable "vm_name" {
  description = "Nome da VM (também usado como hostname)"
  type        = string
}

variable "vm_user" {
  description = "Usuário padrão da VM com sudo NOPASSWD"
  type        = string
  default     = "devops"
}

variable "memory_mb" {
  description = "RAM em MB"
  type        = number
}

variable "vcpu" {
  description = "Número de vCPUs"
  type        = number
}

variable "disk_size_bytes" {
  description = "Tamanho do disco principal (sobre o backing store) em bytes"
  type        = number
}

variable "storage_pool" {
  description = "Pool de armazenamento do libvirt"
  type        = string
  default     = "default"
}

variable "ubuntu_base_path" {
  description = "Path do volume base Ubuntu, gerenciado no root como recurso compartilhado"
  type        = string
}

variable "ssh_public_key" {
  description = "Chave pública SSH a injetar via cloud-init no usuário"
  type        = string
}
