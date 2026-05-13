# ─── cloud-init ──────────────────────────────────────────────────────────────────
# Gera a configuração inicial da VM a partir dos templates em cloud-init/
# O libvirt_cloudinit_disk produz uma ISO que é montada como cdrom na VM
# e consumida pelo cloud-init durante o primeiro boot.
#
# O que é configurado via cloud-init (ver cloud-init/user-data.tpl):
#   - Usuário com sudo sem senha
#   - Autenticação SSH por chave ED25519 (senha desabilitada)
#   - Swap desabilitado (requisito do Kubernetes)
#   - Módulos de kernel overlay e br_netfilter (requisitos do Kubernetes)
#   - ip_forward habilitado (requisito de rede do Kubernetes)

resource "libvirt_cloudinit_disk" "init" {
  name = "${var.vm_name}-cloudinit"
  user_data = templatefile("${path.module}/cloud-init/user-data.tpl", {
    hostname   = var.vm_name
    username   = var.vm_user
    public_key = var.ssh_public_key
  })
  meta_data = jsonencode({
    "instance-id"    = var.vm_name
    "local-hostname" = var.vm_name
  })
  network_config = templatefile("${path.module}/cloud-init/network-config.tpl", {
    static_ip = var.static_ip
    gateway   = var.gateway
  })
}
