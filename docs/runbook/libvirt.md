# Runbook — libvirt / KVM

Operação, comandos úteis e troubleshooting do KVM e libvirt.

---

## Comandos do dia a dia

```bash
# Listar VMs
virsh list --all

# Ligar / desligar VM
virsh start k8s-node-01
virsh shutdown k8s-node-01
virsh destroy k8s-node-01   # força desligamento (equivalente a puxar o cabo)

# Ver console da VM (sair: Ctrl+])
sudo virsh console k8s-node-01

# Ver IP da VM
virsh domifaddr k8s-node-01
sudo virsh net-dhcp-leases default
```

### Rede

```bash
# Ver status da rede default
virsh net-list --all

# Ativar rede default
sudo virsh net-start default
sudo virsh net-autostart default

# Ver zonas do firewalld
sudo firewall-cmd --get-zones
```

### Storage

```bash
# Listar volumes do pool default
virsh vol-list default

# Ver arquivos físicos
ls -lh /var/lib/libvirt/images/
```

---

## Problemas conhecidos

### 1. Rede default inativa após instalação — zona libvirt não carregada no firewalld

**Sintoma**
```
error: Failed to start network default
error: internal error: firewalld is set to use the nftables backend,
but the required firewalld 'libvirt' zone is missing.
```

**Causa**
Após a instalação do libvirt, a zona `libvirt` é criada no firewalld em nível
permanente mas não é carregada no runtime imediatamente. Sem ela, o libvirt
não consegue configurar as regras de rede necessárias para a rede NAT default.

**Solução**
```bash
sudo firewall-cmd --reload
sudo systemctl restart libvirtd
sudo virsh net-start default
sudo virsh net-list --all
# "default" deve aparecer como "active"
```

**Lição**
Sempre verificar o status da rede default antes do primeiro `terraform apply`.
Se estiver inativa, recarregar o firewalld e reiniciar o libvirtd antes de
tentar ativá-la — não tentar forçar sem esse passo.

---

### 2. Terraform falha com `permission denied` no socket do libvirt

**Sintoma**
```
Error: Unable to Connect to Libvirt
URI: qemu:///system
Error: failed to dial libvirt: dial unix /var/run/libvirt/libvirt-sock:
connect: permission denied
```

**Causa**
O usuário foi adicionado ao grupo `libvirt` mas a sessão atual do terminal
foi aberta antes disso — ela não enxerga o grupo ainda. O `newgrp libvirt`
que aplicamos durante a instalação só vale para aquele shell específico.
Qualquer terminal novo aberto depois, ou após um reboot, pode não ter o grupo
ativo até que o usuário faça logout/login completo.

**Solução**
```bash
# Verificar se o grupo está ativo na sessão atual
groups
# Se "libvirt" não aparecer:
newgrp libvirt

# Confirmar que o Terraform consegue conectar
virsh --connect qemu:///system net-list --all
```

Para não precisar do `newgrp` toda vez, fazer logout e login completo — ou
reiniciar o sistema — após adicionar o usuário ao grupo.

**Lição**
`usermod -aG` modifica o `/etc/group` mas não afeta sessões já abertas.
O grupo só é carregado automaticamente em sessões iniciadas após a mudança.
`newgrp` é um atalho para a sessão atual, não uma solução permanente.

---

### 3. Pool `default` não encontrado — pool não criado durante instalação do libvirt

**Sintoma**
```
error: failed to get pool 'default'
error: Storage pool not found: no storage pool with matching name 'default'
```

**Causa**
O pacote `libvirt-daemon-system` no Ubuntu 24.04 não cria o pool `default`
automaticamente durante a instalação. O pool é o local de armazenamento
gerenciado pelo libvirt onde ficam os volumes das VMs — sem ele, o Terraform
não consegue criar discos.

**Solução**
```bash
sudo virsh pool-define-as default dir --target /var/lib/libvirt/images
sudo virsh pool-build default
sudo virsh pool-start default
sudo virsh pool-autostart default

# Verificar
sudo virsh pool-list --all
# "default" deve aparecer como "active"
```

**Lição**
Não assumir que o pool `default` existe após instalar o libvirt. Verificar
com `virsh pool-list --all` antes do primeiro `terraform apply` — junto com
a verificação da rede default.

---

### 4. VM não inicia — AppArmor bloqueando acesso ao disco

