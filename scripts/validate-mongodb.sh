#!/usr/bin/env bash
# validate-mongodb.sh — Validação do milestone v0.6.0 (mongodb-deployed)
# Todos os checks devem passar antes de criar a tag v0.6.0

set -uo pipefail

# ── Configuração ─────────────────────────────────────────────────────────────

MONGODB_IP="${MONGODB_IP:-192.168.123.20}"
MONGODB_PORT="${MONGODB_PORT:-27017}"
SSH_KEY="${SSH_KEY:-.ssh/homelab_ed25519}"
SSH_USER="${SSH_USER:-devops}"
SSH_TARGET="${SSH_USER}@${MONGODB_IP}"

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

ssh_exec() {
  ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=5 \
    -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "$@"
}

echo ""
echo "=== Validação — v0.6.0 mongodb-deployed ==="
echo ""

# ── Camada 1: VM acessível ───────────────────────────────────────────────────

echo "  — VM"

if ping -c 1 -W 2 "$MONGODB_IP" &>/dev/null; then
  check "VM responde a ping ($MONGODB_IP)" "ok"
else
  check "VM responde a ping ($MONGODB_IP)" "fail"
fi

if ssh_exec "hostname" 2>/dev/null | grep -q "^mongodb-01$"; then
  check "SSH funciona e hostname é mongodb-01" "ok"
else
  check "SSH funciona e hostname é mongodb-01" "fail"
fi

# ── Camada 2: serviço mongod ─────────────────────────────────────────────────

echo "  — serviço"

if ssh_exec "systemctl is-active --quiet mongod" 2>/dev/null; then
  check "serviço mongod está active (running)" "ok"
else
  check "serviço mongod está active (running)" "fail"
fi

if ssh_exec "systemctl is-enabled --quiet mongod" 2>/dev/null; then
  check "serviço mongod está enabled (boot automático)" "ok"
else
  check "serviço mongod está enabled (boot automático)" "fail"
fi

# ── Camada 3: bind e rede ────────────────────────────────────────────────────

echo "  — bind e rede"

# Confirma que o bind é 0.0.0.0 (não 127.0.0.1) — caso contrário,
# mongosh do host falharia mas a VM responderia em localhost
BIND_IP=$(ssh_exec "grep -E '^\s*bindIp:' /etc/mongod.conf | awk '{print \$2}'" 2>/dev/null || echo "")
if [ "$BIND_IP" = "0.0.0.0" ]; then
  check "bindIp configurado como 0.0.0.0 em /etc/mongod.conf" "ok"
else
  check "bindIp configurado como 0.0.0.0 em /etc/mongod.conf (atual: ${BIND_IP:-não encontrado})" "fail"
fi

if nc -z -w 3 "$MONGODB_IP" "$MONGODB_PORT" &>/dev/null; then
  check "porta $MONGODB_PORT aberta externamente em $MONGODB_IP" "ok"
else
  check "porta $MONGODB_PORT aberta externamente em $MONGODB_IP" "fail"
fi

# ── Camada 4: protocolo MongoDB ──────────────────────────────────────────────

echo "  — protocolo MongoDB"

if ! command -v mongosh &>/dev/null; then
  check "mongosh disponível no host" "fail"
else
  check "mongosh disponível no host" "ok"

  # Ping no servidor — valida protocolo wire end-to-end
  PING_OUTPUT=$(mongosh --host "$MONGODB_IP" --port "$MONGODB_PORT" --quiet \
    --eval "db.runCommand({ping: 1}).ok" 2>/dev/null || echo "")
  if [ "$PING_OUTPUT" = "1" ]; then
    check "mongosh ping retorna ok: 1" "ok"
  else
    check "mongosh ping retorna ok: 1" "fail"
  fi

  # Insert + find num database de teste — valida escrita e leitura
  CRUD_OUTPUT=$(mongosh --host "$MONGODB_IP" --port "$MONGODB_PORT" --quiet \
    --eval '
      const db = db.getSiblingDB("validate_v060");
      db.smoke.insertOne({test: "v0.6.0", ts: new Date()});
      const doc = db.smoke.findOne({test: "v0.6.0"});
      db.smoke.drop();
      print(doc.test);
    ' 2>/dev/null | tail -1)
  if [ "$CRUD_OUTPUT" = "v0.6.0" ]; then
    check "insert + find + drop num database de teste" "ok"
  else
    check "insert + find + drop num database de teste" "fail"
  fi
fi

# ── Resultado ────────────────────────────────────────────────────────────────

echo ""
echo "  Resultado: $PASS passaram, $FAIL falharam"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo "  Tudo OK. Pode criar a tag:"
  echo ""
  echo "  git tag -a v0.6.0 -m \"mongodb-deployed: MongoDB 8.0 standalone via Ansible, acessível na rede homelab\""
  echo "  git push origin v0.6.0"
  echo ""
  exit 0
else
  echo "  Corrija os itens com ✗ antes de criar a tag."
  echo ""
  exit 1
fi
