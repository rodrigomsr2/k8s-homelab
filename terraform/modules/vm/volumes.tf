# ─── Volumes da VM ───────────────────────────────────────────────────────────────
# Disco principal qcow2 com copy-on-write sobre a imagem base Ubuntu.
# A imagem base é compartilhada entre todas as VMs do homelab — gerenciada no root.
# A ISO cloud-init é gerada a partir do user_data + network_config + meta_data
# definidos em cloudinit.tf e montada como cdrom no domínio.

resource "libvirt_volume" "vm_disk" {
  name     = "${var.vm_name}-disk.qcow2"
  pool     = var.storage_pool
  capacity = var.disk_size_bytes
  target = {
    format = {
      type = "qcow2"
    }
  }
  backing_store = {
    path = var.ubuntu_base_path
    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_volume" "cloudinit_iso" {
  name = "${var.vm_name}-cloudinit.iso"
  pool = var.storage_pool
  create = {
    content = {
      url = libvirt_cloudinit_disk.init.path
    }
  }
}
