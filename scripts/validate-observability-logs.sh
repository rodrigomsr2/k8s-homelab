#!/usr/bin/env bash

set -uo pipefail

KUBECONFIG="$HOME/.kube/k8s-homelab.yaml"
NAMESPACE="monitoring"
PASS=0
FAIL=0

check() {
  local description="$1"
  local result="$2"

  if [ "$result" = "true" ]; then
    echo "  [PASS] $description"
    ((PASS++)) || true
  else
    echo "  [FAIL] $description"
    ((FAIL++)) || true
  fi
}

echo ""
echo "========================================"
echo " Validação — v0.4.0 observability-logs"
echo "========================================"
echo ""

# 1. Applications ArgoCD
echo "[ 1/6 ] ArgoCD"
for app in loki promtail; do
  SYNC=$(kubectl --kubeconfig="$KUBECONFIG" get application "$app" -n argocd \
    -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "NotFound")
  HEALTH=$(kubectl --kubeconfig="$KUBECONFIG" get application "$app" -n argocd \
    -o jsonpath='{.status.health.status}' 2>/dev/null || echo "NotFound")
  check "Application $app Synced + Healthy" "$([ "$SYNC" = "Synced" ] && [ "$HEALTH" = "Healthy" ] && echo true || echo false)"
done

# 2. Pod loki-0 Running
echo ""
echo "[ 2/6 ] Loki"
LOKI_STATUS=$(kubectl --kubeconfig="$KUBECONFIG" get pod loki-0 -n "$NAMESPACE" \
  --no-headers -o custom-columns=":status.phase" 2>/dev/null || echo "NotFound")
check "Pod loki-0 Running" "$([ "$LOKI_STATUS" = "Running" ] && echo true || echo false)"

# 3. Pod promtail Running
echo ""
echo "[ 3/6 ] Promtail"
PROMTAIL_STATUS=$(kubectl --kubeconfig="$KUBECONFIG" get pods -n "$NAMESPACE" \
  -l app.kubernetes.io/name=promtail --no-headers \
  -o custom-columns=":status.phase" 2>/dev/null | head -1 || echo "NotFound")
check "Pod promtail Running" "$([ "$PROMTAIL_STATUS" = "Running" ] && echo true || echo false)"

# 4. PVC storage-loki-0 Bound
echo ""
echo "[ 4/6 ] Persistência"
PVC_STATUS=$(kubectl --kubeconfig="$KUBECONFIG" get pvc storage-loki-0 -n "$NAMESPACE" \
  --no-headers -o custom-columns=":status.phase" 2>/dev/null || echo "NotFound")
check "PVC storage-loki-0 Bound" "$([ "$PVC_STATUS" = "Bound" ] && echo true || echo false)"

# 5. Loki API acessível
echo ""
echo "[ 5/6 ] Loki API"
kubectl --kubeconfig="$KUBECONFIG" port-forward -n "$NAMESPACE" pod/loki-0 3100:3100 &>/dev/null &
PF_PID=$!
sleep 2
LOKI_READY=$(curl -s http://localhost:3100/ready 2>/dev/null || echo "")
kill $PF_PID 2>/dev/null || true
check "Endpoint /ready retorna ready" "$([ "$LOKI_READY" = "ready" ] && echo true || echo false)"

# 6. Labels disponíveis no Loki
echo ""
echo "[ 6/6 ] Streams indexados"
kubectl --kubeconfig="$KUBECONFIG" port-forward -n "$NAMESPACE" pod/loki-0 3100:3100 &>/dev/null &
PF_PID=$!
sleep 2
LABELS=$(curl -s -H "X-Scope-OrgID: homelab" http://localhost:3100/loki/api/v1/labels 2>/dev/null || echo "")
kill $PF_PID 2>/dev/null || true
HAS_LABELS=$(echo "$LABELS" | grep -q '"namespace"' && echo true || echo false)
check "Labels disponíveis no Loki" "$HAS_LABELS"

# Resultado final
echo ""
echo "========================================"
echo " Resultado: $PASS passou, $FAIL falhou"
echo "========================================"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo " Milestone v0.4.0 concluído."
  echo ""
  exit 0
else
  exit 1
fi
