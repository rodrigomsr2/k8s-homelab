# ADR-004 — Ansible como ferramenta de configuration management

**Status:** Aceito  
**Data:** 2026-04-07

## Contexto

Com a VM provisionada pelo Terraform (`v0.1.0`), o próximo passo é instalar e configurar o k3s dentro dela. O Terraform entrega a infraestrutura — a VM existe, tem rede, tem SSH. Mas a instalação de software dentro da VM está fora do escopo do Terraform.

Três abordagens foram consideradas para preencher essa lacuna.

## Decisão

Ansible, executado a partir da máquina host contra a VM via SSH, com um playbook próprio escrito para este projeto.

O inventário aponta para o IP da VM (definido em `CLAUDE.local.md`). A chave SSH gerada pelo Terraform é usada para autenticação. O playbook cobre: instalação do k3s, configuração do `kubeconfig` na VM, e cópia do `kubeconfig` para a máquina host.

## Consequências aceitas

- Ansible precisa estar instalado na máquina host (não está na VM)
- Um novo diretório `ansible/` entra na raiz do repositório
- A instalação do Ansible em si não é gerenciada por código — é um pré-requisito manual documentado no guia

## Alternativas rejeitadas

**Shell script via SSH**
Funciona para uma instalação única, mas é frágil: não é idempotente, não tem tratamento de erro estruturado, e não escala quando o ambiente crescer para múltiplos nós. Difícil de ler e auditar em um portfólio.

**Terraform provisioners**
O próprio HashiCorp os classifica como "último recurso". O problema central é que provisioners executam código arbitrário que o Terraform não rastreia no estado — se o provisionamento falhar no meio, o `.tfstate` fica inconsistente sem forma de recuperação declarativa. Mistura responsabilidades que devem estar separadas: Terraform provisiona infraestrutura, Ansible configura software.

**cloud-init**
Já utilizado para configuração inicial da VM (swap off, módulos de kernel). cloud-init roda uma única vez na criação da VM e não é adequado para instalação de software que depende da VM já estar completamente inicializada e acessível via rede. Não é idempotente por design.

**k3s-ansible (playbook oficial)**
O projeto k3s mantém um repositório Ansible oficial. Foi descartado porque o objetivo deste ambiente é demonstrar compreensão de cada camada — um playbook externo oculta as decisões. Escrever o próprio playbook é mais valioso para portfólio e aprendizado.
