# VM do MongoDB standalone. Sizing definido pela ADR-012:
#   2 vCPU / 4 GiB RAM / 20 GiB disco
# Standalone, sem auth, sem replica set — minimalismo deliberado.
# Cada limitação vira aprendizado quando for sentida na prática.
#
# Rede: homelab (ADR-011), IP estático 192.168.123.20 — segunda VM na faixa
# de IPs reservados (.10-.49), com gap de 10 para acomodar replica set futuro.

module "mongodb" {
  source = "./modules/vm"

  vm_name         = "mongodb-01"
  memory_mb       = 4096
  vcpu            = 2
  disk_size_bytes = 21474836480 # 20 GiB

  storage_pool     = var.storage_pool
  ubuntu_base_path = libvirt_volume.ubuntu_base.path
  ssh_public_key   = tls_private_key.homelab.public_key_openssh

  network_name = libvirt_network.homelab.name
  static_ip    = "192.168.123.20"
  gateway      = "192.168.123.1"
}

# ─── Outputs específicos da VM ─────────────────────────────────────────────────

output "mongodb_vm_name" {
  description = "Nome da VM do MongoDB"
  value       = module.mongodb.vm_name
}

output "mongodb_vm_ip" {
  description = "IP estático da VM do MongoDB na rede homelab"
  value       = "192.168.123.20"
}
