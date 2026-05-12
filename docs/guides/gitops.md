# GitOps — ArgoCD + k8s-gitops

Guia para instalar o ArgoCD no cluster e configurar o fluxo GitOps completo
via Ansible. Ao final, o ambiente estará no estado `v0.5.3` — o ArgoCD
gerencia todas as aplicações do cluster declarativamente, incluindo a si
mesmo (Ingress e ApplicationSet auto-managed).

Pré-requisito: milestone `v0.4.0` concluído — cluster operacional com
Prometheus, Grafana e Loki funcionais.

---

## Conceito — onde mora o quê

A separação de responsabilidades é a chave para entender o que está
acontecendo:

| Camada | Onde mora | O quê |
|--------|-----------|-------|
| Bootstrap do ArgoCD | `k8s-homelab/ansible/install-argocd.yml` | Instala o release Helm, cria o namespace, aplica o ApplicationSet inicial |
| Config do ArgoCD | `k8s-homelab/ansible/files/argocd-values.yaml` | Valores do chart Helm (dex/notifications off, server.insecure) |
| Config do GitOps | `k8s-gitops/apps/argocd/argocd-config/` | Ingress + ApplicationSet auto-managed |
| Aplicações | `k8s-gitops/apps/<namespace>/<app>/` | Manifests Kubernetes das aplicações |

O Ansible toca o release Helm. O ArgoCD reconcilia tudo o mais a partir do
`k8s-gitops`. Veja `docs/adr/ADR-009-argocd-bootstrap.md` para o racional.

---

## Pré-requisitos

### Collection Ansible

O playbook usa módulos da collection `kubernetes.core` (`helm`,
`helm_repository`, `k8s`, `k8s_info`). Instalar:

```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

### `kubectl` e `helm` instalados no host

A collection invoca os binários nativos. Validar:

```bash
kubectl version --client
helm version
```

### Python venv disponível no host

O playbook cria automaticamente um virtualenv local em `.venv/` e instala
as dependências Python usadas pelos módulos `kubernetes.core`:

- `kubernetes`
- `PyYAML`
- `jsonpatch`

Isso evita instalar pacotes no Python do sistema, que em distribuições
recentes pode ser bloqueado por PEP 668 (`externally-managed-environment`).
Pré-requisito do host: `python3 -m venv` precisa funcionar. Em Ubuntu/Debian,
se esse comando não existir, instalar o pacote `python3-venv`.

### `k8s-gitops` populado e pushado

O ArgoCD precisa encontrar `apps/argocd/argocd-config/` no `k8s-gitops`
para conseguir se auto-gerenciar. Antes de rodar o playbook, garantir
que o repositório está com a estrutura mínima:

```
k8s-gitops/
└── apps/
    ├── argocd/
    │   └── argocd-config/
    │       ├── ingress.yaml
    │       └── applicationset.yaml
    └── nexus/
        └── nexus-argocd/
            ├── deployment.yaml
            ├── ingress.yaml
            ├── namespace.yaml
            └── service.yaml
```

E commitado + pushado na branch `main`. Se algum manifest estiver faltando
ou divergir do bootstrap, o ArgoCD vai tentar reconciliar e o resultado
fica imprevisível.

---

## Execução

### 1. Rodar o playbook

```bash
cd ansible/
ansible-playbook install-argocd.yml
```

O playbook executa em sequência:

1. Cria/atualiza o virtualenv local `.venv/` com as dependências Python
   necessárias aos módulos Kubernetes do Ansible
2. Verifica acesso ao cluster via `kubeconfig`
3. Cria o namespace `argocd` (idempotente)
4. Adiciona o repositório Helm `argo`
5. Instala/atualiza o chart `argo/argo-cd:9.5.13` com
   `ansible/files/argocd-values.yaml`
6. **Remove o ApplicationSet legado `nexus`** se existir (v0.5.0)
7. Aplica o ApplicationSet genérico `homelab` a partir de
   `ansible/files/applicationset.yaml`
8. Aguarda a Application `argocd-config` aparecer (até 5 min)
9. Extrai a senha inicial do admin e grava em
   `ansible/files/argocd-credentials.yml` (gitignored)

> Tempo estimado: 3-5 minutos.

Caso queira rodar bootstrap completo do zero (k3s + ArgoCD em sequência):

```bash
ansible-playbook -i inventory/hosts.ini bootstrap-cluster.yml
```

### 2. Adicionar entrada no `/etc/hosts`

```bash
echo "<IP_DA_VM> argocd.homelab.local" | sudo tee -a /etc/hosts
echo "<IP_DA_VM> nexus.homelab.local" | sudo tee -a /etc/hosts
```

Se o IP da VM mudar por DHCP do libvirt, atualizar essas entradas. Um
sintoma típico é o playbook funcionar, mas `curl http://argocd.homelab.local`
falhar enquanto `kubectl get ingress -A` mostra o novo IP.

### 3. Recuperar senha do admin

