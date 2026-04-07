#!/usr/bin/env bash
# validate-k8s.sh — Validação do milestone v0.2.0 (k8s-operational)
# Todos os checks devem passar antes de criar a tag v0.2.0

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

# Garante limpeza dos pods temporários ao sair, mesmo em caso de erro
cleanup() {
  $KC delete pod validate-dns-ext validate-dns-svc validate-net-server validate-net-client \
    --ignore-not-found &>/dev/null || true
  $KC delete service validate-net-svc \
    --ignore-not-found &>/dev/null || true
}
trap cleanup EXIT

echo ""
echo "=== Validação — v0.2.0 k8s-operational ==="
echo ""

# ── Camada 1: infraestrutura básica ──────────────────────────────────────────

echo "  — infraestrutura"

if command -v kubectl &>/dev/null; then
  check "kubectl disponível na máquina host" "ok"
else
  check "kubectl disponível na máquina host" "fail"
fi

if [ -f "$KUBECONFIG" ]; then
  check "kubeconfig existe em $KUBECONFIG" "ok"
else
  check "kubeconfig existe em $KUBECONFIG" "fail"
fi

if $KC cluster-info &>/dev/null; then
  check "cluster responde (cluster-info)" "ok"
else
  check "cluster responde (cluster-info)" "fail"
fi

NODE_STATUS=$($KC get nodes --no-headers 2>/dev/null | awk '{print $2}' | head -1)
if [ "$NODE_STATUS" = "Ready" ]; then
  check "node está Ready" "ok"
else
  check "node está Ready (status: ${NODE_STATUS:-não encontrado})" "fail"
fi

NOT_READY=$($KC get pods -A --no-headers 2>/dev/null \
  | awk '{print $4}' \
  | grep -v -E "^(Running|Completed|Succeeded)$" \
  | wc -l)
if [ "$NOT_READY" -eq 0 ]; then
  check "todos os pods do sistema estão Running/Completed" "ok"
else
  check "todos os pods do sistema estão Running/Completed ($NOT_READY com problema)" "fail"
fi

COREDNS_POD=$($KC get pods -n kube-system --no-headers 2>/dev/null \
  | grep coredns | awk '{print $1}' | head -1)
if [ -n "$COREDNS_POD" ]; then
  COREDNS=$($KC get pod "$COREDNS_POD" -n kube-system \
    -o jsonpath='{.status.phase}' 2>/dev/null)
else
  COREDNS=""
fi
if [ "$COREDNS" = "Running" ]; then
  check "CoreDNS está Running" "ok"
else
  check "CoreDNS está Running (status: ${COREDNS:-não encontrado})" "fail"
fi

# ── Camada 2: DNS externo ─────────────────────────────────────────────────────

echo ""
echo "  — DNS externo"
echo "  → subindo pod para resolver google.com..."

$KC run validate-dns-ext \
  --image=busybox:stable \
  --restart=Never \
  --command -- sh -c "nslookup google.com" &>/dev/null

$KC wait --for=condition=Ready pod/validate-dns-ext --timeout=30s &>/dev/null

DNS_EXT_RESULT=$($KC logs validate-dns-ext 2>/dev/null)
if echo "$DNS_EXT_RESULT" | grep -q "Address"; then
  check "DNS externo: pod resolve google.com" "ok"
else
  check "DNS externo: pod resolve google.com" "fail"
fi

# ── Camada 3: DNS interno / service discovery ─────────────────────────────────

echo ""
echo "  — DNS interno"
echo "  → subindo pod servidor e Service..."

$KC run validate-net-server \
  --image=nginx:stable \
  --restart=Never \
  --labels="app=validate-net" &>/dev/null

$KC expose pod validate-net-server \
  --name=validate-net-svc \
  --port=80 &>/dev/null

$KC wait --for=condition=Ready pod/validate-net-server --timeout=60s &>/dev/null

echo "  → subindo pod cliente para resolver o Service via DNS..."
$KC run validate-dns-svc \
  --image=busybox:stable \
  --restart=Never \
  --command -- sh -c "nslookup validate-net-svc" &>/dev/null

$KC wait --for=condition=Ready pod/validate-dns-svc --timeout=30s &>/dev/null

DNS_SVC_RESULT=$($KC logs validate-dns-svc 2>/dev/null)
if echo "$DNS_SVC_RESULT" | grep -q "validate-net-svc"; then
  check "DNS interno: pod resolve nome do Service" "ok"
else
  check "DNS interno: pod resolve nome do Service" "fail"
fi

# ── Camada 4: comunicação entre pods via Service ──────────────────────────────

echo ""
echo "  — comunicação entre pods"
echo "  → subindo pod cliente para requisitar o servidor via Service..."

$KC run validate-net-client \
  --image=busybox:stable \
  --restart=Never \
  --command -- sh -c "wget -qO- http://validate-net-svc" &>/dev/null

$KC wait --for=condition=Ready pod/validate-net-client --timeout=30s &>/dev/null

NET_RESULT=$($KC logs validate-net-client 2>/dev/null)
if echo "$NET_RESULT" | grep -q "nginx"; then
  check "comunicação entre pods: cliente HTTP alcança servidor via Service" "ok"
else
  check "comunicação entre pods: cliente HTTP alcança servidor via Service" "fail"
fi

# ── Resultado final ───────────────────────────────────────────────────────────

echo ""
echo "=== Resultado: $PASS passou, $FAIL falhou ==="
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo "  Milestone v0.2.0 validado. Pode criar a tag:"
  echo ""
  echo "  git tag -a v0.2.0 -m \"k8s-operational: k3s instalado via Ansible, kubectl funcional, DNS e rede validados\""
  echo "  git push origin v0.2.0"
  echo ""
  exit 0
else
  echo "  Corrija os itens com ✗ antes de criar a tag."
  echo ""
  exit 1
fi
