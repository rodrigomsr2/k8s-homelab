# Changelog

Todas as mudanças relevantes deste projeto são documentadas aqui.

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/).
Versionamento segue [Semantic Versioning](https://semver.org/lang/pt-BR/) — ver `.claude/skills/semver.md`.

---

## [Unreleased]

### Added
- Provisionamento de VM Ubuntu 24.04 via Terraform + KVM/libvirt
- Chave SSH ED25519 gerada pelo Terraform, isolada por projeto
- cloud-init com configurações base para Kubernetes (swap off, kernel modules)
- Script de validação de conectividade (`scripts/validate-connectivity.sh`)
- Estrutura de documentação: ADRs, runbooks, skills para Claude Code
- ADR-001: escolha do KVM como hypervisor
- ADR-002: escolha do k3s como distribuição Kubernetes
- ADR-003: escolha da Ubuntu 24.04 cloud image

---

<!-- Exemplo de entrada após taguear v0.1.0:

## [0.1.0] — vm-provisioned — YYYY-MM-DD

### Added
- Provisionamento de VM Ubuntu 24.04 via Terraform + KVM/libvirt
- ...

-->
