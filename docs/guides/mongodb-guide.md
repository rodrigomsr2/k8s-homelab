# MongoDB — VM dedicada com instância standalone

Guia para provisionar a VM `mongodb-01` e instalar MongoDB 8.0 Community
em modo standalone. Ao final, o ambiente estará no estado `v0.6.0` —
banco acessível via porta 27017 na rede `homelab`, sem autenticação,
pronto para consumidores futuros.

Pré-requisito: milestone `v0.5.5` concluído — rede `homelab` gerenciada
pelo Terraform, com faixa de IPs estáticos reservada.

---

## Pré-requisitos

### No host físico

- `terraform`, `ansible` e `mongosh` instalados
- Chave SSH do projeto (`.ssh/homelab_ed25519`) presente no root do repo
- Repositório oficial do MongoDB adicionado (para o `mongosh`):

```bash
# Importar chave GPG oficial
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc \
  | sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor

# Adicionar repo (Ubuntu 24.04 noble)
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" \
  | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list

sudo apt update
sudo apt install -y mongodb-mongosh
mongosh --version
```

> O host instala apenas o cliente (`mongodb-mongosh`), não o servidor.
> O servidor roda exclusivamente na VM dedicada.

---

## Provisionar a VM

A configuração da VM está em `terraform/mongodb.tf` — reusa o módulo
`modules/vm/` com sizing 4GB / 2vCPU / 20GB e IP estático `192.168.123.20`.

```bash
cd terraform/
terraform init    # necessário quando um novo module é adicionado
terraform plan    # esperado: 4 resources to add em module.mongodb.*
terraform apply
```

Após o apply, conferir os outputs:

```bash
terraform output mongodb_vm_name
# "mongodb-01"
terraform output mongodb_vm_ip
# "192.168.123.20"
```

Validar acesso à VM:

```bash
ping -c 3 192.168.123.20
ssh -i .ssh/homelab_ed25519 devops@192.168.123.20 hostname
# esperado: mongodb-01

ssh -i .ssh/homelab_ed25519 devops@192.168.123.20 cat /tmp/cloud-init-complete
# esperado: cloud-init done
```

---

## Instalar e configurar o MongoDB

### 1. Atualizar o inventário Ansible

O `hosts.ini.example` já contém o grupo `[mongodb]`. Copiar para
`hosts.ini` (gitignored) e preencher com o caminho da chave SSH local:

```bash
# Se ainda não existe
cp ansible/inventory/hosts.ini.example ansible/inventory/hosts.ini

# Editar e preencher FILL_SSH_KEY_PATH
nano ansible/inventory/hosts.ini
```

Validar conectividade antes do playbook:

```bash
cd ansible/
ansible -i inventory/hosts.ini mongodb -m ping
```

Esperado:

```
mongodb-01 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### 2. Executar o playbook

```bash
ansible-playbook -i inventory/hosts.ini install-mongodb.yml
```

O playbook executa, em ordem:

1. Adiciona o repositório oficial MongoDB 8.0 com chave GPG verificada
2. Instala o meta-pacote `mongodb-org` (server + shell + tools)
3. Sobrescreve `/etc/mongod.conf` com a config do projeto (bindIp `0.0.0.0`, porta 27017, sem auth)
4. Habilita e inicia o serviço `mongod` no boot
5. Aguarda a porta 27017 responder

Tempo estimado: 1–3 minutos (depende do download do `mongodb-org`, ~150 MB).

> Em runs subsequentes do mesmo playbook, nada muda — todas as tasks
> são idempotentes. Mudar `/etc/mongod.conf` manualmente na VM e rodar
> o playbook novamente reverte a alteração.

---

## Validação

```bash
bash scripts/validate-mongodb.sh
```

O script executa 9 testes em 4 camadas:

| # | Camada | Teste |
|---|--------|-------|
| 1 | VM | VM responde a ping |
| 2 | VM | SSH funciona e hostname é `mongodb-01` |
| 3 | serviço | `mongod` está active |
| 4 | serviço | `mongod` está enabled |
| 5 | bind | `bindIp: 0.0.0.0` no `mongod.conf` |
| 6 | bind | porta 27017 aberta externamente |
| 7 | protocolo | `mongosh` disponível no host |
| 8 | protocolo | `db.runCommand({ping: 1}).ok == 1` |
| 9 | protocolo | insert + find + drop num database de teste |

Todos os 9 testes passando = milestone `v0.6.0` concluído.

---

## Operação básica

### Conectar via mongosh do host

```bash
mongosh --host 192.168.123.20
```

### Criar um database e inserir um documento

```javascript
use catalog
db.products.insertOne({sku: "ABC-123", price: 99.90})
db.products.find()
```

### Listar databases

```javascript
show dbs
```

### Sair

```javascript
exit
```

---

## Taguear o milestone

```bash
git add -A
git commit -m "feat: MongoDB 8.0 standalone via Ansible, VM dedicada na rede homelab"

git tag -a v0.6.0 -m "mongodb-deployed: MongoDB 8.0 standalone via Ansible, acessível na rede homelab"
git push origin main --tags
```

---

## Desinstalar

Para destruir apenas a VM do MongoDB (preservando o resto do ambiente):

```bash
cd terraform/
terraform destroy -target=module.mongodb
```

> O `destroy` apaga o volume da VM — todos os dados do MongoDB são
> perdidos. Não há backup automatizado neste milestone.
