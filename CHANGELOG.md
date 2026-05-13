# Changelog

Todas as mudanças relevantes deste projeto são documentadas aqui.

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/).
Versionamento segue [Semantic Versioning](https://semver.org/lang/pt-BR/) — ver `.claude/skills/semver.md`.

---

## [Unreleased]

---

## [0.5.5] — network-managed — 2026-05-13

### Added
- Rede `libvirt_network "homelab"` gerenciada pelo Terraform — CIDR `192.168.123.0/24`, NAT, bridge dedicado `virbr-homelab`, pool DHCP `.100–.254`. Convenção de alocação reserva `.10–.49` para IPs estáticos de VMs gerenciadas (`terraform/network.tf`).
- Variáveis `network_name`, `static_ip`, `gateway` no módulo `modules/vm/` — features aditivas com defaults retrocompatíveis (network `"default"`, IPs `null`).
- Template `cloud-init/network-config.tpl` com lógica condicional: gera bloco `addresses + routes` quando `static_ip` está setado, ou `dhcp4: true` quando não.
- Outputs `k8s_vm_ip` e `homelab_network_name` no root.
- ADR-012 — racional da rede dedicada, alternativas rejeitadas (`default` + DHCP reservation, cloud-init static sem rede nova, bridge, isolated, dual-NIC).

### Changed
- VM `k8s-node-01` migrada da rede `default` para `homelab` com IP estático `192.168.123.10`.
- `scripts/validate-connectivity.sh` lê IP via `terraform output -raw k8s_vm_ip` em vez de `virsh domifaddr` — necessário porque IP estático não gera DHCP lease.
- `scripts/validate-gitops.sh` referencia ApplicationSet `homelab` (renomeado no `v0.5.3` — atualização atrasada visível agora que o ambiente foi reconstruído do zero).

### Migration notes
- O `terraform apply` da migração exigiu `-replace=` explícito em três pontos: `module.k8s.libvirt_domain.vm` e `module.k8s.libvirt_volume.vm_disk` (forçados para garantir re-execução do cloud-init com `network-config` novo), e `module.k8s.libvirt_volume.cloudinit_iso` (provider rejeita `update in-place` em volumes — bug do provider v0.9.x, ver runbook).
- Após `terraform apply`: cluster k3s reconstruído via `ansible-playbook bootstrap-cluster.yml`; ArgoCD ressincronizou monitoring, applications e configs a partir do `k8s-gitops` automaticamente. Tempo total da migração: ~10 minutos.
- Atualizações manuais pós-migração: `/etc/hosts` do host físico, `CLAUDE.local.md` (gitignored), `ansible/inventory/hosts.ini` (gitignored). Cada `192.168.122.2` substituído por `192.168.123.10`.
- Validação final: 38 testes passando em 5 scripts (`connectivity`, `k8s`, `gitops`, `observability`, `observability-logs`).

---

## [0.5.4] — 2026-05-01

### Changed
- Camada de observabilidade migrada para GitOps no repositório `k8s-gitops`:
  - `apps/monitoring/monitoring-stack`: Prometheus, Grafana, Ingress, Node Exporter e RBAC
  - `apps/monitoring/loki`: wrapper chart com dependência para `grafana/loki`
  - `apps/monitoring/promtail`: wrapper chart com dependência para `grafana/promtail`
- Guias de observabilidade atualizados para tratar ArgoCD como mecanismo de deploy, mantendo os scripts locais apenas como validação.
- Diretório local de manifests Kubernetes removido após migração da observabilidade para GitOps.
- Dashboards Grafana movidos para `monitoring-dashboards/` como localização temporária até serem migrados para o `k8s-gitops`.
- ADR-010 adicionada para registrar a decisão de mover observabilidade para o paradigma GitOps.

---

## [0.5.3] — 2026-05-01

### Changed
- Bootstrap do ArgoCD migrado de `helm install` + `kubectl apply` manuais para playbook Ansible (`ansible/install-argocd.yml`). O release Helm continua sob controle do Ansible (não auto-managed pelo ArgoCD).
- ApplicationSet renomeado de `nexus` para `homelab` e generalizado para `apps/*/*` com `destination.namespace: '{{path[1]}}'`. Um único ApplicationSet cobre todos os namespaces — `nexus`, `argocd`, e futuros.
- `argocd-values.yaml` movido de `k8s/cd/` para `ansible/files/`. `ingress.yaml` e `applicationset.yaml` movidos para `k8s-gitops/apps/argocd/argocd-config/` — auto-managed via GitOps.
- `docs/guides/gitops.md` reescrito para refletir o fluxo Ansible.

### Added
- `ansible/install-argocd.yml`: playbook de bootstrap. Instala chart `argo/argo-cd:9.5.13`, migra ApplicationSet legado, aplica o novo, extrai senha admin.
- `ansible/bootstrap-cluster.yml`: wrapper opcional que executa `install-k3s.yml` + `install-argocd.yml` em sequência.
- `ansible/requirements.yml`: collection `kubernetes.core >=3.0.0`.
- `ansible/files/argocd-values.yaml`: cópia local do values do chart.
- `ansible/files/applicationset.yaml`: cópia de bootstrap do ApplicationSet (sincronizada manualmente com `k8s-gitops/apps/argocd/argocd-config/applicationset.yaml`).
- `ADR-009`: bootstrap do ArgoCD via Ansible, racional da duplicação consciente do `applicationset.yaml`, alternativas rejeitadas.
- `.gitignore`: adicionado pattern `ansible/files/*-credentials.yml` para credenciais geradas pelos playbooks.

### Removed
- Diretório `k8s/cd/` — todos os arquivos migrados para `ansible/files/` ou `k8s-gitops/`.

### Migration notes
- O ApplicationSet legado `nexus` (do v0.5.0) é **deletado** pelo playbook antes da aplicação do novo `homelab`. Causa ~5 segundos de downtime das Applications geradas — coerente com filosofia "ambiente reconstruível do zero".
- Antes de rodar o `install-argocd.yml`, garantir que o `k8s-gitops` está pushado com `apps/argocd/argocd-config/` populado. Caso contrário a Application `argocd-config` falha em sincronizar.
- Após rodar o playbook, verificar que `scripts/validate-gitops.sh` ainda funciona — pode precisar atualizar referências de `nexus` para `homelab` se o script consultava o ApplicationSet pelo nome.

---

## [0.5.2] — 2026-05-01

### Changed
- Refactor do Terraform para módulo reutilizável `modules/vm/`. A VM do k8s passa a ser instanciada via `module "k8s"` em `terraform/k8s.tf`. Recursos compartilhados (chave SSH ED25519, imagem base Ubuntu) ficam no root. Sem alteração funcional na infraestrutura — refactor estritamente de organização de código, validado via `terraform state mv` + `terraform plan` limpo.
- Outputs do Terraform reorganizados: `vm_name` → `k8s_vm_name`.
- `scripts/validate-connectivity.sh` atualizado para consumir `k8s_vm_name`.

### Added
- ADR-008: estrutura modular do Terraform — racional, alternativas rejeitadas.
- `terraform/modules/vm/versions.tf`: declaração de `required_providers` para o módulo.
- Runbook `libvirt.md` problema #6: procedimento de `terraform state mv` durante refactor.

### Migration notes
- 4 resources movidos no state sem destruir infra: `libvirt_volume.vm_disk`, `libvirt_volume.cloudinit_iso`, `libvirt_cloudinit_disk.init`, `libvirt_domain.vm` → `module.k8s.*`.
- `libvirt_volume.ubuntu_base` permanece no root como recurso compartilhado.

---

## [0.5.1] — 2026-04-23

### Fixed
- `README.md` atualizado: ArgoCD adicionado na stack, `v0.5.0` marcado como concluído, `k8s/cd/` adicionado na estrutura, `validate-gitops.sh` nos scripts, `docs/guides/gitops.md` e `ADR-007-gitops.md` na documentação, milestone `v0.5.0` adicionado no início rápido
- `.claude/CLAUDE.md` atualizado: ArgoCD adicionado na descrição, `v0.5.0` adicionado na tabela de guias, ADR-007 na tabela de ADRs, convenção de separação entre `k8s/` e `k8s-gitops` adicionada

---

## [0.5.0] — gitops — 2026-04-23

### Added
- ArgoCD instalado via Helm chart oficial (`argo/argo-cd`) no namespace `argocd`, com `dex` e `notifications` desabilitados via `k8s/cd/argocd-values.yaml`
- Ingress Traefik para `argocd.homelab.local` (`k8s/cd/ingress.yaml`)
- `ApplicationSet` configurado com gerador de diretórios monitorando `apps/nexus/*` no repositório `k8s-gitops` (`k8s/cd/applicationset.yaml`)
- Repositório `k8s-gitops` criado como fonte de verdade declarativa para manifests de aplicações gerenciadas pelo ArgoCD
- Aplicação `nexus-argocd` deployada via GitOps — Deployment, Service e Ingress gerenciados pelo ArgoCD a partir do `k8s-gitops`
- Script de validação do milestone (`scripts/validate-gitops.sh`) com 7 camadas de testes: pods ArgoCD, ApplicationSet, sync, health, pod da aplicação e ingresses
- Guia de instalação do GitOps (`docs/guides/gitops.md`)
- ADR-007: decisões de ferramenta GitOps, organização de repositórios, ApplicationSet e estrutura de manifests
- Dashboard `k8s/monitoring/dashboards/jvm-metrics.json` para monitoramento de aplicações java

---

## [0.4.0] — observability-logs — 2026-04-17

### Added
- Stack de logs no namespace `monitoring` via Helm:
  - Loki em modo `SingleBinary` com storage filesystem, retenção de 7 dias e multi-tenancy habilitado (`tenant: homelab`)
  - Promtail como DaemonSet coletando logs de todos os pods, com pipeline multiline para agrupar stacktraces Java
  - Gateway nginx provisionado pelo chart do Loki como ponto de entrada único para leitura e escrita
- Datasource Loki provisionado automaticamente no Grafana via ConfigMap (`04-grafana.yaml`)
- Dashboard `Logs — Kubernetes` (`k8s/monitoring/dashboards/logs-kubernetes.json`) com filtros obrigatórios por namespace e app, filtro opcional por pod e busca por texto
- Script de validação da stack de logs (`scripts/validate-observability-logs.sh`) com 5 camadas de testes: Loki, Promtail, PVC, API e streams indexados
- Guia de instalação da stack de logs (`docs/guides/observability-logs.md`)
- ADR-006: decisões de instalação e configuração da stack de logs
- Runbook de operação da stack de logs (`docs/runbook/loki.md`)

### Changed
- `04-grafana.yaml` atualizado com datasource do Loki provisionado via ConfigMap

---

## [0.3.0] — observability-metrics — 2026-04-14

### Added
- Stack de observabilidade no namespace `monitoring`:
  - Prometheus com RBAC, ConfigMap de scrape e Service
  - Grafana com PersistentVolumeClaim, datasource provisionado via ConfigMap e Service
  - Node Exporter como DaemonSet com acesso ao filesystem e `/run/udev` do host
  - Ingress via Traefik para `grafana.homelab.local` e `prometheus.homelab.local`
- Dashboard Kubernetes cluster monitoring (ID 315) adaptado para k3s/containerd (`k8s/monitoring/dashboards/kubernetes-cluster-monitoring-315.json`)
- Script de validação da stack (`scripts/validate-observability.sh`) com 5 camadas de testes: pods, services, ingress, prometheus e grafana
- Guia de instalação da stack de observabilidade (`docs/guides/observability-metrics.md`)
- ADR-005: decisões de deploy e configuração da stack de observabilidade

### Changed
- Dashboard 315 adaptado: label `pod_name` → `pod`, filtro Docker removido, `systemd_service_name` substituído por `namespace`, painéis `Graph (old)` migrados para `Time series`, filtro de interface loopback adicionado nas métricas de rede

---

## [0.2.0] — k8s-operational — 2026-04-07

### Added
- Instalação do k3s via Ansible (playbook próprio em `ansible/install-k3s.yml`)
- Inventário Ansible com template de exemplo (`ansible/inventory/hosts.ini.example`)
- kubeconfig copiado automaticamente para `~/.kube/k8s-homelab.yaml` pelo playbook
- Script de validação do cluster (`scripts/validate-k8s.sh`) com 4 camadas de testes:
  infraestrutura básica, DNS externo, DNS interno e comunicação entre pods via Service
- Guia de instalação do Kubernetes (`docs/guides/kubernetes.md`)
- ADR-004: escolha do Ansible como ferramenta de configuration management

---

## [0.1.1] — 2026-04-07

### Fixed
- CHANGELOG atualizado com entrada do milestone `v0.1.0`

---

## [0.1.0] — vm-provisioned — 2026-04-07

### Added
- Provisionamento de VM Ubuntu 24.04 via Terraform + KVM/libvirt
- Chave SSH ED25519 gerada pelo Terraform, isolada por projeto
- cloud-init com configurações base para Kubernetes (swap off, kernel modules)
- Script de validação de conectividade (`scripts/validate-connectivity.sh`)
- Estrutura de documentação: ADRs, runbooks, skills para Claude Code
- ADR-001: escolha do KVM como hypervisor
- ADR-002: escolha do k3s como distribuição Kubernetes
- ADR-003: escolha da Ubuntu 24.04 cloud image
