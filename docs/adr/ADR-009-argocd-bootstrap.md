# ADR-009 — Bootstrap do ArgoCD via Ansible

**Status:** Aceito
**Data:** 2026-05-01

---

## Contexto

No `v0.5.0`, o ArgoCD foi instalado manualmente via `helm install`, com
os manifests acessórios (Ingress, ApplicationSet) aplicados via `kubectl
apply -f` direto do diretório `k8s/cd/` no repositório principal. Esse
modelo funciona para o setup inicial, mas viola dois princípios que o
projeto adotou ao longo da evolução:

1. **Reprodutibilidade do bootstrap**: o ambiente deve subir do zero sem
   intervenção manual. Comandos `helm install` + `kubectl apply` exigem
   ordem e contexto que o operador precisa memorizar — exatamente o tipo
   de conhecimento tribal que documentação compensa mal.

2. **Separação `k8s/` vs. `k8s-gitops/`**: o `.claude/CLAUDE.md` formaliza
   que "Aplicações gerenciadas pelo ArgoCD vivem em `k8s-gitops` — nunca
   em `k8s/`". O Ingress e o ApplicationSet do ArgoCD são exatamente isso:
   recursos que o ArgoCD pode gerenciar. Mantê-los em `k8s/cd/` era uma
   exceção histórica que precisava ser corrigida.

---

## Decisão

Migrar o bootstrap do ArgoCD para um playbook Ansible
(`install-argocd.yml`) e mover Ingress + ApplicationSet para o repositório
`k8s-gitops`.

A divisão de responsabilidades passa a ser:

- **Ansible (`install-argocd.yml`)**: instala o release Helm
  `argo/argo-cd` em versão fixa, cria o namespace, aplica o ApplicationSet
  de bootstrap, extrai a senha admin gerada pelo chart e grava em arquivo
  gitignored.

- **k8s-gitops (`apps/argocd/argocd-config/`)**: versiona o Ingress e
  o ApplicationSet. O próprio ApplicationSet — sendo genérico e cobrindo
  `apps/*/*` — auto-descobre esse diretório, criando uma Application
  chamada `argocd-config` que aplica os dois manifests no namespace
  `argocd`. A partir desse ponto, o ArgoCD se auto-gerencia: alterar o
  `applicationset.yaml` ou o `ingress.yaml` no Git é reconciliado pelo
  próprio ArgoCD.

O **release Helm permanece sob controle do Ansible** (não é
auto-gerenciado pelo ArgoCD). Upgrades do chart são feitos via
`ansible-playbook install-argocd.yml` após atualizar a variável
`argocd_chart_version` no playbook.

---

## Self-bootstrap com duplicação consciente

Há uma ambiguidade no modelo que vale tornar explícita: o
`applicationset.yaml` existe em **dois lugares**:

1. **`k8s-homelab/ansible/files/applicationset.yaml`** — cópia usada pelo
   Ansible no bootstrap inicial. Aplicada via `kubectl apply` antes do
   ArgoCD ter ciência do `k8s-gitops`.

2. **`k8s-gitops/apps/argocd/argocd-config/applicationset.yaml`** — manifest
   que o ArgoCD reconcilia via GitOps após o bootstrap. Bit-idêntico ao
   anterior.

Os dois precisam ser bit-idênticos. Divergência leva o ArgoCD a marcar a
Application `argocd-config` como `OutOfSync` e tentar reconciliar para o
estado do Git — em outras palavras, o `k8s-gitops` vence em caso de
conflito.

Essa duplicação vem da escolha de não fazer o release Helm
auto-gerenciado pelo ArgoCD. Se o release fosse auto-gerenciado, o
ApplicationSet inicial poderia vir direto do `k8s-gitops` e a duplicação
não existiria — mas o custo seria o bootstrap chicken-and-egg do ArgoCD
gerenciar a si mesmo, com edge cases de upgrade muito arriscados para um
homelab de estudo.

---

## Consequências aceitas

- O diretório `k8s/cd/` deixa de existir no repositório principal. Os
  manifests vivem ou em `ansible/files/` (responsabilidade do Ansible) ou
  em `k8s-gitops` (responsabilidade do ArgoCD).

- ApplicationSet renomeado de `nexus` para `homelab` e generalizado para
  `apps/*/*` com `destination.namespace: '{{path[1]}}'`. Um único
  ApplicationSet cobre todos os namespaces — `nexus`, `argocd`, e futuros
  (`monitoring` em `v0.5.4`, microserviços em `v0.8.0`).

- A migração é destrutiva: o ApplicationSet legado precisa ser deletado
  antes do novo ser aplicado, causando ~5 segundos de downtime das
  Applications geradas. Coerente com a filosofia "ambiente reconstruível
  do zero".

- Senha inicial do admin passa a ser gravada automaticamente em
  `ansible/files/argocd-credentials.yml` (gitignored).

- Versão do chart fixada em `9.5.13`. Upgrades exigem alterar a variável
  no playbook e re-rodá-lo.

- Cópia local em `ansible/files/applicationset.yaml` exige sincronização
  manual com a versão no `k8s-gitops` quando o manifest mudar. Aceito
  como custo da reprodutibilidade do bootstrap.

---

## Alternativas rejeitadas

**Manter Helm + kubectl manuais (modelo do v0.5.0)**
Funciona para setup inicial, mas violava o princípio de reprodutibilidade
e a separação `k8s/` vs. `k8s-gitops/`. Era a forma menos invasiva mas
deixava conhecimento tribal sobre ordem de comandos e contexto.

**Helm release auto-gerenciado pelo ArgoCD**
Em vez do Ansible instalar o chart, o ApplicationSet teria uma Application
adicional apontando para `chart: argo-cd, repoURL: argo-helm`. GitOps
puro, elegante. Mas o bootstrap fica chicken-and-egg (o ArgoCD precisa
estar rodando para se instalar) e upgrades do release passam pelo próprio
ArgoCD — sujeito a edge cases em upgrades major. Para homelab de estudo,
o Ansible gerenciando o release é mais previsível e debuggável.

**Buscar `applicationset.yaml` do GitHub raw em vez de cópia local**
Eliminaria a duplicação entre `ansible/files/` e `k8s-gitops/`. Mas cria
dependência operacional implícita: o `k8s-gitops` precisa estar pushado
antes do playbook rodar. Em ambiente de estudo onde se reconstrói com
frequência, essa dependência é fonte recorrente de erro humano ("rodei
o playbook antes de pushar o gitops, deu 404"). A duplicação tem custo
baixo (~30 linhas, mudança rara) e elimina o failure mode.
