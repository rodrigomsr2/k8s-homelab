# Changelog

Todas as mudanças relevantes deste projeto são documentadas aqui.

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/).
Versionamento segue [Semantic Versioning](https://semver.org/lang/pt-BR/) — ver `.claude/skills/semver.md`.

---

## [Unreleased]

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
