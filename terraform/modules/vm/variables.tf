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

variable "network_name" {
  description = "Nome da rede libvirt à qual a VM será conectada"
  type        = string
  default     = "default"
}

variable "static_ip" {
  description = <<-EOT
    IP estático opcional para a VM, configurado via cloud-init network-config.
    Quando null, a VM usa DHCP. Quando setado, deve estar fora do pool DHCP da
    rede correspondente. Formato: "192.168.123.10" (sem prefixo CIDR — o módulo
    assume /24). Quando setado, var.gateway também deve ser fornecida.
  EOT
  type        = string
  default     = null
}

variable "gateway" {
  description = <<-EOT
    Gateway IPv4 da rede. Obrigatório quando var.static_ip está setado.
    Para a rede default do libvirt: 192.168.122.1.
    Para a rede homelab: 192.168.123.1.
  EOT
  type        = string
  default     = null
}
