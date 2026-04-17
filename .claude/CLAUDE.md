# k8s-homelab — Índice para IA

Ambiente local isolado para estudo de DevOps: KVM + Terraform + Kubernetes + Prometheus + Grafana + Loki.
Construído em fases incrementais, cada fase validada antes de avançar.

> Para visão geral, stack e início rápido: leia o `README.md`.

---

## Onde encontrar cada tipo de conhecimento

| Tipo | Onde |
|------|------|
| Stack, estrutura e início rápido | `README.md` |
| Decisões arquiteturais (por que X e não Y) | `docs/adr/` |
| Guias de instalação sequenciais (do zero) | `docs/guides/` |
| Operação e troubleshooting por tema | `docs/runbook/` |
| Informações locais (IPs, paths, credenciais) | `CLAUDE.local.md` ← não versionado |

---

## Guias disponíveis

| Milestone | Guia de instalação | Runbook operacional |
|-----------|-------------------|---------------------|
| `v0.1.0` — VM provisionada | `docs/guides/vm-provisioning.md` | `docs/runbook/libvirt.md` |
| `v0.2.0` — Kubernetes | `docs/guides/kubernetes.md` | `docs/runbook/kubernetes.md` |
| `v0.3.0` — Métricas | `docs/guides/observability-metrics.md` | `docs/runbook/observability.md` |
| `v0.4.0` — Logs | `docs/guides/observability-logs.md` | `docs/runbook/loki.md` |

---

## ADRs vigentes

| ADR | Decisão |
|-----|---------|
| `docs/adr/ADR-001-hypervisor.md` | KVM/libvirt como hypervisor |
| `docs/adr/ADR-002-kubernetes-distro.md` | k3s como distribuição Kubernetes |
| `docs/adr/ADR-003-vm-image.md` | Ubuntu 24.04 cloud image |
| `docs/adr/ADR-004-configuration-management.md` | Ansible como ferramenta de configuration management |
| `docs/adr/ADR-005-observability-stack.md` | Stack de observabilidade: deploy e configuração |
| `docs/adr/ADR-006-loki-stack.md` | Stack de logs: Helm, Promtail, SingleBinary, filesystem |

---

## Runbooks disponíveis

| Runbook | Cobre |
|---------|-------|
| `docs/runbook/libvirt.md` | KVM, libvirt, virsh, rede NAT |
| `docs/runbook/kubernetes.md` | k3s, kubectl, pods, namespaces |
| `docs/runbook/observability.md` | Prometheus, Grafana, Node Exporter |
| `docs/runbook/loki.md` | Loki, Promtail, Helm, pipeline de logs |

---

## Convenções do projeto

- Infraestrutura como código: toda mudança passa pelo Terraform
- Nenhuma configuração manual na VM sem estar refletida no cloud-init ou em um runbook
- Cada milestone tem um script de validação em `scripts/` antes de avançar
- Chaves SSH e IPs locais vivem em `CLAUDE.local.md`, nunca no repositório
- Manifests Kubernetes organizados em `k8s/<namespace>/` — um subdiretório por namespace
- Charts Helm gerenciados via `values.yaml` versionados no repositório — sem `helm install` sem values explícitos
