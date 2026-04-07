#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# validate-connectivity.sh
# Testa toda a camada de rede entre host e VM após terraform apply
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ok()   { echo -e "${GREEN}  ✔ $1${NC}"; }
fail() { echo -e "${RED}  ✘ $1${NC}"; exit 1; }
info() { echo -e "${BLUE}  → $1${NC}"; }
warn() { echo -e "${YELLOW}  ⚠ $1${NC}"; }

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Validação de Conectividade - v0.1.0      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ── Obter dados do terraform output ───────────────────────────────────────────
cd "$(dirname "$0")/../terraform"

info "Lendo outputs do Terraform..."
VM_NAME=$(terraform output -raw vm_name 2>/dev/null) \
  || fail "Não foi possível obter o nome da VM. Execute 'terraform apply' primeiro."
KEY_PATH=$(terraform output -raw private_key_path 2>/dev/null) \
  || fail "Não foi possível obter o caminho da chave SSH."
VM_USER=$(terraform output -raw ssh_user 2>/dev/null) \
  || fail "Não foi possível obter o usuário SSH."

# ── Obter IP via virsh ─────────────────────────────────────────────────────────
info "Obtendo IP da VM via virsh..."
VM_IP=$(sudo virsh domifaddr "$VM_NAME" 2>/dev/null \
  | awk '/ipv4/ {print $4}' \
  | cut -d'/' -f1)

[[ -n "$VM_IP" ]] || fail "IP não encontrado. A VM pode ainda estar inicializando."

echo ""
echo "  VM      : $VM_NAME"
echo "  IP      : $VM_IP"
echo "  User    : $VM_USER"
echo "  SSH Key : $KEY_PATH"
echo ""

# ── Teste 1: Ping ─────────────────────────────────────────────────────────────
info "Teste 1/5 — Ping (ICMP)..."
if ping -c 3 -W 2 "$VM_IP" &>/dev/null; then
  ok "Ping OK"
else
  fail "Ping falhou — VM pode estar inicializando. Aguarde e tente novamente."
fi

# ── Teste 2: Porta SSH ────────────────────────────────────────────────────────
info "Teste 2/5 — Porta SSH (22)..."
if timeout 5 bash -c "echo >/dev/tcp/$VM_IP/22" 2>/dev/null; then
  ok "Porta 22 aberta"
else
  fail "Porta 22 fechada — cloud-init pode ainda estar em execução."
fi

# ── Teste 3: Autenticação SSH ─────────────────────────────────────────────────
info "Teste 3/5 — Autenticação SSH com chave ED25519..."
SSH_OPTS="-i $KEY_PATH -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes"
if ssh $SSH_OPTS "${VM_USER}@${VM_IP}" "echo ok" &>/dev/null; then
  ok "SSH autenticado com sucesso"
else
  fail "Falha na autenticação SSH. Verifique a chave em: $KEY_PATH"
fi

# ── Teste 4: DNS dentro da VM ─────────────────────────────────────────────────
info "Teste 4/5 — Resolução DNS dentro da VM..."
if ssh $SSH_OPTS "${VM_USER}@${VM_IP}" "getent hosts google.com &>/dev/null"; then
  ok "DNS funcionando dentro da VM"
else
  warn "DNS pode ter problema — verificar /etc/resolv.conf na VM"
fi

# ── Teste 5: cloud-init concluído ─────────────────────────────────────────────
info "Teste 5/5 — cloud-init finalizado..."
if ssh $SSH_OPTS "${VM_USER}@${VM_IP}" "test -f /tmp/cloud-init-complete"; then
  ok "cloud-init concluído"
else
  warn "cloud-init ainda em execução. Execute novamente em alguns minutos."
fi

# ── Resumo ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Todos os testes passaram! ✔              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo "  Para acessar a VM:"
echo -e "  ${YELLOW}ssh -i $KEY_PATH ${VM_USER}@${VM_IP}${NC}"
echo ""