**Sintoma**
```
error: Failed to start domain 'k8s-node-01'
error: internal error: process exited while connecting to monitor:
qemu-system-x86_64: -blockdev {"driver":"file","filename":"/var/lib/libvirt/images/k8s-node-01-disk.qcow2",...}:
Could not open '/var/lib/libvirt/images/k8s-node-01-disk.qcow2': Permission denied
```

O erro parece ser de permissão de arquivo, mas verificar dono, grupo e permissões
do arquivo e do diretório não resolve — tudo está correto no nível Unix.

**Causa**
O AppArmor gera um perfil de segurança específico para cada VM em
`/etc/apparmor.d/libvirt/`. Esse perfil inclui a abstraction `libvirt-qemu`,
que não tem uma regra explícita para `/var/lib/libvirt/images/`. O diretório
de extensões locais `libvirt-qemu.d/` não é criado automaticamente no Ubuntu
24.04 — sem ele, o AppArmor bloqueia o QEMU de acessar os arquivos de disco,
mesmo que as permissões Unix estejam corretas.

Para confirmar que é AppArmor e não permissão Unix, instalar o `auditd` e
verificar o `subj` do processo que tenta abrir o arquivo:
```bash
sudo apt install -y auditd
sudo auditctl -w /var/lib/libvirt/images/ -p rwa -k qemu_disk
# tentar iniciar a VM, depois:
sudo ausearch -k qemu_disk | grep "subj=libvirt-"
# se aparecer subj=libvirt-<uuid>, é AppArmor
```

**Solução**
Criar a extensão local da abstraction `libvirt-qemu` com permissão explícita
para o diretório de imagens:

```bash
sudo mkdir -p /etc/apparmor.d/abstractions/libvirt-qemu.d

sudo tee /etc/apparmor.d/abstractions/libvirt-qemu.d/images << 'EOF'
/var/lib/libvirt/images/** rwk,
EOF

sudo apparmor_parser -r /etc/apparmor.d/libvirt/libvirt-<uuid-da-vm>
sudo systemctl restart libvirtd
virsh start k8s-node-01
```

Para descobrir o UUID da VM:
```bash
sudo ls /etc/apparmor.d/libvirt/
# ou
virsh domuuid k8s-node-01
```

**Lição**
Erros de `Permission denied` no libvirt nem sempre são sobre permissões Unix.
O AppArmor age como uma camada acima e pode bloquear acesso mesmo que o
arquivo tenha `chmod 777`. Quando permissões Unix estão corretas e o erro
persiste, investigar o AppArmor com `auditd`.

---

### 5. VM inicia mas trava — CPU em 0%, sem IP, console sem output

**Sintoma**
A VM aparece como `running` no `virsh list`, mas:
- `virsh domifaddr` não retorna IP
- `sudo virsh console` conecta mas não mostra nada
- `ps aux | grep qemu` mostra o processo com CPU em 0%
- `sudo virsh qemu-monitor-command k8s-node-01 --hmp "info status"` retorna `VM status: running`

**Causa**
O Terraform não especificou o tipo do driver no bloco `disk` do `libvirt_domain`.
Sem essa informação, o libvirt gera o XML da VM com `driver name='qemu'` sem
o atributo `type`, e o QEMU assume `raw`. O arquivo de disco é `qcow2` — ao
ser lido como `raw`, o QEMU não consegue interpretar a estrutura do formato e
a VM trava silenciosamente na inicialização.

Confirmar inspecionando o XML gerado:
```bash
sudo virsh dumpxml k8s-node-01 | grep -A2 "<driver"
# se aparecer apenas <driver name='qemu'/> sem type='qcow2', é esse o problema
```

**Solução**
Adicionar o driver explicitamente no bloco `disks` do `main.tf`:

```hcl
disks = [
  {
    driver = {
      name = "qemu"
      type = "qcow2"
    }
    source = { ... }
    target = { ... }
  }
]
```

Após corrigir o `main.tf`, aplicar via `terraform destroy && terraform apply`.

Alternativamente, corrigir temporariamente via `virsh edit` sem recriar a VM:
```bash
sudo virsh destroy k8s-node-01
sudo virsh edit k8s-node-01
# substituir <driver name='qemu'/> por <driver name='qemu' type='qcow2'/>
virsh start k8s-node-01
```

**Lição**
No provider `dmacvicar/libvirt` v0.9.x, o tipo do driver de disco não é
inferido automaticamente a partir do formato do volume — precisa ser declarado
explicitamente no `libvirt_domain`. Omitir o `type` resulta em `raw` implícito.
