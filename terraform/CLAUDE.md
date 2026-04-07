# terraform/ — Índice para IA

Provisionamento da VM via Terraform + provider `dmacvicar/libvirt` v0.9.x.

---

## Arquivos

| Arquivo | Responsabilidade |
|---------|-----------------|
| `main.tf` | Bloco `terraform` (versões, providers) e configuração do provider libvirt |
| `ssh.tf` | Geração do par de chaves ED25519 e salvamento local em `.ssh/` |
| `volumes.tf` | Imagem base Ubuntu, disco da VM (CoW), ISO cloud-init |
| `cloudinit.tf` | Configuração cloud-init gerada a partir dos templates em `cloud-init/` |
| `vm.tf` | Domínio KVM — a VM em si (CPU, disco, rede, console) |
| `variables.tf` | Todas as variáveis configuráveis do módulo |
| `outputs.tf` | Outputs pós-apply (nome da VM, usuário SSH, path da chave) |

## Templates

| Arquivo | O que faz |
|---------|-----------|
| `cloud-init/user-data.tpl` | Configura usuário, SSH, swap, módulos de kernel |
| `cloud-init/network-config.yaml` | DHCP na interface enp1s0, DNS 8.8.8.8 e 1.1.1.1 |

---

## Dependências entre recursos

```
tls_private_key.homelab
    ├── local_sensitive_file.private_key   (.ssh/homelab_ed25519)
    ├── local_file.public_key              (.ssh/homelab_ed25519.pub)
    └── libvirt_cloudinit_disk.init        (public_key injetada no user-data)

libvirt_volume.ubuntu_base
    └── libvirt_volume.vm_disk             (backing_store)

libvirt_cloudinit_disk.init
    └── libvirt_volume.cloudinit_iso       (url = init.path)

libvirt_volume.vm_disk ──────┐
libvirt_volume.cloudinit_iso ┼──▶ libvirt_domain.vm
```

---

## Notas importantes

- O provider libvirt v0.9.x exige que o tipo do driver seja declarado
  explicitamente no disco principal (`driver.type = "qcow2"`). Omitir resulta
  em `raw` implícito e a VM trava na inicialização sem erro claro.
- O cdrom (cloud-init ISO) não leva `driver.type` — é uma imagem raw.
- `create.start = true` no `libvirt_domain` faz a VM iniciar imediatamente
  após o `terraform apply`, sem necessidade de `virsh start` manual.
- O IP da VM não é exposto como output — obtê-lo via `virsh domifaddr <nome>`.
- O AppArmor requer a extensão local em
  `/etc/apparmor.d/abstractions/libvirt-qemu.d/images` para permitir acesso
  ao `/var/lib/libvirt/images/`. Ver `docs/runbook/libvirt.md` problema 4.
