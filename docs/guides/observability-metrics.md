# Guia de instalação — Observabilidade: métricas (v0.3.0)

Pré-requisito: milestone `v0.2.0` concluído — k3s instalado, kubectl funcional, DNS e rede validados.

---

## 1. Adicionar entradas no /etc/hosts

O acesso ao Grafana e ao Prometheus é feito via Ingress por host. A máquina host precisa resolver esses nomes para o IP da VM (disponível no `CLAUDE.local.md`):

```bash
echo "192.168.122.X grafana.homelab.local" | sudo tee -a /etc/hosts
echo "192.168.122.X prometheus.homelab.local" | sudo tee -a /etc/hosts
```

---

## 2. Aplicar os manifests

Os manifests estão em `k8s/monitoring/` e devem ser aplicados em ordem:

```bash
KC="kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml"

$KC apply -f k8s/monitoring/01-namespace-rbac.yaml
$KC apply -f k8s/monitoring/02-prometheus-configmap.yaml
$KC apply -f k8s/monitoring/03-prometheus.yaml
$KC apply -f k8s/monitoring/04-grafana.yaml
$KC apply -f k8s/monitoring/05-ingress.yaml
$KC apply -f k8s/monitoring/06-node-exporter.yaml
```

Acompanhar os pods subindo:

```bash
$KC get pods -n monitoring -w
```

Todos os pods devem ficar `Running` antes de prosseguir. O Grafana pode demorar alguns segundos a mais na primeira inicialização — ele executa migrations do banco SQLite interno.

---

## 3. Validar targets no Prometheus

Acessa `http://prometheus.homelab.local/targets` e confirma que todos os jobs estão com status `UP`:

| Job | O que coleta |
|-----|-------------|
| `prometheus` | Métricas do próprio Prometheus |
| `kubelet` | Métricas do kubelet e do node |
| `cadvisor` | Métricas de containers via cAdvisor |
| `kubernetes-pods` | Pods com anotação `prometheus.io/scrape: "true"` |

O job `kubernetes-pods` deve listar pelo menos dois targets: o Node Exporter e o Traefik.

---

## 4. Acessar o Grafana

Acessa `http://grafana.homelab.local` e faz login com:

- **Usuário:** `admin`
- **Senha:** `homelab`

O datasource do Prometheus já está pré-configurado via provisioning — não é necessário configurar manualmente.

---

## 5. Importar os dashboards

### Dashboard adaptado para k3s (315)

O dashboard Kubernetes cluster monitoring foi adaptado para compatibilidade com k3s e containerd. O JSON modificado está versionado no repositório:

1. Menu lateral → **Dashboards** → **New** → **Import**
2. Clica em **Upload dashboard JSON file**
3. Seleciona `k8s/monitoring/dashboards/kubernetes-cluster-monitoring-315.json`
4. Seleciona o datasource **Prometheus** → **Import**

### Node Exporter Full (1860)

Este dashboard não precisou de modificações e não está versionado no repositório:

1. Menu lateral → **Dashboards** → **New** → **Import**
2. No campo **Import via grafana.com**, digita `1860` → **Load**
3. Seleciona o datasource **Prometheus** → **Import**

---

## 6. Executar script de validação

```bash
bash scripts/validate-observability.sh
```

Todos os checks devem passar antes de criar a tag `v0.3.0`.
