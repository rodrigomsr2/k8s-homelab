# ─── VM ──────────────────────────────────────────────────────────────────────────
# Define o domínio KVM (a VM em si) com:
#   - CPU em modo host-passthrough (necessário para k8s nested)
#   - Disco principal qcow2 em virtio (vda)
#   - ISO cloud-init montada como cdrom sata (sda)
#   - Interface de rede na rede NAT default do libvirt
#   - Console serial para acesso via "virsh console"
#   - start = true: VM inicia automaticamente após terraform apply

resource "libvirt_domain" "vm" {
  name        = var.vm_name
  type        = "kvm"
  memory      = var.memory_mb * 1024
  memory_unit = "KiB"
  vcpu        = var.vcpu

  create = {
    start = true
  }

  cpu = {
    mode = "host-passthrough"
  }

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
  }

  features = {
    acpi = true
  }

  devices = {
    disks = [
      {
        driver = {
          name = "qemu"
          type = "qcow2"
        }
        source = {
          volume = {
            pool   = libvirt_volume.vm_disk.pool
            volume = libvirt_volume.vm_disk.name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = libvirt_volume.cloudinit_iso.pool
            volume = libvirt_volume.cloudinit_iso.name
          }
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
      }
    ]

    interfaces = [
      {
        model = {
          type = "virtio"
        }
        source = {
          network = {
            network = "default"
          }
        }
      }
    ]

    consoles = [
      {
        type = "pty"
        target = {
          type = "serial"
          port = 0
        }
      }
    ]
  }
}