```bash
cat ansible/files/argocd-credentials.yml
# argocd_url: http://argocd.homelab.local
# argocd_admin_username: admin
# argocd_admin_password: <senha-gerada>
```

> Após o primeiro login, altere a senha em **User Info → Update Password**.
> O Secret `argocd-initial-admin-secret` pode ser deletado depois:
>
> ```bash
> kubectl -n argocd delete secret argocd-initial-admin-secret
> ```

### 4. Acessar a UI

`http://argocd.homelab.local`

A interface mostra:

- ApplicationSet `homelab` ativo, monitorando `apps/*/*` do `k8s-gitops`
- Application `argocd-config` (auto-managed) — Synced, Healthy
- Application `nexus-argocd` — Synced, Healthy

---

## Como o ciclo GitOps funciona daqui em diante

Adicionar uma nova aplicação ao cluster vira uma operação puramente
declarativa no `k8s-gitops`:

```bash
cd k8s-gitops/
mkdir -p apps/<namespace>/<app>/
# adicionar manifests Kubernetes em apps/<namespace>/<app>/
git add -A
git commit -m "feat: nova aplicação <app>"
git push
```

O ApplicationSet `homelab` detecta o novo diretório em ~3 minutos (intervalo
de polling padrão) e cria automaticamente uma Application Kubernetes:

- `name`: o último segmento do path (`<app>`)
- `destination.namespace`: o segundo segmento (`<namespace>`)
- `source.path`: o path completo
- Sync policy: automated + prune + selfHeal + CreateNamespace

Para acelerar a descoberta, forçar refresh manual via CLI:

```bash
argocd appset get homelab --refresh
```

---

## Instalar a CLI do ArgoCD (opcional)

A CLI é útil para inspecionar o estado das aplicações e forçar syncs sem
precisar acessar a UI.

```bash
sudo curl -sSL -o /usr/local/bin/argocd \
  https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

sudo chmod +x /usr/local/bin/argocd

argocd version --client
```

Autenticar (usando a senha de `ansible/files/argocd-credentials.yml`):

```bash
argocd login argocd.homelab.local \
  --username admin \
  --password "$(yq '.argocd_admin_password' ansible/files/argocd-credentials.yml)" \
  --insecure
```

Comandos úteis:

```bash
argocd app list
argocd app get nexus-argocd
argocd app sync nexus-argocd          # forçar sync manual
argocd appset get homelab             # status do ApplicationSet
argocd appset get homelab --refresh   # forçar descoberta de novos apps
```

---

## Validação

```bash
bash scripts/validate-gitops.sh
```

O script executa 8 verificações:

| # | Teste | O que valida |
|---|-------|-------------|
| 1 | Pods argocd Running | ArgoCD operacional |
| 2 | ApplicationSet homelab existe | Genérico ativo |
| 3 | Application nexus-argocd Synced | Sincronizada do k8s-gitops |
| 4 | Application argocd-config Synced + Healthy | Auto-management ativo |
| 5 | Application nexus-argocd Healthy | Workload reconciliado com sucesso |
| 6 | Pod nexus-argocd Running | Aplicação deployada |
| 7 | Ingress nexus-argocd acessível | Rota HTTP da aplicação |
| 8 | Ingress ArgoCD acessível | Rota HTTP do ArgoCD |

Todos os 8 testes passando = milestone `v0.5.3` concluído.

---

## Atualizar o ArgoCD

Para fazer upgrade de versão:

```bash
# Editar ansible/install-argocd.yml — alterar argocd_chart_version
ansible-playbook install-argocd.yml
```

O Helm faz upgrade in-place — sem downtime significativo dos componentes
do ArgoCD em si. As Applications continuam sendo reconciliadas durante
o upgrade.

---

## Taguear o milestone

```bash
# No repositório k8s-homelab
git add -A
git commit -m "refactor(gitops): bootstrap do ArgoCD via Ansible"

git tag -a v0.5.3 -m "argocd-via-ansible: bootstrap reproduzível, manifests auto-managed via k8s-gitops"
git push origin main --tags

# No repositório k8s-gitops
git add -A
git commit -m "feat: argocd-config auto-managed em apps/argocd/"

git tag -a v1.1.0 -m "argocd-config: ingress e applicationset auto-managed"
git push origin main --tags
```

---

## Desinstalar

```bash
# Remover o ApplicationSet (ArgoCD vai deletar todas as Applications geradas
# e seus recursos no cluster)
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml \
  -n argocd \
  delete applicationset homelab

# Remover o release Helm
helm uninstall argocd \
  --kubeconfig $HOME/.kube/k8s-homelab.yaml \
  --namespace argocd

# Remover o namespace
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml delete namespace argocd
```

> Deletar o ApplicationSet **antes** de desinstalar o ArgoCD garante que
> as Applications e seus recursos gerenciados sejam removidos de forma
> limpa. Se o release Helm for deletado primeiro, os recursos permanecem
> órfãos no cluster.
