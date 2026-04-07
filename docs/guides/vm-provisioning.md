# Provisionamento da VM

Guia para subir a VM local do zero usando Terraform + KVM.
Ao final, o ambiente estará no estado `v0.1.0` — pronto para receber o Kubernetes.

---

## Pré-requisitos

### KVM e libvirt

```bash
# Verificar se o CPU suporta virtualização
egrep -c '(vmx|svm)' /proc/cpuinfo
# Qualquer número > 0 indica suporte
```

```bash
sudo apt update
sudo apt install -y \
  qemu-kvm \
  libvirt-daemon-system \
  libvirt-clients \
  virtinst \
  bridge-utils
```

```bash
# Adicionar seu usuário aos grupos necessários
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER

# Aplicar na sessão atual sem precisar de logout
newgrp libvirt
```

> Os grupos só são carregados automaticamente em sessões iniciadas após
> a mudança. Para não depender do `newgrp`, faça logout e login após
> este passo. Consulte o runbook `docs/runbook/libvirt.md` se o Terraform
> reclamar de `permission denied` no socket do libvirt.

```bash
# Verificar que o serviço está ativo
sudo systemctl enable --now libvirtd
sudo systemctl status libvirtd
```

### Terraform

```bash
sudo apt update && sudo apt install -y gnupg software-properties-common

wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor | \
  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install -y terraform

terraform version
# Requer >= 1.6.0
```

### Variável de ambiente do libvirt

O `virsh` e o Terraform precisam saber que devem conectar na sessão do
sistema (`qemu:///system`) e não na sessão do usuário:

```bash
export LIBVIRT_DEFAULT_URI="qemu:///system"
```

Adicione ao `~/.bashrc` para persistir:

```bash
echo 'export LIBVIRT_DEFAULT_URI="qemu:///system"' >> ~/.bashrc
source ~/.bashrc
```

### Rede NAT padrão do libvirt

O Terraform usa a rede `default` do libvirt para atribuir IP à VM via DHCP.

```bash
virsh net-list --all
# A rede "default" deve aparecer como "active"
```

Se estiver inativa, consulte o problema 1 em `docs/runbook/libvirt.md`.

### Pool de armazenamento padrão

O pool `default` é onde o libvirt armazena os volumes das VMs. No Ubuntu 24.04
ele não é criado automaticamente durante a instalação do libvirt.

```bash
virsh pool-list --all
# O pool "default" deve aparecer como "active"
```

Se não existir:

```bash
sudo virsh pool-define-as default dir --target /var/lib/libvirt/images
sudo virsh pool-build default
sudo virsh pool-start default
sudo virsh pool-autostart default
```

---

## Execução

### 1. Inicializar o Terraform

```bash
cd terraform/
terraform init
```

O Terraform baixa o provider `dmacvicar/libvirt`. Saída esperada:

```
Terraform has been successfully initialized!
```

### 2. Revisar o plano

```bash
terraform plan
```

Recursos que serão criados:

| Recurso | O que é |
|---------|---------|
| `tls_private_key.homelab` | Par de chaves ED25519 gerado na memória |
| `local_sensitive_file.private_key` | Chave privada salva em `.ssh/homelab_ed25519` |
| `local_file.public_key` | Chave pública salva em `.ssh/homelab_ed25519.pub` |
| `libvirt_volume.ubuntu_base` | Download da imagem Ubuntu 24.04 cloud (~600 MB) |
| `libvirt_volume.vm_disk` | Disco da VM (40 GB, copy-on-write sobre a base) |
| `libvirt_cloudinit_disk.init` | Configuração cloud-init |
| `libvirt_volume.cloudinit_iso` | ISO cloud-init no pool |
| `libvirt_domain.vm` | A VM em si (8 GB RAM, 4 vCPUs) |

### 3. Aplicar

```bash
terraform apply
```

Digite `yes` para confirmar.

> O primeiro apply faz download da imagem Ubuntu (~600 MB) — pode levar alguns
> minutos dependendo da conexão. Os applies seguintes são rápidos pois a imagem
> fica cacheada no pool do libvirt.

### 4. Obter o IP da VM

O IP não é exposto diretamente pelo Terraform — obtê-lo via virsh após a VM subir:

```bash
virsh domifaddr k8s-node-01
```

Anote o IP e preencha o `CLAUDE.local.md` com ele.

### 5. Aguardar o cloud-init

A VM leva cerca de 2 minutos para concluir o cloud-init após subir.
O cloud-init instala pacotes e aplica as configurações de kernel necessárias
para o Kubernetes. Para acompanhar em tempo real:

```bash
sudo virsh console k8s-node-01
# Sair do console: Ctrl+]
```

### 6. Validar

```bash
cd ..
bash scripts/validate-connectivity.sh
```

O script executa 5 verificações:

| # | Teste | O que valida |
|---|-------|-------------|
| 1 | Ping (ICMP) | VM está na rede e respondendo |
| 2 | Porta 22 | Serviço SSH está ativo |
| 3 | Autenticação SSH | Chave ED25519 foi aceita pelo cloud-init |
| 4 | DNS interno | VM tem acesso à internet |
| 5 | cloud-init | Configuração inicial foi concluída |

Todos os 5 testes passando = milestone `v0.1.0` concluído.

---

## O que o cloud-init configura

É útil saber o que acontece automaticamente na VM para não tentar
configurar manualmente algo que já foi feito.

| Configuração | Valor | Por quê |
|---|---|---|
| Usuário | `devops` | Usuário não-root com sudo sem senha |
| Autenticação SSH | Chave ED25519 apenas | Login por senha desabilitado |
| Root via SSH | Desabilitado | Boa prática de segurança |
| Swap | Desabilitado | Requisito do Kubernetes |
| Módulo `overlay` | Carregado | Requisito do container runtime |
| Módulo `br_netfilter` | Carregado | Requisito de rede do Kubernetes |
| `ip_forward` | Habilitado | Requisito de rede do Kubernetes |

---

## Taguear o milestone

Quando todos os 5 testes passarem:

```bash
git add -A
git commit -m "feat: VM Ubuntu 24.04 provisionada via Terraform + KVM"

git tag -a v0.1.0 -m "vm-provisioned: VM Ubuntu 24.04 via Terraform+KVM, SSH com ED25519, conectividade validada"
git push origin main --tags
```

---

## Destruir o ambiente

```bash
cd terraform/
terraform destroy
```

Remove a VM, os discos e a ISO cloud-init.
A imagem base (`ubuntu-24.04-base`) é preservada no pool para acelerar
o próximo `terraform apply`.

Para remover também a imagem base:

```bash
sudo virsh vol-delete ubuntu-24.04-base --pool default
```
