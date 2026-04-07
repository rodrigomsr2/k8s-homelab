# Guia de instalação — Kubernetes (v0.2.0)

Pré-requisito: milestone `v0.1.0` concluído — VM Ubuntu 24.04 rodando, SSH funcionando.

---

## 1. Instalar Ansible na máquina host

Ansible é instalado apenas na máquina host. A VM não precisa ter Ansible.

```bash
sudo apt update
sudo apt install -y ansible
ansible --version
```

Versão mínima recomendada: 2.14.

---

## 2. Preencher o inventário

Copiar o arquivo de exemplo e preencher com os valores do seu ambiente local (disponíveis no `CLAUDE.local.md`):

```bash
cp ansible/inventory/hosts.ini.example ansible/inventory/hosts.ini
# editar com IP da VM e path absoluto da chave SSH
nano ansible/inventory/hosts.ini
```

O arquivo preenchido deve ficar assim:

```ini
[k3s_nodes]
k8s-homelab ansible_host=192.168.122.X ansible_user=devops ansible_ssh_private_key_file=/home/seu-usuario/k8s-homelab/.ssh/homelab_ed25519
```

`hosts.ini` está no `.gitignore` — as informações locais não são versionadas. O `hosts.ini.example` com placeholders é o arquivo versionado.

---

## 3. Validar conectividade Ansible

Antes de rodar o playbook, confirmar que o Ansible consegue alcançar a VM:

```bash
cd ansible/
ansible -i inventory/hosts.ini k3s_nodes -m ping
```

Saída esperada:

```
k8s-homelab | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

---

## 4. Executar o playbook

```bash
cd ansible/
ansible-playbook -i inventory/hosts.ini install-k3s.yml
```

O playbook vai:
1. Instalar o k3s via script oficial
2. Aguardar o node ficar `Ready`
3. Copiar o `kubeconfig` para `~/.kube/k8s-homelab.yaml` na máquina host

Tempo estimado: 2–4 minutos.

---

## 5. Verificar kubectl na máquina host

O kubeconfig foi copiado pelo playbook para `~/.kube/k8s-homelab.yaml`. Passar o arquivo explicitamente em cada comando:

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml get nodes
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml get pods -A
```

Saída esperada em `get nodes`:

```
NAME           STATUS   ROLES                  AGE   VERSION
k8s-homelab   Ready    control-plane,master   Xm    v1.X.X+k3s1
```

O `--kubeconfig` explícito é a abordagem correta em ambientes com múltiplos clusters — evita aplicar comandos no cluster errado por ter esquecido qual contexto estava ativo.

---

## 6. Executar script de validação

```bash
bash scripts/validate-k8s.sh
```

Todos os checks devem passar antes de criar a tag `v0.2.0`.
