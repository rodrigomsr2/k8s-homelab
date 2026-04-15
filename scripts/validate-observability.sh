#!/usr/bin/env bash
# validate-observability.sh — Validação do milestone v0.3.0 (observability-metrics)
# Todos os checks devem passar antes de criar a tag v0.3.0

set -uo pipefail

KUBECONFIG="$HOME/.kube/k8s-homelab.yaml"
KC="kubectl --kubeconfig=$KUBECONFIG"
PASS=0
FAIL=0

check() {
  local description="$1"
  local result="$2"
  if [ "$result" = "ok" ]; then
    echo "  ✓ $description"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $description"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "=== Validação — v0.3.0 observability-metrics ==="
echo ""

# ── Camada 1: pods da stack ───────────────────────────────────────────────────

echo "  — pods"

for pod in prometheus grafana node-exporter; do
  STATUS=$($KC get pods -n monitoring --no-headers 2>/dev/null \
    | grep "^$pod" | awk '{print $3}' | head -1)
  if [ "$STATUS" = "Running" ]; then
    check "pod $pod está Running" "ok"
  else
    check "pod $pod está Running (status: ${STATUS:-não encontrado})" "fail"
  fi
done

# ── Camada 2: Services acessíveis ────────────────────────────────────────────

echo ""
echo "  — services"

for svc in prometheus grafana node-exporter; do
  CLUSTER_IP=$($KC get service $svc -n monitoring \
    -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
  if [ -n "$CLUSTER_IP" ]; then
    check "service $svc existe (ClusterIP: $CLUSTER_IP)" "ok"
  else
    check "service $svc existe" "fail"
  fi
done

# ── Camada 3: Ingress configurado ─────────────────────────────────────────────

echo ""
echo "  — ingress"

for host in grafana.homelab.local prometheus.homelab.local; do
  INGRESS=$($KC get ingress -n monitoring --no-headers 2>/dev/null \
    | grep "$host" | wc -l)
  if [ "$INGRESS" -gt 0 ]; then
    check "Ingress configurado para $host" "ok"
  else
    check "Ingress configurado para $host" "fail"
  fi
done

for host in grafana.homelab.local prometheus.homelab.local; do
  if getent hosts "$host" &>/dev/null; then
    check "$host resolve no /etc/hosts" "ok"
  else
    check "$host resolve no /etc/hosts" "fail"
  fi
done

# ── Camada 4: Prometheus coletando métricas ───────────────────────────────────

echo ""
echo "  — prometheus"

PROM_URL="http://prometheus.homelab.local"

# Prometheus responde
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$PROM_URL/-/healthy" 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
  check "Prometheus responde em $PROM_URL" "ok"
else
  check "Prometheus responde em $PROM_URL (HTTP $HTTP_CODE)" "fail"
fi

# Jobs com targets UP
for job in prometheus kubelet cadvisor kubernetes-pods; do
  UP=$(curl -s "$PROM_URL/api/v1/query?query=up%7Bjob%3D%22$job%22%7D" 2>/dev/null \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('data', {}).get('result', [])
up = sum(1 for r in results if r.get('value', [None, None])[1] == '1')
print(up)
" 2>/dev/null)
  if [ "${UP:-0}" -gt 0 ]; then
    check "job $job tem targets UP" "ok"
  else
    check "job $job tem targets UP" "fail"
  fi
done

# Métricas do Node Exporter chegando
NODE_METRICS=$(curl -s "$PROM_URL/api/v1/query?query=node_cpu_seconds_total" 2>/dev/null \
  | grep -o '"result":\[.' | grep -v '\[\]' | wc -l)
if [ "$NODE_METRICS" -gt 0 ]; then
  check "métricas do Node Exporter presentes (node_cpu_seconds_total)" "ok"
else
  check "métricas do Node Exporter presentes (node_cpu_seconds_total)" "fail"
fi

# Métricas do cAdvisor chegando
CADVISOR_METRICS=$(curl -s "$PROM_URL/api/v1/query?query=container_cpu_usage_seconds_total" 2>/dev/null \
  | grep -o '"result":\[.' | grep -v '\[\]' | wc -l)
if [ "$CADVISOR_METRICS" -gt 0 ]; then
  check "métricas do cAdvisor presentes (container_cpu_usage_seconds_total)" "ok"
else
  check "métricas do cAdvisor presentes (container_cpu_usage_seconds_total)" "fail"
fi

# ── Camada 5: Grafana acessível ───────────────────────────────────────────────

echo ""
echo "  — grafana"

GRAFANA_URL="http://grafana.homelab.local"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$GRAFANA_URL/api/health" 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
  check "Grafana responde em $GRAFANA_URL" "ok"
else
  check "Grafana responde em $GRAFANA_URL (HTTP $HTTP_CODE)" "fail"
fi

# Datasource Prometheus configurado
DS=$(curl -s -u admin:homelab "$GRAFANA_URL/api/datasources" 2>/dev/null \
  | grep -o '"type":"prometheus"' | wc -l)
if [ "$DS" -gt 0 ]; then
  check "datasource Prometheus configurado no Grafana" "ok"
else
  check "datasource Prometheus configurado no Grafana" "fail"
fi

# ── Resultado final ───────────────────────────────────────────────────────────

echo ""
echo "=== Resultado: $PASS passou, $FAIL falhou ==="
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo "  Milestone v0.3.0 validado. Pode criar a tag:"
  echo ""
  echo "  git tag -a v0.3.0 -m \"observability-metrics: Prometheus + Grafana + Node Exporter operacionais\""
  echo "  git push origin v0.3.0"
  echo ""
  exit 0
else
  echo "  Corrija os itens com ✗ antes de criar a tag."
  echo ""
  exit 1
fi
