#cloud-config

hostname: ${hostname}
manage_etc_hosts: true

# ─── Usuário ────────────────────────────────────────────────────────────────────
users:
  - name: ${username}
    gecos: DevOps User
    groups: [sudo, docker]
    shell: /bin/bash
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    ssh_authorized_keys:
      - ${public_key}

# Desabilitar login como root via SSH
disable_root: true

# ─── SSH ────────────────────────────────────────────────────────────────────────
ssh_pwauth: false

# ─── Pacotes ────────────────────────────────────────────────────────────────────
package_update: true
package_upgrade: false

packages:
  - curl
  - wget
  - git
  - vim
  - htop
  - net-tools
  - iputils-ping
  - iptables
  - open-iscsi     # necessário para storage no k8s
  - nfs-common     # necessário para PVs NFS no k8s

# ─── Configurações de kernel para Kubernetes ────────────────────────────────────
write_files:
  - path: /etc/modules-load.d/k8s.conf
    content: |
      overlay
      br_netfilter
  - path: /etc/sysctl.d/99-k8s.conf
    content: |
      net.bridge.bridge-nf-call-iptables  = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.ipv4.ip_forward                 = 1

# ─── Comandos pós-boot ───────────────────────────────────────────────────────────
runcmd:
  - modprobe overlay
  - modprobe br_netfilter
  - sysctl --system
  - swapoff -a
  - sed -i '/swap/d' /etc/fstab
  - echo "cloud-init done" > /tmp/cloud-init-complete

# ─── Mensagem final ──────────────────────────────────────────────────────────────
final_message: |
  VM ${hostname} provisionada com sucesso!
  Usuario: ${username}
  Acesso: SSH com chave ED25519
