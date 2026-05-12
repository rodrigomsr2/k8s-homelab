# Runbook — GitOps (ArgoCD + Ansible)

---

## 1. Ansible sem rota para o IP da VM

### Sintoma

O bootstrap falha no `Gathering Facts`:

```text
Failed to connect to the host via ssh:
ssh: connect to host 192.168.122.86 port 22: No route to host
```

### Causa

O IP no `ansible/inventory/hosts.ini` estava antigo. A VM libvirt estava
rodando, mas o DHCP havia entregue outro endereço.

### Diagnóstico

```bash
virsh list --all
virsh net-dhcp-leases default
ansible -i ansible/inventory/hosts.ini k3s_nodes -m ping
```

### Solução

Atualizar `ansible/inventory/hosts.ini` com o IP atual da VM. Validar:

```bash
ansible -i ansible/inventory/hosts.ini k3s_nodes -m ping
```

### Lição

Em ambiente libvirt com DHCP, o inventário e o `/etc/hosts` são dependências
locais que podem ficar obsoletas. Se o IP mudar, revisar ambos.

---

## 2. `ansible_env.HOME` indefinido no play localhost

### Sintoma

O play `install-argocd.yml` falha antes de acessar o cluster:

```text
{{ ansible_env.HOME }}/.kube/k8s-homelab.yaml: 'ansible_env' is undefined
```

### Causa

O play de ArgoCD roda com `gather_facts: false`. Sem facts, `ansible_env`
não existe.

### Solução

Usar lookup de ambiente para resolver o `HOME` local:

```yaml
kubeconfig: "{{ lookup('env', 'HOME') }}/.kube/k8s-homelab.yaml"
```

### Lição

Em plays locais sem facts, preferir `lookup('env', 'HOME')` para paths do
usuário.

---

## 3. Módulos `kubernetes.core` sem biblioteca Python `kubernetes`

### Sintoma

O playbook acessa o cluster via `kubectl`, mas falha no primeiro módulo
`kubernetes.core.k8s`:

```text
Failed to import the required Python library (kubernetes)
```

Tentar instalar com `pip --user` pode falhar em distros recentes:

```text
error: externally-managed-environment
```

### Causa

Os módulos `kubernetes.core` executam no Python local do Ansible e precisam
das bibliotecas `kubernetes`, `PyYAML` e `jsonpatch`. O Python do sistema é
gerenciado pela distro e bloqueia instalações diretas via pip por PEP 668.

### Solução

O `ansible/install-argocd.yml` cria um virtualenv local em `.venv/`, instala
as dependências e usa esse Python no play principal:

```yaml
ansible_python_interpreter: "{{ local_venv_path }}/bin/python"
```

Pré-requisito: `python3 -m venv` precisa funcionar no host.

### Lição

Dependências Python de automação devem ficar isoladas do Python do sistema.
O playbook deve preparar o ambiente local antes de usar módulos que dependem
dessas bibliotecas.

---

## 4. Chart Helm fixado não encontrado

### Sintoma

O install do ArgoCD falha mesmo com versão válida:

```text
Error: chart "argo-cd" matching 9.5.13 not found in argo index
```

### Causa

Cache local do repositório Helm desatualizado.

### Solução

O task `kubernetes.core.helm` deve atualizar o índice antes do install:

```yaml
update_repo_cache: true
```

Diagnóstico manual:

```bash
helm repo update argo
helm search repo argo/argo-cd --versions | head
```

### Lição

Quando um chart está fixado por versão, o playbook precisa manter o cache
Helm atualizado para ser reproduzível em máquinas novas ou caches antigos.

---

## 5. `wait_timeout` inválido no módulo `k8s`

### Sintoma

O módulo `kubernetes.core.k8s` falha ao remover o ApplicationSet legado:

```text
argument 'wait_timeout' is of type <class 'str'> and we were unable to convert to int
```

### Causa

No módulo `k8s`, `wait_timeout` espera inteiro em segundos. O valor `2m` é
aceito por alguns módulos Helm, mas não por esse módulo.

### Solução

Usar segundos:

```yaml
wait_timeout: 120
```

### Lição

Mesmo dentro da mesma collection, formatos de timeout podem variar por
módulo. Conferir a documentação do módulo específico.

---

## 6. `validate-gitops.sh` referenciando nomes antigos

### Sintoma

O bootstrap aplica o ApplicationSet `homelab`, mas a validação procura
`applicationset nexus` ou aborta antes do resumo final.

### Causa

O script ainda refletia o estado v0.5.0, anterior à migração para
ApplicationSet genérico `homelab` e Application `argocd-config`.

### Solução

Atualizar a validação para:

- procurar `ApplicationSet homelab`
- validar `Application argocd-config` como `Synced` e `Healthy`
- tratar comandos que podem falhar com `|| true`, reportando falha sem
  abortar o script antes do resumo

### Lição

Scripts de validação fazem parte do contrato operacional. Quando o modelo
GitOps muda, atualizar o script junto com os manifests.

---

## 7. Application saudável no ArgoCD, mas pod em `ImagePullBackOff`

### Sintoma

O ArgoCD fica operacional, `nexus-argocd` aparece `Synced`, mas a saúde fica
`Progressing` e o pod não sobe:

```text
Failed to pull image "ghcr.io/rodrigomsr2/nexus-argocd:sha-sha-5c732ad":
not found
```

### Causa

O manifesto em `k8s-gitops` apontava para uma tag inexistente no GHCR. A tag
correta existente era `sha-5c732ad`.

### Diagnóstico

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml describe pod -n nexus -l app=nexus-argocd
docker manifest inspect ghcr.io/rodrigomsr2/nexus-argocd:sha-5c732ad
```

### Solução

Corrigir o manifesto no repositório `k8s-gitops`, commitar e fazer push para
a branch monitorada pelo ArgoCD:

```yaml
image: ghcr.io/rodrigomsr2/nexus-argocd:sha-5c732ad
```

### Lição

`Synced` significa que o cluster bate com o Git, não que o workload está
funcional. Para validar disponibilidade, conferir também `Health`, pods e
eventos do kubelet.

---

## 8. Ingress falha por `/etc/hosts` com IP antigo

### Sintoma

O Ingress existe e aponta para o IP atual da VM, mas o acesso pelo host local
falha:

```bash
curl http://argocd.homelab.local
```

### Causa

`/etc/hosts` ainda apontava os domínios `*.homelab.local` para o IP antigo
da VM.

### Diagnóstico

```bash
getent hosts argocd.homelab.local nexus.homelab.local
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml get ingress -A
curl --resolve argocd.homelab.local:80:<IP_DA_VM> http://argocd.homelab.local
```

### Solução

Atualizar as entradas locais:

```bash
sudo sed -i 's/192\.168\.122\.86/192.168.122.9/g' /etc/hosts
```

Ou editar manualmente para o IP atual mostrado por:

```bash
virsh net-dhcp-leases default
```

### Lição

Ingress e DNS local são camadas separadas. Se `curl --resolve` funciona e o
hostname normal não, o problema está na resolução local, não no cluster.
