# ADR-003 — Ubuntu 24.04 LTS cloud image como imagem base da VM

**Status:** Aceito  
**Data:** 2025-01

---

## Contexto

A VM precisa de uma imagem Linux base para ser provisionada via Terraform.
A imagem precisa ser compatível com cloud-init (para configuração automatizada),
ter suporte LTS e ser mínima o suficiente para não desperdiçar recursos.

---

## Decisão

Usar a **Ubuntu 24.04 LTS (Noble Numbat) cloud image** oficial da Canonical.

A cloud image é uma variante mínima do Ubuntu, sem interface gráfica, pré-configurada
para uso com cloud-init. É a mesma imagem usada em AWS EC2, GCP e Azure quando
se sobe uma instância Ubuntu — o que aproxima o ambiente local do comportamento
cloud real. Distribuída em formato `qcow2`, compatível nativamente com KVM/libvirt.

---

## Consequências aceitas

- Primeiro `terraform apply` faz download de ~600 MB da imagem base
- A imagem base fica cacheada no pool libvirt após o primeiro download;
  aplys subsequentes são rápidos
- Atualizações de segurança da imagem requerem novo download ou `apt upgrade` na VM

---

## Alternativas rejeitadas

**ISO de instalação padrão do Ubuntu**
Requer processo de instalação interativo — incompatível com provisionamento
automatizado via Terraform. cloud-init não funciona com ISOs de instalação.

**Debian 12 cloud image**
Tecnicamente equivalente e igualmente válida. Ubuntu foi preferido por ser
mais comum em tutoriais Kubernetes e ter melhor suporte de pacotes para
ferramentas de observabilidade.

**Rocky Linux 9**
Excelente para ambientes enterprise que precisam de compatibilidade RHEL.
Ubuntu foi preferido por ser mais familiar para o contexto do projeto e
ter maior adoção em ambientes cloud nativos com Kubernetes.
