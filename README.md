# k8s-homelab

Ambiente local isolado para estudo e demonstração de habilidades DevOps.

## Stack

| Tecnologia | Função |
|---|---|
| KVM + libvirt | Hypervisor (virtualização enterprise) |
| Terraform | Provisionamento de infraestrutura como código |
| cloud-init | Configuração inicial da VM |
| Ansible | Configuration management e instalação de software |
| Kubernetes (k3s) | Orquestração de containers |
| Prometheus | Coleta de métricas |
| Grafana | Visualização de métricas e dashboards |
| Node Exporter | Métricas de hardware do host |
| Grafana Loki | Agregação de logs |
| Promtail | Coleta e envio de logs dos pods para o Loki |
| Helm | Gerenciamento de charts Kubernetes |

## Milestones

| Tag | Estado | O que entrega |
|-----|--------|---------------|
| `v0.1.0` | ✅ | VM Ubuntu 24.04 via Terraform + KVM, SSH com ED25519, conectividade validada |
| `v0.2.0` | ✅ | k3s instalado via Ansible, kubectl funcional, DNS e rede validados |
| `v0.3.0` | ✅ | Prometheus + Grafana + Node Exporter operacionais, dashboards de cluster funcionais |
| `v0.4.0` | ✅ | Grafana Loki + Promtail via Helm, logs dos pods coletados e consultáveis via Grafana |
| `v0.5.0` | 🔜 | GitOps com ArgoCD ou Flux |
| `v0.6.0` | 🔜 | RBAC, Network Policies, secrets gerenciados |
| `v1.0.0` | 🔜 | Tudo integrado, documentado e com rollback validado |

## Estrutura do repositório

```
k8s-homelab/
├── README.md
├── CHANGELOG.md
├── CLAUDE.local.md                        # IPs e paths locais — não versionado
├── .claude/
│   ├── CLAUDE.md                          # Índice de navegação para IA
│   └── skills/
│       ├── semver.md
│       └── project-organization.md
├── terraform/
│   ├── CLAUDE.md                          # Índice do módulo Terraform
│   ├── main.tf                            # Bloco terraform + provider
│   ├── ssh.tf                             # Chaves ED25519
│   ├── volumes.tf                         # Imagem base, disco VM, ISO cloud-init
│   ├── cloudinit.tf                       # Configuração cloud-init
│   ├── vm.tf                              # Domínio KVM
│   ├── variables.tf
│   ├── outputs.tf
│   └── cloud-init/
│       ├── user-data.tpl
│       └── network-config.yaml
├── ansible/
│   ├── install-k3s.yml                    # Playbook de instalação do k3s
│   └── inventory/
│       └── hosts.ini.example              # Template de inventário — copiar e preencher
├── k8s/
│   └── monitoring/
│       ├── 01-namespace-rbac.yaml         # Namespace + RBAC do Prometheus
│       ├── 02-prometheus-configmap.yaml   # Configuração de scrape do Prometheus
│       ├── 03-prometheus.yaml             # Deployment + Service do Prometheus
│       ├── 04-grafana.yaml                # PVC + Deployment + Service + datasources do Grafana
│       ├── 05-ingress.yaml                # Ingress para Grafana e Prometheus
│       ├── 06-node-exporter.yaml          # DaemonSet + Service do Node Exporter
│       ├── loki-values.yaml               # Helm values do Loki
│       ├── promtail-values.yaml           # Helm values do Promtail
│       └── dashboards/
│           ├── kubernetes-cluster-monitoring-315.json
│           └── logs-kubernetes.json
├── scripts/
│   ├── validate-connectivity.sh           # Validação do milestone v0.1.0
│   ├── validate-k8s.sh                    # Validação do milestone v0.2.0
│   ├── validate-observability.sh          # Validação do milestone v0.3.0
│   └── validate-observability-logs.sh     # Validação do milestone v0.4.0
└── docs/
    ├── adr/
    │   ├── ADR-001-hypervisor.md
    │   ├── ADR-002-kubernetes-distro.md
    │   ├── ADR-003-vm-image.md
    │   ├── ADR-004-configuration-management.md
    │   ├── ADR-005-observability-stack.md
    │   └── ADR-006-loki-stack.md
    ├── guides/
    │   ├── vm-provisioning.md
    │   ├── kubernetes.md
    │   ├── observability-metrics.md
    │   └── observability-logs.md
    └── runbook/
        ├── libvirt.md
        ├── kubernetes.md
        ├── observability.md
        └── loki.md
```

## Início rápido

Consulte os guias de instalação em `docs/guides/` para instruções completas de cada milestone.

```bash
# Milestone v0.1.0 — provisionar a VM
cd terraform/
terraform init
terraform apply

# Milestone v0.2.0 — instalar o k3s
cp ansible/inventory/hosts.ini.example ansible/inventory/hosts.ini
# editar hosts.ini com IP da VM e path da chave SSH
cd ansible/
ansible-playbook -i inventory/hosts.ini install-k3s.yml

# Milestone v0.3.0 — instalar a stack de observabilidade
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml apply -f k8s/monitoring/

# Milestone v0.4.0 — instalar a stack de logs
helm install loki grafana/loki \
  --kubeconfig=$HOME/.kube/k8s-homelab.yaml \
  --namespace monitoring \
  --values k8s/monitoring/loki-values.yaml

helm install promtail grafana/promtail \
  --kubeconfig=$HOME/.kube/k8s-homelab.yaml \
  --namespace monitoring \
  --values k8s/monitoring/promtail-values.yaml
```

## Documentação

| Documento | Descrição |
|-----------|-----------|
| `docs/guides/vm-provisioning.md` | Guia de instalação do zero — milestone `v0.1.0` |
| `docs/guides/kubernetes.md` | Guia de instalação do k3s via Ansible — milestone `v0.2.0` |
| `docs/guides/observability-metrics.md` | Guia de instalação da stack de observabilidade — milestone `v0.3.0` |
| `docs/guides/observability-logs.md` | Guia de instalação da stack de logs — milestone `v0.4.0` |
| `docs/adr/` | Decisões arquiteturais e alternativas rejeitadas |
| `docs/runbook/libvirt.md` | Operação do KVM e problemas encontrados |
| `docs/runbook/kubernetes.md` | Operação do k3s e problemas encontrados |
| `docs/runbook/observability.md` | Operação da stack de observabilidade e problemas encontrados |
| `docs/runbook/loki.md` | Operação da stack de logs e problemas encontrados |
| `.claude/CLAUDE.md` | Índice de navegação para agentes de IA |
