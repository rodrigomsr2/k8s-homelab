# VM do nó Kubernetes. Sizing definido pela ADR-002 (k3s):
#   4 vCPU / 8 GiB RAM / 40 GiB disco
# Suficiente para todo o stack futuro: monitoring, GitOps, microserviços,
# service mesh.
#
# Rede: homelab (ADR-011), IP estático 192.168.123.10 — primeira VM na faixa
# de IPs reservados (.10-.49).

module "k8s" {
  source = "./modules/vm"

  vm_name         = "k8s-node-01"
  memory_mb       = 8192
  vcpu            = 4
  disk_size_bytes = 42949672960 # 40 GiB

  storage_pool     = var.storage_pool
  ubuntu_base_path = libvirt_volume.ubuntu_base.path
  ssh_public_key   = tls_private_key.homelab.public_key_openssh

  network_name = libvirt_network.homelab.name
  static_ip    = "192.168.123.10"
  gateway      = "192.168.123.1"
}

# ─── Outputs específicos da VM ─────────────────────────────────────────────────

output "k8s_vm_name" {
  description = "Nome da VM do Kubernetes"
  value       = module.k8s.vm_name
}

output "k8s_vm_ip" {
  description = "IP estático da VM do Kubernetes na rede homelab"
  value       = "192.168.123.10"
}
