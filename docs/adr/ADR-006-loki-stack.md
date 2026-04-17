# ADR-006 — Stack de logs: instalação e configuração

**Data:** 2026-04-17
**Status:** Aceito

---

## Contexto

O milestone `v0.4.0` adiciona coleta e consulta de logs ao ambiente.
A stack de métricas (`v0.3.0`) já está operacional com Prometheus + Grafana
no namespace `monitoring`. A decisão envolve quatro escolhas independentes:
como instalar, qual agente coletor usar, qual modo de deploy do Loki, e
onde armazenar os dados.

---

## Decisões

### 1. Helm em vez de manifests Kubernetes puros

Os milestones anteriores usaram manifests puros para demonstrar conhecimento
direto de recursos Kubernetes. O `v0.4.0` introduz o Helm deliberadamente
para demonstrar também o uso de package manager — uma habilidade distinta
e relevante no mercado, presente em praticamente qualquer ambiente
Kubernetes real.

O Loki também se beneficia do Helm objetivamente: sua superfície de
configuração é maior que a dos componentes anteriores, e o chart oficial
gerencia storage backend, schema, replication e subcharts opcionais de
forma mais clara do que manifests individuais.

**Alternativa rejeitada:** manifests puros, como nos milestones anteriores.
Rejeitado porque o padrão de manifests já foi consolidado no `v0.3.0` —
repetir a mesma abordagem não acrescenta ao portfólio.

---

### 2. Promtail como agente coletor

Promtail é o agente nativo do ecossistema Loki: faz uma coisa só (coletar
logs e enviar para o Loki), é bem documentado e ainda domina em ambientes
Kubernetes que não usam Grafana Cloud.

O chart `grafana/promtail` está marcado como deprecated desde 2024 — a
Grafana descontinuou o chart em favor do Alloy. O Promtail em si ainda
funciona e é amplamente usado em produção, mas novos projetos devem
considerar o Alloy.

**Alternativa rejeitada:** Alloy, o substituto moderno lançado pela Grafana
em 2024. Rejeitado porque usa uma linguagem de configuração própria
(Alloy syntax) com documentação ainda amadurecendo, e consolida métricas,
logs e traces num único agente — complexidade desnecessária para um ambiente
onde Prometheus já cobre métricas. Migrar para Alloy é um exercício válido
após `v1.0.0`.

---

### 3. Modo de deploy SingleBinary

O chart oficial do Loki suporta três modos: `SingleBinary` (único pod),
`SimpleScalable` (separação read/write/backend) e `Distributed` (cada
componente isolado). Com um cluster de 1 node e carga mínima,
`SingleBinary` é o único modo que faz sentido.

**Alternativa rejeitada:** `SimpleScalable`. Rejeitado porque exige no
mínimo 3 pods e um `replication_factor` maior, sem benefício real num
ambiente de 1 node.

---

### 4. Filesystem como storage backend

O Loki foi projetado para usar object storage (S3, GCS, MinIO) em produção.
No homelab, usar o disco local da VM via `type: filesystem` elimina a
dependência de um serviço externo ou de um subchart adicional (MinIO),
mantendo o ambiente simples e autocontido.

**Alternativa rejeitada:** MinIO, que o próprio chart oferece como subchart.
Rejeitado porque adiciona um componente extra sem benefício para o objetivo
do milestone — aprender o fluxo de coleta e consulta de logs.

---

## Consequências

- O Loki não é adequado para produção nessa configuração: filesystem não
  oferece redundância e `replication_factor: 1` não tolera falhas.
- Os dados de log ficam no PVC do pod — se o PVC for deletado, os logs
  se perdem. Aceitável para um ambiente de estudo.
- A migração para object storage no futuro exige reconfiguração do schema
  e potencial perda dos dados históricos.
- Multi-tenancy está habilitado (`auth_enabled: true`) com tenant `homelab`.
  Todas as requisições ao Loki — Promtail, Grafana e ferramentas de
  diagnóstico — precisam incluir o header `X-Scope-OrgID: homelab`.
- O pipeline do Promtail inclui um estágio multiline para agrupar
  stacktraces Java em uma única entrada de log. A regex ancora no
  timestamp + nível (`TRACE|DEBUG|INFO|WARN|ERROR|FATAL`) para evitar
  falsos positivos no corpo das exceptions.
- O chart `grafana/promtail` está deprecated — a migração para Alloy é
  um item pendente para após `v1.0.0`.
