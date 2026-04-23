#!/bin/bash

set -euo pipefail

KUBECONFIG="$HOME/.kube/k8s-homelab.yaml"
PASS=0
FAIL=0

ok() {
  echo "✓ $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "✗ $1"
  FAIL=$((FAIL + 1))
}

echo "=== Validação — v0.5.0 gitops ==="
echo ""

# 1. Pods do ArgoCD Running
ARGOCD_PODS=$(kubectl --kubeconfig="$KUBECONFIG" get pods -n argocd \
  --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [ "$ARGOCD_PODS" -ge 5 ]; then
  ok "Pods ArgoCD Running ($ARGOCD_PODS pods)"
else
  fail "Pods ArgoCD insuficientes — esperado >= 5, encontrado $ARGOCD_PODS"
fi

# 2. ApplicationSet criado
kubectl --kubeconfig="$KUBECONFIG" get applicationset nexus -n argocd \
  --no-headers &>/dev/null \
  && ok "ApplicationSet nexus existe" \
  || fail "ApplicationSet nexus não encontrado"

# 3. Application nexus-argocd Synced
SYNC=$(kubectl --kubeconfig="$KUBECONFIG" get application nexus-argocd \
  -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
if [ "$SYNC" = "Synced" ]; then
  ok "Application nexus-argocd Synced"
else
  fail "Application nexus-argocd não está Synced — status: ${SYNC:-desconhecido}"
fi

# 4. Application nexus-argocd Healthy
HEALTH=$(kubectl --kubeconfig="$KUBECONFIG" get application nexus-argocd \
  -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null)
if [ "$HEALTH" = "Healthy" ]; then
  ok "Application nexus-argocd Healthy"
else
  fail "Application nexus-argocd não está Healthy — status: ${HEALTH:-desconhecido}"
fi

# 5. Pod nexus-argocd Running
NEXUS_POD=$(kubectl --kubeconfig="$KUBECONFIG" get pods -n nexus \
  -l app=nexus-argocd --field-selector=status.phase=Running \
  --no-headers 2>/dev/null | wc -l)
if [ "$NEXUS_POD" -ge 1 ]; then
  ok "Pod nexus-argocd Running"
else
  fail "Pod nexus-argocd não está Running"
fi

# 6. Ingress nexus-argocd acessível
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  --max-time 5 http://nexus.homelab.local 2>/dev/null)
if [ "$HTTP_CODE" != "000" ]; then
  ok "Ingress nexus-argocd acessível (HTTP $HTTP_CODE)"
else
  fail "Ingress nexus-argocd não acessível"
fi

# 7. Ingress ArgoCD acessível
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  --max-time 5 http://argocd.homelab.local 2>/dev/null)
if [ "$HTTP_CODE" != "000" ]; then
  ok "Ingress ArgoCD acessível (HTTP $HTTP_CODE)"
else
  fail "Ingress ArgoCD não acessível"
fi

echo ""
echo "=== Resultado: $PASS passou, $FAIL falhou ==="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
