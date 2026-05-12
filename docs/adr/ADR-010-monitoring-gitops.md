# ADR-010 — Observabilidade gerenciada via GitOps

**Status:** Aceito
**Data:** 2026-05-12

---

## Contexto

A stack de observabilidade nasceu nos milestones `v0.3.0` e `v0.4.0` como
manifests e values locais neste repositório. Métricas eram aplicadas com
`kubectl apply` e logs eram instalados com `helm install`.

Depois da introdução do ArgoCD e do ApplicationSet `homelab`, manter a
observabilidade como camada manual criava duas fontes de verdade:

- este repositório, com manifests e instruções de aplicação manual
- `k8s-gitops`, com o estado desejado reconciliado pelo ArgoCD

Isso contrariava o modelo atual do projeto: o `k8s-homelab` deve cuidar do
bootstrap, automação, validações e documentação; o estado declarativo do
cluster deve viver no `k8s-gitops`.

---

## Decisão

Mover a camada de observabilidade para o repositório `k8s-gitops`, no
namespace `monitoring`, usando o padrão já descoberto pelo ApplicationSet
`homelab`:

```text
k8s-gitops/apps/monitoring/monitoring-stack/
k8s-gitops/apps/monitoring/loki/
k8s-gitops/apps/monitoring/promtail/
```

A divisão fica:

- **`monitoring-stack`**: manifests Kubernetes puros para namespace, RBAC,
  Prometheus, Grafana, Ingress e Node Exporter.
- **`loki`**: wrapper chart Helm com dependência fixa para `grafana/loki`.
- **`promtail`**: wrapper chart Helm com dependência fixa para
  `grafana/promtail`.

O diretório local de manifests Kubernetes foi removido deste repositório.
Os dashboards do Grafana permanecem temporariamente em
`monitoring-dashboards/`, porque ainda são importados manualmente. Eles
devem migrar futuramente para o `k8s-gitops` junto da configuração do
Grafana.

---

## Consequências aceitas

- O deploy da observabilidade passa a depender de commit e push no
  `k8s-gitops`; o ArgoCD reconcilia o cluster a partir da branch monitorada.
- Os scripts deste repositório permanecem como validação operacional, não
  como mecanismo de deploy.
- Loki e Promtail passam a exercitar o fluxo GitOps com Helm de forma
  explícita, usando wrapper charts, `Chart.lock` e `values.yaml`.
- O diretório `charts/` gerado por `helm dependency build` é artefato local e
  não deve ser versionado no `k8s-gitops`.
- Dashboards ainda são uma exceção temporária: ficam versionados localmente
  em `monitoring-dashboards/`, mas não são aplicados automaticamente.

---

## Alternativas rejeitadas

**Manter observabilidade manual neste repositório**

Rejeitada porque mantém duas formas de operar o cluster: GitOps para
aplicações e comandos manuais para observabilidade. Isso aumenta o risco de
drift e torna rebuilds menos reprodutíveis.

**Commitar YAML renderizado dos charts Loki e Promtail**

Rejeitada porque esconderia o uso real de Helm. O objetivo do homelab também
é praticar operação de charts em GitOps. Wrapper charts preservam essa
habilidade e deixam explícitas as versões das dependências.

**Mover dashboards para GitOps neste momento**

Rejeitada temporariamente. O provisioning automático de dashboards exige uma
decisão separada sobre ciclo de vida, duplicação com dashboards importados
manualmente e ownership da configuração do Grafana. Por enquanto, os JSONs
ficam em `monitoring-dashboards/`.
