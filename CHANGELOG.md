# Changelog

Todas as mudanças relevantes deste projeto são documentadas aqui.

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/).
Versionamento segue [Semantic Versioning](https://semver.org/lang/pt-BR/) — ver `.claude/skills/semver.md`.

---

## [Unreleased]

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
- `ApplicationSet` configurado com gerador de diretórios monitorando `apps/*/*` no repositório `k8s-gitops` (`k8s/cd/applicationset.yaml`)
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
