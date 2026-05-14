# terraform/ — Índice para IA

Provisionamento de VMs via Terraform + provider `dmacvicar/libvirt` v0.9.x.
Estrutura modular: cada VM é uma chamada do módulo `modules/vm/`.
Rede dedicada `homelab` (192.168.123.0/24) gerenciada como recurso compartilhado.

---

## Arquivos do root

| Arquivo | Responsabilidade |
|---------|-----------------|
| `main.tf` | Bloco `terraform` (versões, providers) e configuração do provider libvirt |
| `ssh.tf` | Geração do par ED25519 — chave compartilhada entre todas as VMs |
| `image.tf` | Imagem base Ubuntu 24.04 — recurso compartilhado |
| `network.tf` | Rede `homelab` (NAT, 192.168.123.0/24) — recurso compartilhado |
| `k8s.tf` | Módulo + outputs da VM do Kubernetes |
| `mongodb.tf` | Módulo + outputs da VM do MongoDB |
| `variables.tf` | Variáveis de root (storage_pool, ubuntu_image_url) |
| `outputs.tf` | Outputs de recursos compartilhados (rede, SSH user, chave) |

**Convenção:** cada VM dedicada tem seu próprio arquivo `.tf` no root, contendo
tanto a chamada do módulo quanto os outputs específicos daquela VM. O
`outputs.tf` central fica apenas com outputs de recursos compartilhados.

## Módulo `modules/vm/`

| Arquivo | Responsabilidade |
|---------|-----------------|
| `variables.tf` | Inputs do módulo (vm_name, sizing, ssh_public_key, ubuntu_base_path, network_name, static_ip, gateway) |
| `volumes.tf` | Disco principal (CoW sobre base) e ISO cloud-init |
| `cloudinit.tf` | Geração da config cloud-init via templates |
| `vm.tf` | Domínio KVM — CPU, memória, disco, rede, console |
| `outputs.tf` | vm_name |
| `cloud-init/user-data.tpl` | Usuário, SSH, swap, módulos de kernel (k8s) |
| `cloud-init/network-config.tpl` | Template: IP estático ou DHCP em enp1s0, condicional a var.static_ip |

---

## Dependências entre recursos

```
tls_private_key.homelab (root)
    ├── local_sensitive_file.private_key   (.ssh/homelab_ed25519)
    ├── local_file.public_key              (.ssh/homelab_ed25519.pub)
    └── module.<vm>.ssh_public_key         (input do módulo)

libvirt_volume.ubuntu_base (root)
    └── module.<vm>.ubuntu_base_path       (input do módulo)
        └── module.<vm>.libvirt_volume.vm_disk.backing_store

libvirt_network.homelab (root)
    └── module.<vm>.network_name           (input do módulo)
        └── module.<vm>.libvirt_domain.vm.devices.interfaces[0].source.network

(dentro do módulo:)
libvirt_cloudinit_disk.init
    └── libvirt_volume.cloudinit_iso       (url = init.path)

libvirt_volume.vm_disk    ──────┐
libvirt_volume.cloudinit_iso ───┼──▶ libvirt_domain.vm
```

---

## Convenção de endereçamento da rede `homelab`

CIDR `192.168.123.0/24`. Faixas reservadas:

| Faixa | Uso |
|---|---|
| `.1` | Gateway (libvirt — `virbr-homelab`) |
| `.10` – `.49` | IPs estáticos reservados (VMs gerenciadas, declarados via cloud-init) |
| `.50` – `.99` | Reserva (livre) |
| `.100` – `.254` | Pool DHCP (VMs efêmeras / testes) |

Alocação estática atual: `.10` k8s-node-01 (v0.5.5), `.20` mongodb-01 (v0.6.0),
`.30` kafka-01 (v0.7.0). Gaps de 10 entre VMs acomodam replica sets futuros.
Decisão registrada na ADR-011.

---

## Notas importantes

- Provider libvirt v0.9.x exige `driver.type = "qcow2"` explícito
  no disco principal — ver `runbook/libvirt.md` problema #5.
- Cdrom (cloud-init ISO) não leva `driver.type` — imagem raw.
- `create.start = true` faz a VM iniciar após `terraform apply`.
- IP estático da VM é exposto como output (`<vm>_vm_ip`) a partir do v0.5.5 —
  declarado no Terraform, não mais via `virsh domifaddr`.
- AppArmor requer extensão local em `libvirt-qemu.d/images` —
  ver `runbook/libvirt.md` problema #4.
- Refactor envolvendo movimentação de resources para dentro do
  módulo exige `terraform state mv` — ver `runbook/libvirt.md`
  problema #6.
- Provider libvirt v0.9.x rejeita `update in-place` em `libvirt_volume`
  mesmo quando o `terraform plan` propõe — sempre exige replace.
  Resolvido com `terraform apply -replace=` explícito. Ver
  `runbook/libvirt.md` problema #7.
- A imagem base Ubuntu fica no root (não no módulo) porque o nome
  do volume é fixo no pool (`ubuntu-24.04-base`) — colocá-la no
  módulo geraria conflito em chamadas múltiplas. Decisão registrada
  na ADR-008.
- A rede `homelab` também fica no root pelos mesmos motivos da imagem base
  (recurso compartilhado entre VMs). Decisão registrada na ADR-011.
