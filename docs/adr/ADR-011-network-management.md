# ADR-011 — Rede homelab gerenciada via Terraform

## Status

Aceita — `v0.5.5`

## Contexto

Até o `v0.5.4`, todas as VMs do projeto viviam na rede `default` do libvirt:
um recurso pré-criado pela instalação do pacote, com pool DHCP `192.168.122.2`
até `192.168.122.254`, fora do controle do Terraform.

O `v0.6.0` introduz a primeira VM dedicada a um serviço integrado (MongoDB),
e os milestones seguintes adicionam mais (Kafka, microserviços). O fato de
que essas VMs precisam se enxergar pelo IP — para que microserviços no k8s
consumam Mongo e Kafka — exige IPs previsíveis. DHCP dinâmico inviabiliza
declarar endpoints em ConfigMaps, Secrets ou variáveis de ambiente.

A pergunta passa a ser: **como reservar IPs estáticos para as VMs**?

## Decisão

Criar uma **rede dedicada `homelab`** gerenciada pelo Terraform como recurso
`libvirt_network`, com CIDR `192.168.123.0/24` e convenção de alocação que
separa range estático (gerenciado pelo Terraform via cloud-init) de pool DHCP
(reserva para VMs efêmeras ou testes futuros).

**Endereçamento:**

| Faixa | Uso |
|---|---|
| `192.168.123.1` | Gateway (libvirt — `virbr-homelab`) |
| `192.168.123.10` – `.49` | IPs estáticos reservados (VMs gerenciadas) |
| `192.168.123.50` – `.99` | Reserva (livre, sem propósito ainda) |
| `192.168.123.100` – `.254` | Pool DHCP (VMs efêmeras / testes) |

**Alocação estática:**

| IP | VM | Milestone |
|---|---|---|
| `192.168.123.10` | `k8s-node-01` | `v0.5.5` (migração) |
| `192.168.123.20` | `mongodb-01` | `v0.6.0` |
| `192.168.123.30` | `kafka-01` | `v0.7.0` |

Gaps de 10 entre cada VM acomodam crescimento (replica set, múltiplos nós)
sem reorganizar o esquema.

**Como o IP estático chega na VM:** via cloud-init `network-config`,
não via DHCP reservation. O módulo `modules/vm/` aceita variáveis
`static_ip` e `gateway`; quando setadas, o template `network-config.tpl`
gera `addresses: [<ip>/24]` em vez de `dhcp4: true`. A rede `homelab` continua
com DHCP **habilitado** para acomodar VMs futuras que não declarem IP fixo.

## Consequências aceitas

- **Destroy/create da VM do k8s na migração.** Mudar `network_name` no
  `libvirt_domain` força recriação. O cluster k3s e tudo dele é
  reconstruído via `bootstrap-cluster.yml` + ressincronização do ArgoCD a
  partir do `k8s-gitops`. Validado no `v0.5.5`.
- **Volumes locais perdidos no destroy.** PVs do k3s (Loki, Grafana) e
  imagens de container cacheadas no node são perdidos. Não há backup —
  a filosofia do projeto é "ambiente reconstruível do zero" via GitOps.
- **`/etc/hosts` do host físico precisa ser atualizado** após a migração.
  Resolução de `*.homelab.local` continua sendo gambiarra local até um
  futuro milestone de DNS gerenciado (ver "Trabalhos futuros").
- **Inventário Ansible precisa ser atualizado** (`hosts.ini` é gitignored
  com IP local).
- **Coexistência com a rede `default`.** A rede `default` continua existindo
  no libvirt, intocada. Outras VMs fora do projeto (se houver) seguem
  funcionando. O Terraform só gerencia a `homelab`.
- **Provider libvirt v0.9.x: `update in-place` sobre `libvirt_volume`
  falha em runtime.** O plan propõe in-place, o apply rejeita com
  "Storage volumes cannot be updated". Resolvido no `v0.5.5` com
  `terraform apply -replace=` explícito no `cloudinit_iso`. Vale entrar
  no runbook do libvirt como problema #7.

## Alternativas rejeitadas

### (a) Manter a rede `default` e configurar DHCP reservation

Editar a `default` para adicionar `<host mac='...' ip='...'>` no bloco
`<dhcp>`. **Rejeitada** porque exige que o Terraform gerencie a `default`,
o que significaria importá-la para o state (`terraform import`). Se um
dia `terraform destroy` fosse executado, levaria junto a rede que serve
qualquer outra VM fora do projeto na máquina. Acoplamento perigoso para
um homelab que coexiste com outras coisas.

### (b) IP estático apenas via cloud-init, sem rede nova

Configurar a interface da VM com IP estático no `network-config`, escolhendo
um endereço fora do pool DHCP da `default` (ex: `192.168.122.50`).
**Rejeitada** porque (1) mantém a `default` como dependência implícita
do projeto, (2) não tem garantia formal de que o IP escolhido não vai
colidir com algum lease futuro do DHCP da `default`, (3) não dá ao
projeto uma rede própria que possa evoluir (DNS interno, regras de
firewall, segregação) sem afetar outras VMs.

### (c) Rede em modo `bridge` (acesso à LAN física)

Expor as VMs diretamente na rede da casa/escritório. **Rejeitada** —
desnecessário (não precisamos de acesso a partir de outros dispositivos
da LAN), aumenta superfície de exposição, e amarra o projeto à
topologia da rede física do host.

### (d) Rede em modo `isolated` (sem NAT, sem internet)

VMs se enxergariam entre si mas não teriam acesso à internet. **Rejeitada**
— quebra `apt`, `docker pull`, GitOps puxando do GitHub, qualquer coisa
de fora. Forçaria dual-NIC (uma na `isolated`, outra na `default`) com
todos os problemas associados (asymmetric routing, complexidade no
cloud-init, mais uma peça pra documentar).

### (e) Dual-NIC: VM com interface na `default` (internet) + na `homelab` (inter-VM)

**Rejeitada** após análise — a rede `homelab`, sendo NAT, dá acesso à
internet pelo mesmo masquerade que a `default`. Dual-NIC não resolveria
um problema real, apenas adicionaria complexidade (qual interface é
default route, como o Ansible escolhe o IP "principal", como ingresses
sabem qual IP usar).

## Trabalhos futuros

- **DNS gerenciado via libvirt dnsmasq.** A rede `homelab` poderia ter
  `dns { domain = "homelab.local", local_only = false }` declarado e
  expor entradas estáticas para `argocd.homelab.local`,
  `grafana.homelab.local`, etc. Combinado com `systemd-resolved` configurado
  no host físico para split DNS, eliminaria a edição manual de `/etc/hosts`.
  Candidato a milestone próprio (ex: `v0.5.6` — `dns-managed`).
- **Network Policies do k8s** para restringir tráfego saindo do cluster
  para as VMs MongoDB/Kafka. Faz parte do milestone de
  hardening de segurança previsto no roadmap (`v0.11.0`).

## Referências

- ADR-008 — estrutura modular do Terraform (precondição deste ADR).
- `docs/runbook/libvirt.md` — procedimento de migração de rede no
  provider libvirt v0.9.x.
- `docs/guides/network.md` — guia operacional da rede `homelab`.
