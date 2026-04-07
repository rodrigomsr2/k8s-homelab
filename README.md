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
| Grafana | Visualização de métricas |
| Grafana Loki | Agregação de logs |

## Milestones

| Tag | Estado | O que entrega |
|-----|--------|---------------|
| `v0.1.0` | ✅ | VM Ubuntu 24.04 via Terraform + KVM, SSH com ED25519, conectividade validada |
| `v0.2.0` | ✅ | k3s instalado via Ansible, kubectl funcional, DNS e rede validados |
| `v0.3.0` | 🔜 | Prometheus + Grafana com dashboards de cluster |
| `v0.4.0` | 🔜 | Grafana Loki coletando logs dos pods |
| `v0.5.0` | 🔜 | GitOps com ArgoCD ou Flux |
| `v0.6.0` | 🔜 | RBAC, Network Policies, secrets gerenciados |
| `v1.0.0` | 🔜 | Tudo integrado, documentado e com rollback validado |

## Estrutura do repositório

```
k8s-homelab/
├── README.md
├── CHANGELOG.md
├── CLAUDE.local.md                  # IPs e paths locais — não versionado
├── .claude/
│   ├── CLAUDE.md                    # Índice de navegação para IA
│   └── skills/
│       ├── semver.md
│       └── project-organization.md
├── terraform/
│   ├── CLAUDE.md                    # Índice do módulo Terraform
│   ├── main.tf                      # Bloco terraform + provider
│   ├── ssh.tf                       # Chaves ED25519
│   ├── volumes.tf                   # Imagem base, disco VM, ISO cloud-init
│   ├── cloudinit.tf                 # Configuração cloud-init
│   ├── vm.tf                        # Domínio KVM
│   ├── variables.tf
│   ├── outputs.tf
│   └── cloud-init/
│       ├── user-data.tpl
│       └── network-config.yaml
├── ansible/
│   ├── install-k3s.yml              # Playbook de instalação do k3s
│   └── inventory/
│       └── hosts.ini.example        # Template de inventário — copiar e preencher
├── scripts/
│   ├── validate-connectivity.sh     # Validação do milestone v0.1.0
│   └── validate-k8s.sh             # Validação do milestone v0.2.0
└── docs/
    ├── adr/
    │   ├── ADR-001-hypervisor.md
    │   ├── ADR-002-kubernetes-distro.md
    │   ├── ADR-003-vm-image.md
    │   └── ADR-004-configuration-management.md
    ├── guides/
    │   ├── vm-provisioning.md
    │   └── kubernetes.md
    └── runbook/
        ├── libvirt.md
        ├── kubernetes.md
        └── observability.md
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
```

## Documentação

| Documento | Descrição |
|-----------|-----------|
| `docs/guides/vm-provisioning.md` | Guia de instalação do zero — milestone `v0.1.0` |
| `docs/guides/kubernetes.md` | Guia de instalação do k3s via Ansible — milestone `v0.2.0` |
| `docs/adr/` | Decisões arquiteturais e alternativas rejeitadas |
| `docs/runbook/libvirt.md` | Operação do KVM e problemas encontrados |
| `docs/runbook/kubernetes.md` | Operação do k3s e problemas encontrados |
| `.claude/CLAUDE.md` | Índice de navegação para agentes de IA |
