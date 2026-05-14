# ADR-012 — MongoDB standalone via Ansible

## Status

Aceita — `v0.6.0`

## Contexto

O `v0.5.5` deixou a rede `homelab` pronta, com faixa de IPs estáticos
reservada (`.10–.49`) e convenção de alocação documentada na ADR-011.

O roadmap aponta para `v0.8.0` introduzir microserviços no k8s que
consomem MongoDB e Kafka. Para que isso seja possível, os dois serviços
precisam existir como dependências externas antes — daí o `v0.6.0`
(MongoDB) e o `v0.7.0` (Kafka).

A filosofia explícita do projeto é "sentir os problemas na prática
antes de adicionar complexidade preventiva". Isso significa que, neste
milestone, escolhemos a configuração mais simples possível e cada
limitação será revisitada quando virar dor real.

## Decisão

Instalar **MongoDB 8.0 Community** em uma VM dedicada `mongodb-01`,
provisionada pelo módulo `terraform/modules/vm` e configurada via
playbook Ansible (`ansible/install-mongodb.yml`).

**Configuração:**

| Aspecto | Valor |
|---|---|
| Modo | Standalone (sem replica set) |
| Autenticação | Desabilitada |
| Bind | `0.0.0.0` na interface da rede `homelab` |
| Porta | `27017` (default) |
| Storage | `/var/lib/mongodb` no disco principal da VM (sem volume separado) |
| Sizing | 4 GiB RAM, 2 vCPU, 20 GiB disco |
| IP | `192.168.123.20` (estático, via cloud-init) |

A configuração do `/etc/mongod.conf` é sobrescrita inteiramente pelo
playbook — qualquer ajuste manual será revertido na próxima execução.

## Consequências aceitas

- **Sem transactions multi-documento** — feature requer replica set.
  Aplicações que precisarem terão que ser desenhadas em torno disso ou
  motivar a migração futura.
- **Sem change streams** — também requer replica set. Padrões reativos
  (microserviço escutando mudanças no banco) não são possíveis neste
  milestone.
- **Sem autenticação significa acesso irrestrito na rede `homelab`** —
  qualquer host com IP em `192.168.123.0/24` pode ler, escrever ou
  destruir qualquer dado. Mitigado pelo isolamento da rede (NAT, sem
  bridge para a LAN física). Aceitável enquanto o homelab estiver
  isolado.
- **Single point of failure** — se a VM cai, o banco cai. Aplicações
  consumidoras precisarão lidar com indisponibilidade.
- **Volume único compartilhado com o SO** — `/var/lib/mongodb` vive no
  disco principal de 20 GiB. Quando o disco encher (logs, dados, SO),
  é dor real e será resolvida quando acontecer.
- **Idempotência do playbook** — sobrescrever `/etc/mongod.conf` a cada
  run garante config previsível, mas impede tuning manual entre rodadas
  do Ansible. Toda mudança vai pelo playbook.

## Alternativas rejeitadas

### Replica set de 1 nó (PSA degenerado)

Replica set com um único `mongod` (sem secondaries, sem arbiter).
Habilita transactions multi-documento e change streams mantendo
infraestrutura mínima de uma VM. **Rejeitada** porque adiciona
complexidade conceitual (initiate, oplog, configuração de hostname
resolvível) sem que haja consumidor pedindo essas features. A migração
de standalone → RS é documentada e factível quando a dor aparecer.

### Replica set de 3 nós

Três VMs (`mongodb-01`, `-02`, `-03`) em `.20`, `.21`, `.22`. HA real,
eleição de primary, failover automático. **Rejeitada** — 3x o custo de
infraestrutura sem que se saiba ainda se HA importa neste contexto.
Quando o impacto de "Mongo caiu" for sentido, vira motivação concreta
para migrar.

### Autenticação habilitada desde já

Criar usuário admin durante o playbook, persistir credencial em
`ansible/files/mongodb-credentials.yml` (gitignored), forçar
`--auth` no `mongod`. **Rejeitada** — a complexidade da auth (rotação,
distribuição de credenciais, separação de roles) só faz sentido sentir
quando há consumidor real. Postergar até o `v0.8.0` (microserviços) ou
quando outro motivo concreto aparecer.

### MongoDB 7.0 LTS

Versão LTS atual, mais conservadora, com janela de suporte mais longa.
**Rejeitada** sem motivo concreto para ficar atrás no homelab de estudo.
A 8.0 é a versão atual da MongoDB Inc., e usar a versão recente expõe
o operador a features e mudanças mais relevantes para o mercado.

### MongoDB no Kubernetes via Operator

Deploy do MongoDB Community Operator ou Percona Operator dentro do
cluster k3s, sem VM dedicada. **Rejeitada** para este milestone porque
queremos primeiro experimentar a diferença entre "banco em VM
dedicada" e "banco como workload no cluster". A versão em VM é
deliberadamente o ponto de partida — futura migração para o k8s pode
virar milestone próprio.

## Referências

- ADR-011 — rede `homelab` (precondição: VM com IP estático).
- `terraform/mongodb.tf` — provisionamento da VM.
- `ansible/install-mongodb.yml` — instalação e configuração.
- `docs/guides/mongodb.md` — guia operacional do milestone.
- `docs/runbook/mongodb.md` — troubleshooting (preenchido conforme
  problemas reais aparecerem).
- `scripts/validate-mongodb.sh` — validação automatizada do estado
  esperado ao final do milestone.
