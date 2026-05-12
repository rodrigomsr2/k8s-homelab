# Guia de instalação — Observabilidade: métricas (v0.3.0)

Pré-requisito: milestone `v0.5.3` concluído — k3s instalado, ArgoCD
operacional e ApplicationSet `homelab` monitorando `k8s-gitops/apps/*/*`.

---

## 1. Adicionar entradas no /etc/hosts

O acesso ao Grafana e ao Prometheus é feito via Ingress por host. A máquina host precisa resolver esses nomes para o IP da VM (disponível no `CLAUDE.local.md`):

```bash
echo "192.168.122.X grafana.homelab.local" | sudo tee -a /etc/hosts
echo "192.168.122.X prometheus.homelab.local" | sudo tee -a /etc/hosts
```

---

## 2. Publicar os manifests no GitOps

A stack de métricas é gerenciada pelo ArgoCD a partir do repositório
`k8s-gitops`, em:

```text
k8s-gitops/apps/monitoring/monitoring-stack/
```

O ApplicationSet `homelab` cria automaticamente a Application
`monitoring-stack` quando essa pasta existe na branch `main` do
`k8s-gitops`. Publicar a mudança:

```bash
cd ../k8s-gitops
git add apps/monitoring/monitoring-stack
git commit -m "feat: manage monitoring stack via argocd"
git push
```

## 3. Acompanhar a reconciliação

```bash
KC="kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml"

$KC get applications -n argocd
$KC get application monitoring-stack -n argocd -o wide
$KC get pods -n monitoring -w
```

Todos os pods devem ficar `Running` antes de prosseguir. O Grafana pode demorar alguns segundos a mais na primeira inicialização — ele executa migrations do banco SQLite interno.

---

## 4. Validar targets no Prometheus

Acessa `http://prometheus.homelab.local/targets` e confirma que todos os jobs estão com status `UP`:

| Job | O que coleta |
|-----|-------------|
| `prometheus` | Métricas do próprio Prometheus |
| `kubelet` | Métricas do kubelet e do node |
| `cadvisor` | Métricas de containers via cAdvisor |
| `kubernetes-pods` | Pods com anotação `prometheus.io/scrape: "true"` |

O job `kubernetes-pods` deve listar pelo menos dois targets: o Node Exporter e o Traefik.

---

## 5. Acessar o Grafana

Acessa `http://grafana.homelab.local` e faz login com:

- **Usuário:** `admin`
- **Senha:** `homelab`

O datasource do Prometheus já está pré-configurado via provisioning — não é necessário configurar manualmente.

---

## 6. Importar os dashboards

### Dashboard adaptado para k3s (315)

O dashboard Kubernetes cluster monitoring foi adaptado para compatibilidade com k3s e containerd. O JSON modificado está versionado no repositório:

1. Menu lateral -> **Dashboards** -> **New** -> **Import**
2. Clica em **Upload dashboard JSON file**
3. Seleciona `monitoring-dashboards/kubernetes-cluster-monitoring-315.json`
4. Seleciona o datasource **Prometheus** -> **Import**

### Node Exporter Full (1860)

Este dashboard não precisou de modificações e não está versionado no repositório:

1. Menu lateral -> **Dashboards** -> **New** -> **Import**
2. No campo **Import via grafana.com**, digita `1860` -> **Load**
3. Seleciona o datasource **Prometheus** -> **Import**

---

## 7. Executar script de validação

```bash
bash scripts/validate-observability.sh
```

O script valida a Application `monitoring-stack` no ArgoCD e a camada em
runtime: pods, services, ingresses, targets do Prometheus e datasource do
Grafana. Todos os checks devem passar antes de criar a tag `v0.3.0`.
