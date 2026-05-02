# ─── Imagem base Ubuntu ──────────────────────────────────────────────────────────
# Recurso compartilhado entre todas as VMs do homelab.
# Baixada uma única vez do upstream (~600 MB) e usada como backing store qcow2
# pelos discos das VMs (copy-on-write). Mantida no root (não no módulo) porque
# o nome do volume é fixo no pool — se ficasse no módulo, chamadas múltiplas
# gerariam conflito de nomes. Decisão registrada na ADR-008.

resource "libvirt_volume" "ubuntu_base" {
  name = "ubuntu-24.04-base"
  pool = var.storage_pool
  create = {
    format = "qcow2"
    content = {
      url = var.ubuntu_image_url
    }
  }
}
