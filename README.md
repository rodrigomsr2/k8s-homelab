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
| ArgoCD | GitOps — deploy declarativo a partir do repositório |
| MongoDB | Banco de dados de documentos — VM dedicada |
| Kafka | Streaming de eventos — VM dedicada |
| OpenTelemetry | Coleta e exportação de traces distribuídos |

## Milestones

| Tag | Estado | O que entrega |
|-----|--------|---------------|
| `v0.1.0` | ✅ | VM Ubuntu 24.04 via Terraform + KVM, SSH com ED25519, conectividade validada |
| `v0.2.0` | ✅ | k3s instalado via Ansible, kubectl funcional, DNS e rede validados |
| `v0.3.0` | ✅ | Prometheus + Grafana + Node Exporter operacionais, dashboards de cluster funcionais |
| `v0.4.0` | ✅ | Grafana Loki + Promtail via Helm, logs dos pods coletados e consultáveis via Grafana |
| `v0.5.0` | ✅ | ArgoCD operacional, nexus-argocd gerenciado via GitOps a partir do k8s-gitops |
| `v0.5.2` | ✅ | Refactor do Terraform para módulo reutilizável `modules/vm/` — sem alteração funcional |
| `v0.6.0` | 🔜 | VM dedicada provisionada via Terraform, MongoDB instalado e operacional |
| `v0.7.0` | 🔜 | VM dedicada provisionada via Terraform, Kafka instalado e operacional |
| `v0.8.0` | 🔜 | Microserviços no k8s consumindo Kafka e MongoDB |
| `v0.9.0` | 🔜 | OpenTelemetry coletando traces dos microserviços, visível no Grafana |
| `v0.10.0` | 🔜 | ArgoCD gerenciando toda a stack declarativamente |
| `v0.11.0` | 🔜 | RBAC, Network Policies e Pod Security |
| `v0.12.0` | 🔜 | Istio ou Linkerd gerenciando tráfego e mTLS entre serviços |
| `v1.0.0` | 🔜 | Tudo integrado, documentado, estável e com rollback validado |

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
│   ├── main.tf                            # Provider libvirt
│   ├── ssh.tf                             # Chave ED25519 compartilhada
│   ├── image.tf                           # Imagem base Ubuntu (compartilhada)
│   ├── k8s.tf                             # Chamada do módulo para a VM do k8s
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       └── vm/
│           ├── variables.tf
│           ├── volumes.tf                 # Disco da VM + ISO cloud-init
│           ├── cloudinit.tf
│           ├── vm.tf                      # Domínio KVM
│           ├── outputs.tf
│           └── cloud-init/
│               ├── user-data.tpl
│               └── network-config.yaml
├── ansible/
│   ├── install-k3s.yml                    # Playbook de instalação do k3s
│   ├── install-mongodb.yml                # Playbook de instalação do MongoDB — milestone v0.6.0
│   ├── install-kafka.yml                  # Playbook de instalação do Kafka — milestone v0.7.0
│   └── inventory/
│       └── hosts.ini.example              # Template de inventário — copiar e preencher
├── k8s/
│   ├── monitoring/
│   │   ├── 01-namespace-rbac.yaml         # Namespace + RBAC do Prometheus
│   │   ├── 02-prometheus-configmap.yaml   # Configuração de scrape do Prometheus
│   │   ├── 03-prometheus.yaml             # Deployment + Service do Prometheus
│   │   ├── 04-grafana.yaml                # PVC + Deployment + Service + datasources do Grafana
│   │   ├── 05-ingress.yaml                # Ingress para Grafana e Prometheus
│   │   ├── 06-node-exporter.yaml          # DaemonSet + Service do Node Exporter
│   │   ├── loki-values.yaml               # Helm values do Loki
│   │   ├── promtail-values.yaml           # Helm values do Promtail
│   │   └── dashboards/
│   │       ├── kubernetes-cluster-monitoring-315.json
│   │       └── logs-kubernetes.json
│   └── cd/
│       ├── argocd-values.yaml             # Helm values do ArgoCD
│       ├── ingress.yaml                   # Ingress para argocd.homelab.local
│       └── applicationset.yaml            # ApplicationSet — monitora apps/* no k8s-gitops
├── scripts/
│   ├── validate-connectivity.sh           # Validação do milestone v0.1.0
│   ├── validate-k8s.sh                    # Validação do milestone v0.2.0
│   ├── validate-observability.sh          # Validação do milestone v0.3.0
│   ├── validate-observability-logs.sh     # Validação do milestone v0.4.0
│   ├── validate-gitops.sh                 # Validação do milestone v0.5.0
│   ├── validate-mongodb.sh                # Validação do milestone v0.6.0
│   └── validate-kafka.sh                  # Validação do milestone v0.7.0
└── docs/
    ├── adr/
    │   ├── ADR-001-hypervisor.md
    │   ├── ADR-002-kubernetes-distro.md
    │   ├── ADR-003-vm-image.md
    │   ├── ADR-004-configuration-management.md
    │   ├── ADR-005-observability-stack.md
    │   ├── ADR-006-loki-stack.md
    │   ├── ADR-007-gitops.md
    │   └── ADR-008-terraform-module-structure.md
    ├── guides/
    │   ├── vm-provisioning.md
    │   ├── kubernetes.md
    │   ├── observability-metrics.md
    │   ├── observability-logs.md
    │   └── gitops.md
    └── runbook/
        ├── libvirt.md
        ├── kubernetes.md
        ├── observability.md
        └── loki.md
```

## Início rápido

Consulte os guias de instalação em `docs/guides/` para instruções completas de cada milestone.

```bash
# Milestone v0.1.0 — provisionar a VM do k8s
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

# Milestone v0.5.0 — instalar o ArgoCD e configurar GitOps
helm install argocd argo/argo-cd \
  --kubeconfig=$HOME/.kube/k8s-homelab.yaml \
  --namespace argocd \
  --values k8s/cd/argocd-values.yaml

kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml apply -f k8s/cd/ingress.yaml
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml apply -f k8s/cd/applicationset.yaml

# Milestone v0.6.0 — provisionar VM do MongoDB e instalar
cd terraform/
terraform apply
ansible-playbook -i inventory/hosts.ini install-mongodb.yml

# Milestone v0.7.0 — provisionar VM do Kafka e instalar
cd terraform/
terraform apply
ansible-playbook -i inventory/hosts.ini install-kafka.yml
```

## Documentação

| Documento | Descrição |
|-----------|-----------|
| `docs/guides/vm-provisioning.md` | Guia de instalação do zero — milestone `v0.1.0` |
| `docs/guides/kubernetes.md` | Guia de instalação do k3s via Ansible — milestone `v0.2.0` |
| `docs/guides/observability-metrics.md` | Guia de instalação da stack de observabilidade — milestone `v0.3.0` |
| `docs/guides/observability-logs.md` | Guia de instalação da stack de logs — milestone `v0.4.0` |
| `docs/guides/gitops.md` | Guia de instalação do ArgoCD e GitOps — milestone `v0.5.0` |
| `docs/adr/` | Decisões arquiteturais e alternativas rejeitadas |
| `docs/runbook/libvirt.md` | Operação do KVM e problemas encontrados |
| `docs/runbook/kubernetes.md` | Operação do k3s e problemas encontrados |
| `docs/runbook/observability.md` | Operação da stack de observabilidade e problemas encontrados |
| `docs/runbook/loki.md` | Operação da stack de logs e problemas encontrados |
| `.claude/CLAUDE.md` | Índice de navegação para agentes de IA |
