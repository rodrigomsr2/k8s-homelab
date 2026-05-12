# Observabilidade — Logs com Loki + Promtail

Guia para instalar a stack de logs no cluster existente via ArgoCD.
Ao final, o ambiente estará no estado `v0.4.0` — logs dos pods coletados
pelo Promtail, armazenados no Loki e consultáveis via Grafana.

Pré-requisito: milestone `v0.3.0` concluído — namespace `monitoring`,
Prometheus e Grafana operacionais.

---

## Pré-requisitos

### ArgoCD operacional

O ApplicationSet `homelab` precisa estar ativo e monitorando
`k8s-gitops/apps/*/*`. Validar com:

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml get applications -n argocd
```

---

## Entendendo os charts antes de instalar

Antes de aplicar qualquer coisa, inspecione os valores padrão dos charts.
Isso é o que permite adaptar em vez de copiar cegamente.

```bash
# Ver versões disponíveis
helm search repo grafana/loki --versions | head -10
helm search repo grafana/promtail --versions | head -10

# Exportar valores padrão para referência
helm show values grafana/loki > /tmp/loki-default-values.yaml
helm show values grafana/promtail > /tmp/promtail-default-values.yaml
```

Os arquivos em `/tmp` servem como referência. O que realmente será aplicado
fica nos wrapper charts do `k8s-gitops`:

```bash
../k8s-gitops/apps/monitoring/loki/Chart.yaml
../k8s-gitops/apps/monitoring/loki/values.yaml
../k8s-gitops/apps/monitoring/promtail/Chart.yaml
../k8s-gitops/apps/monitoring/promtail/values.yaml
```

Os `values.yaml` desses wrapper charts mantêm a configuração original
aninhandada sob a chave do subchart (`loki:` ou `promtail:`). Validar antes
do commit:

```bash
cd ../k8s-gitops
helm dependency build apps/monitoring/loki
helm template loki apps/monitoring/loki --namespace monitoring

helm dependency build apps/monitoring/promtail
helm template promtail apps/monitoring/promtail --namespace monitoring
```

---

## Instalação via GitOps

### 1. Publicar Loki e Promtail no `k8s-gitops`

Loki e Promtail são gerenciados como Helm wrapper charts no repositório
GitOps:

```text
k8s-gitops/apps/monitoring/loki/
k8s-gitops/apps/monitoring/promtail/
```

Publicar a mudança:

```bash
cd ../k8s-gitops
git add apps/monitoring/loki apps/monitoring/promtail
git commit -m "feat: manage logs stack via argocd"
git push
```

### 2. Acompanhar a reconciliação

```bash
KC="kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml"

$KC get applications -n argocd
$KC get application loki -n argocd -o wide
$KC get application promtail -n argocd -o wide
$KC get pods -n monitoring -w
```

> O Loki é instalado como StatefulSet — o pod se chama `loki-0`.
> O PVC é provisionado automaticamente pelo k3s no primeiro start.

Verificar que o PVC foi criado:

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml get pvc -n monitoring
# storage-loki-0   Bound   ...   5Gi
```

> O Promtail roda como DaemonSet — um pod por node. Com 1 node no cluster,
> sobe exatamente 1 pod.

Verificar que o Promtail está enviando logs para o Loki:

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml logs -n monitoring daemonset/promtail | tail -20
# Deve aparecer linhas indicando descoberta e monitoramento de logs de todos os pods
```

### 3. Atualizar configuração de logs

O datasource do Loki é provisionado via ConfigMap junto com o Grafana em
`apps/monitoring/monitoring-stack`. Quando o arquivo é alterado no GitOps, o
ArgoCD reconcilia o ConfigMap. Se o pod do Grafana já estava rodando antes da
mudança, reiniciar o Deployment para recarregar provisioning:

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml rollout restart deployment/grafana -n monitoring
```

Aguardar o pod reiniciar:

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml get pods -n monitoring -w
# Aguardar: grafana-xxxxx   1/1   Running
```

Verificar que o datasource foi carregado:

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml logs -n monitoring deployment/grafana | grep -i "provisioning.datasources"
# Esperado: inserting datasource from configuration name=Loki
```

---

## Integração com o Grafana

### 1. Validar no Explore

1. **Explore** no menu lateral
2. Selecionar datasource **Loki**
3. Executar a query: `{namespace="monitoring", app="loki"}`
4. Logs dos pods do namespace `monitoring` devem aparecer

---

## Validação

```bash
bash scripts/validate-observability-logs.sh
```

O script executa as seguintes verificações:

| # | Teste | O que valida |
|---|-------|-------------|
| 1 | Applications loki/promtail Synced + Healthy | ArgoCD reconciliou a stack |
| 2 | Pod loki-0 Running | Loki está operacional |
| 3 | Pod promtail Running | Promtail está coletando |
| 4 | PVC storage-loki-0 Bound | Persistência configurada |
| 5 | Loki API acessível | Endpoint `/ready` retorna 200 |
| 6 | Labels disponíveis | Loki tem streams indexados |

Todos os testes passando = milestone `v0.4.0` concluído.

---

## Desinstalar

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml -n argocd delete application loki
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml -n argocd delete application promtail
```

> O PVC do Loki é preservado pelo Kubernetes após a remoção da Application.
> Para remover também os dados:
>
> ```bash
> kubectl delete pvc storage-loki-0 -n monitoring
> ```
