# GitOps — ArgoCD + k8s-gitops

Guia para instalar o ArgoCD no cluster e configurar o fluxo GitOps completo.
Ao final, o ambiente estará no estado `v0.5.0` — deploys da aplicação
`nexus-argocd` gerenciados automaticamente a partir do repositório
`k8s-gitops`.

Pré-requisito: milestone `v0.4.0` concluído — cluster operacional com
Prometheus, Grafana e Loki funcionais.

---

## Instalação do ArgoCD

### 1. Adicionar o repositório Helm

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

Verificar que o repositório foi adicionado:

```bash
helm repo list
# argo    https://argoproj.github.io/argo-helm
```

### 2. Inspecionar o chart antes de instalar

```bash
# Ver versões disponíveis
helm search repo argo/argo-cd --versions | head -10

# Exportar valores padrão para referência
helm show values argo/argo-cd > /tmp/argocd-default-values.yaml
```

### 3. Instalar via Helm

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml create namespace argocd

helm install argocd argo/argo-cd \
  --kubeconfig=$HOME/.kube/k8s-homelab.yaml \
  --namespace argocd \
  --values k8s/cd/argocd-values.yaml
```

Acompanhar os pods subindo:

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml get pods -n argocd -w
```

Aguardar os 5 pods em `Running`:

```
argocd-application-controller-0
argocd-applicationset-controller-xxx
argocd-redis-xxx
argocd-repo-server-xxx
argocd-server-xxx
```

---

## Expor a UI via Ingress

O ArgoCD não é exposto fora do cluster por padrão. Seguindo o padrão do
projeto, vamos criar um Ingress Traefik para `argocd.homelab.local`.

O ArgoCD serve HTTPS por padrão — é necessário desabilitar o TLS interno
para que o Traefik possa fazer o proxy sem conflito de certificados.

### 1. Aplicar o Ingress

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml apply -f k8s/cd/ingress.yaml
```

### 3. Adicionar ao /etc/hosts

```bash
echo "<IP_DA_VM> argocd.homelab.local" | sudo tee -a /etc/hosts
```

Verificar o acesso no browser: `http://argocd.homelab.local`

---

## Primeiro acesso

O usuário padrão é `admin`. A senha inicial é gerada automaticamente e
armazenada num Secret:

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

> Após o primeiro login, altere a senha em **User Info → Update Password**.
> O Secret `argocd-initial-admin-secret` pode ser deletado depois disso.

---

## Instalar a CLI do ArgoCD

A CLI é útil para inspecionar o estado das aplicações e forçar syncs sem
precisar acessar a UI.

```bash
curl -sSL -o /usr/local/bin/argocd \
  https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

chmod +x /usr/local/bin/argocd

argocd version --client
```

Autenticar:

```bash
argocd login argocd.homelab.local --username admin --password <senha> --insecure
```

---

## Configurar o ApplicationSet

O `ApplicationSet` monitora o path `apps/nexus/*` no `k8s-gitops` e gera
automaticamente uma `Application` para cada subdiretório encontrado. Adicionar
um novo microserviço significa apenas criar o diretório correspondente no
`k8s-gitops` — sem nenhuma alteração aqui.

Aplicar:

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml apply -f k8s/cd/applicationset.yaml
```

O ArgoCD vai detectar o `k8s-gitops`, encontrar o diretório
`apps/nexus/nexus-argocd/` e criar automaticamente uma `Application`
chamada `nexus-argocd` que aplica os manifests no cluster.

Acompanhar o sync na UI em `http://argocd.homelab.local` ou via CLI:

```bash
argocd app list
argocd app get nexus-argocd
argocd app sync nexus-argocd  # forçar sync manual se necessário
```

---

## Validação

```bash
bash scripts/validate-gitops.sh
```

O script executa as seguintes verificações:

| # | Teste | O que valida |
|---|-------|-------------|
| 1 | Pods argocd Running | ArgoCD operacional |
| 2 | Application nexus-argocd Synced | Repositório sincronizado |
| 3 | Application nexus-argocd Healthy | Recursos saudáveis no cluster |
| 4 | Pod nexus-argocd Running | Aplicação deployada |
| 5 | Ingress nexus acessível | Endpoint responde |

Todos os 5 testes passando = milestone `v0.5.0` concluído.

---

## Taguear o milestone

```bash
# No repositório k8s-homelab
git add -A
git commit -m "feat: ArgoCD instalado, Application nexus-argocd configurada"

git tag -a v0.5.0 -m "gitops: ArgoCD operacional, nexus-argocd gerenciado via k8s-gitops"
git push origin main --tags

# No repositório k8s-gitops
git add -A
git commit -m "feat: manifests iniciais da aplicação nexus-argocd"

git tag -a v0.1.0 -m "nexus-argocd: Deployment + Service + Ingress operacionais"
git push origin main --tags
```

---

## Desinstalar

```bash
# Remover o ApplicationSet (ArgoCD vai deletar todos os recursos gerenciados)
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml delete -f k8s/cd/applicationset.yaml

# Remover o ArgoCD
helm uninstall argocd --kubeconfig=$HOME/.kube/k8s-homelab.yaml -n argocd

# Remover o namespace
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml delete namespace argocd
```

> Deletar a `Application` antes de desinstalar o ArgoCD garante que os
> recursos gerenciados (`nexus-argocd`) sejam removidos de forma limpa.
> Se o ArgoCD for deletado primeiro, os recursos permanecem no cluster órfãos.
