# Observabilidade — Logs com Loki + Promtail

Guia para instalar a stack de logs no cluster existente usando Helm.
Ao final, o ambiente estará no estado `v0.4.0` — logs dos pods coletados
pelo Promtail, armazenados no Loki e consultáveis via Grafana.

Pré-requisito: milestone `v0.3.0` concluído — namespace `monitoring`,
Prometheus e Grafana operacionais.

---

## Pré-requisitos

### Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

helm version
# Requer >= 3.0.0
```

### Repositório oficial da Grafana

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

Verificar que o repositório foi adicionado:

```bash
helm repo list
# grafana    https://grafana.github.io/helm-charts
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
são os `values.yaml` do repositório, que sobrescrevem apenas o necessário.

---

## Instalação

### 1. Instalar o Loki

```bash
helm install loki grafana/loki \
  --kubeconfig=$HOME/.kube/k8s-homelab.yaml \
  --namespace monitoring \
  --values k8s/monitoring/loki-values.yaml
```

Acompanhar o pod subindo:

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml get pods -n monitoring -w
# Aguardar: loki-0   1/1   Running
```

> O Loki é instalado como StatefulSet — o pod se chama `loki-0`.
> O PVC é provisionado automaticamente pelo k3s no primeiro start.

Verificar que o PVC foi criado:

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml get pvc -n monitoring
# storage-loki-0   Bound   ...   5Gi
```

### 2. Instalar o Promtail

```bash
helm install promtail grafana/promtail \
  --kubeconfig=$HOME/.kube/k8s-homelab.yaml \
  --namespace monitoring \
  --values k8s/monitoring/promtail-values.yaml
```

Acompanhar o pod subindo:

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml get pods -n monitoring -w
# Aguardar: promtail-xxxxx   1/1   Running
```

> O Promtail roda como DaemonSet — um pod por node. Com 1 node no cluster,
> sobe exatamente 1 pod.

Verificar que o Promtail está enviando logs para o Loki:

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml logs -n monitoring daemonset/promtail | tail -20
# Deve aparecer linhas indicando descoberta e monitoramento de logs de todos os pods
```

### 3. Atualizar o Grafana

O datasource do Loki é provisionado via ConfigMap junto com o Grafana.
Aplicar as atualizações e reiniciar o pod:

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml apply -f k8s/monitoring/04-grafana.yaml

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
| 1 | Pod loki-0 Running | Loki está operacional |
| 2 | Pod promtail Running | Promtail está coletando |
| 3 | PVC storage-loki-0 Bound | Persistência configurada |
| 4 | Loki API acessível | Endpoint `/ready` retorna 200 |
| 5 | Labels disponíveis | Loki tem streams indexados |

Todos os 5 testes passando = milestone `v0.4.0` concluído.
```

---

## Desinstalar

```bash
helm uninstall loki --kubeconfig=$HOME/.kube/k8s-homelab.yaml -n monitoring
helm uninstall promtail --kubeconfig=$HOME/.kube/k8s-homelab.yaml -n monitoring
```

> O PVC do Loki **não é deletado automaticamente** pelo `helm uninstall` —
> os dados de log são preservados. Para remover também os dados:
>
> ```bash
> kubectl delete pvc storage-loki-0 -n monitoring
> ```