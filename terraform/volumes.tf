# ─── Volumes ─────────────────────────────────────────────────────────────────────
# Três volumes no pool default do libvirt:
#   ubuntu_base    — imagem Ubuntu 24.04 cloud baixada do upstream (~600 MB)
#   vm_disk        — disco principal da VM (copy-on-write sobre ubuntu_base)
#   cloudinit_iso  — ISO gerada pelo libvirt_cloudinit_disk, montada como cdrom

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
    path = libvirt_volume.ubuntu_base.path
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
