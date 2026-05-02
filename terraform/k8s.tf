# ─── VM do Kubernetes ────────────────────────────────────────────────────────────
# Sizing definido pela ADR-002 (k3s):
#   4 vCPU / 8 GiB RAM / 40 GiB disco
# Suficiente para todo o stack futuro: monitoring, GitOps, microserviços,
# service mesh.

module "k8s" {
  source = "./modules/vm"

  vm_name         = "k8s-node-01"
  memory_mb       = 8192
  vcpu            = 4
  disk_size_bytes = 42949672960 # 40 GiB

  storage_pool     = var.storage_pool
  ubuntu_base_path = libvirt_volume.ubuntu_base.path
  ssh_public_key   = tls_private_key.homelab.public_key_openssh
}
