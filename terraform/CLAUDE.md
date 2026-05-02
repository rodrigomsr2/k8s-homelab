# terraform/ — Índice para IA

Provisionamento de VMs via Terraform + provider `dmacvicar/libvirt` v0.9.x.
Estrutura modular: cada VM é uma chamada do módulo `modules/vm/`.

---

## Arquivos do root

| Arquivo | Responsabilidade |
|---------|-----------------|
| `main.tf` | Bloco `terraform` (versões, providers) e configuração do provider libvirt |
| `ssh.tf` | Geração do par ED25519 — chave compartilhada entre todas as VMs |
| `image.tf` | Imagem base Ubuntu 24.04 — recurso compartilhado |
| `k8s.tf` | Chamada do módulo para a VM do Kubernetes |
| `variables.tf` | Variáveis de root (storage_pool, ubuntu_image_url) |
| `outputs.tf` | Outputs prefixados por VM |

## Módulo `modules/vm/`

| Arquivo | Responsabilidade |
|---------|-----------------|
| `variables.tf` | Inputs do módulo (vm_name, sizing, ssh_public_key, ubuntu_base_path) |
| `volumes.tf` | Disco principal (CoW sobre base) e ISO cloud-init |
| `cloudinit.tf` | Geração da config cloud-init via templates |
| `vm.tf` | Domínio KVM — CPU, memória, disco, rede, console |
| `outputs.tf` | vm_name |
| `cloud-init/user-data.tpl` | Usuário, SSH, swap, módulos de kernel (k8s) |
| `cloud-init/network-config.yaml` | DHCP em enp1s0, DNS 8.8.8.8 e 1.1.1.1 |

---

## Dependências entre recursos

```
tls_private_key.homelab (root)
    ├── local_sensitive_file.private_key   (.ssh/homelab_ed25519)
    ├── local_file.public_key              (.ssh/homelab_ed25519.pub)
    └── module.k8s.ssh_public_key          (input do módulo)

libvirt_volume.ubuntu_base (root)
    └── module.k8s.ubuntu_base_path        (input do módulo)
        └── module.k8s.libvirt_volume.vm_disk.backing_store

(dentro do módulo:)
libvirt_cloudinit_disk.init
    └── libvirt_volume.cloudinit_iso       (url = init.path)

libvirt_volume.vm_disk    ──────┐
libvirt_volume.cloudinit_iso ───┼──▶ libvirt_domain.vm
```

---

## Notas importantes

- Provider libvirt v0.9.x exige `driver.type = "qcow2"` explícito
  no disco principal — ver `runbook/libvirt.md` problema #5.
- Cdrom (cloud-init ISO) não leva `driver.type` — imagem raw.
- `create.start = true` faz a VM iniciar após `terraform apply`.
- IP da VM não é exposto como output — usar `virsh domifaddr <nome>`.
- AppArmor requer extensão local em `libvirt-qemu.d/images` —
  ver `runbook/libvirt.md` problema #4.
- Refactor envolvendo movimentação de resources para dentro do
  módulo exige `terraform state mv` — ver `runbook/libvirt.md`
  problema #6.
- A imagem base Ubuntu fica no root (não no módulo) porque o nome
  do volume é fixo no pool (`ubuntu-24.04-base`) — colocá-la no
  módulo geraria conflito em chamadas múltiplas. Decisão registrada
  na ADR-008.
