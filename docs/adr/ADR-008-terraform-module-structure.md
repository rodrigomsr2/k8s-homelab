# ADR-008 — Estrutura modular do Terraform

**Status:** Aceito
**Data:** 2026-05-01

---

## Contexto

A partir do milestone `v0.6.0` o projeto provisiona múltiplas VMs
(MongoDB, Kafka) além da VM do k8s. A estrutura inicial do Terraform —
um conjunto de arquivos por responsabilidade no root (`vm.tf`,
`volumes.tf`, `cloudinit.tf`) com defaults únicos em `variables.tf` —
foi desenhada para uma única VM. Adicionar novas VMs sem refactor
implicaria duplicar resources, com convenções de nomes manuais
(`mongodb_disk`, `mongodb_vm`...) e divergência inevitável ao longo
do tempo.

---

## Decisão

Refatorar o Terraform para um módulo reutilizável `modules/vm/`.

O root contém apenas:
- Recursos **compartilhados**: chave SSH (`tls_private_key.homelab`),
  imagem base Ubuntu (`libvirt_volume.ubuntu_base`)
- Uma chamada `module` por VM, com sizing inline

O módulo `modules/vm/` encapsula tudo que é específico de uma VM:
disco principal, ISO cloud-init, domínio KVM, templates cloud-init.

A imagem base permanece no root porque o nome do volume é fixo no
pool (`ubuntu-24.04-base`) — colocá-la no módulo geraria conflito
de nomes em chamadas múltiplas.

---

## Consequências aceitas

- Refactor exige `terraform state mv` para preservar a infraestrutura
  existente. Procedimento documentado no runbook `libvirt.md`.
- Outputs do root passam a ser prefixados por VM (`k8s_vm_name` em
  vez de `vm_name`) — quebra de interface menor, documentada no
  CHANGELOG.
- Customizações específicas por VM (cloud-init com pacotes/runcmd
  diferentes, discos de dados extras) ainda não estão suportadas —
  serão adicionadas em `v0.6.0` quando o MongoDB exigir.

---

## Alternativas rejeitadas

**Resources paralelos (duplicação manual)**
Adicionar `mongodb_vm`, `mongodb_disk`, `mongodb_cloudinit` lado a
lado dos atuais. Funciona para 2 VMs, vira um pesadelo de
manutenção a partir de 3. Cada nova VM exige replicar e renomear
todos os resources.

**`for_each` sobre map de VMs**
Estruturar todas as VMs em uma única `variable "vms"` do tipo
`map(object({...}))` e usar `for_each`. Maximamente DRY e elegante
até uma VM precisar de algo que outra não tem (ex: disco de dados
extra, ou cloud-init customizado). A partir desse ponto vira
ginástica de `merge()`, `lookup()` com defaults e expressões
condicionais. Para um homelab com 3-4 VMs heterogêneas, módulo
explícito é mais legível.
