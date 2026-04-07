---
name: semver
description: |
  Define como versionar e taguear este projeto usando Semantic Versioning.
  Use esta skill sempre que o usuário perguntar sobre versionamento, tags git,
  quando criar uma nova versão, o que cada número significa, ou como fazer
  rollback para um estado anterior do ambiente.
---

# Skill — Versionamento com Semver

## Formato

```
vMAJOR.MINOR.PATCH
```

| Segmento | Quando incrementar |
|----------|--------------------|
| `PATCH` | Correção ou melhoria dentro de um milestone existente — o ambiente continua funcionalmente igual |
| `MINOR` | Novo milestone funcional — uma nova camada foi adicionada ao ambiente |
| `MAJOR` | Mudança arquitetural que torna estados anteriores incompatíveis (ex: trocar k3s por kubeadm, migrar para multi-node) |

`v0.x.x` indica que o projeto ainda está em desenvolvimento ativo — sem garantia de estabilidade entre versões. `v1.0.0` é a declaração de que a arquitetura base está estável e documentada.

---

## Milestones deste projeto

| Tag | Nome semântico | O que deve estar 100% funcional |
|-----|---------------|----------------------------------|
| `v0.1.0` | `vm-provisioned` | VM Ubuntu 24.04 via Terraform + KVM, SSH com ED25519, conectividade validada |
| `v0.2.0` | `k8s-operational` | k3s instalado, kubectl funcionando, pods básicos sobem, CNI operacional |
| `v0.3.0` | `observability-metrics` | Prometheus coletando métricas do cluster, Grafana com dashboards funcionais |
| `v0.4.0` | `observability-logs` | Grafana Loki coletando e consultando logs dos pods |
| `v0.5.0` | `gitops` | ArgoCD ou Flux gerenciando deploys declarativamente a partir do repositório |
| `v0.6.0` | `security-hardening` | RBAC, Network Policies e secrets gerenciados |
| `v1.0.0` | `production-ready` | Tudo integrado, documentado, estável e com rollback validado |

---

## Critério para criar uma tag

Uma tag só é criada quando:

- [ ] O ambiente sobe do zero com `terraform apply` + script de instalação do milestone
- [ ] O script de validação do milestone passa sem erros
- [ ] O `CHANGELOG.md` tem a entrada correspondente
- [ ] Todos os arquivos do milestone estão commitados no `main`

Nunca taguear um estado intermediário ou com validação pendente.

---

## Comandos git

```bash
# Criar tag anotada (sempre anotada — nunca lightweight)
git tag -a v0.1.0 -m "vm-provisioned: VM Ubuntu 24.04 via Terraform+KVM, SSH com ED25519, conectividade validada"

# Publicar tag no remoto
git push origin v0.1.0

# Listar todas as tags com mensagem
git tag -n

# Inspecionar uma tag
git show v0.1.0

# Voltar para o estado de uma tag (rollback)
git checkout v0.1.0

# Voltar para o main depois do rollback
git checkout main
```

---

## Regras

1. **Sempre tags anotadas** (`-a`) — tags lightweight não carregam mensagem nem metadados de autoria
2. **Mensagem no formato `<nome-semântico>: <descrição do estado`** — legível em qualquer interface git
3. **Tag no `main`** — nunca taguear branches de desenvolvimento
4. **Uma tag por milestone concluído** — não criar tags antecipadas
5. **PATCH só em cima do MINOR mais recente** — `v0.1.1` é uma correção do `v0.1.0`, não um novo milestone
