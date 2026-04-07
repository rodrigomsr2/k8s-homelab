---
name: project-organization
description: |
  Define onde cada tipo de conhecimento vive neste repositório.
  Use esta skill sempre que o usuário perguntar onde criar um arquivo novo,
  como documentar uma decisão, onde registrar um problema encontrado,
  como estruturar um guia de instalação, ou quando houver dúvida sobre
  onde determinado conteúdo deve viver.
---

# Skill — Organização do Projeto

## Princípio central

Conhecimento tem naturezas diferentes. Cada natureza tem um lugar certo.
Misturar naturezas no mesmo arquivo é a principal causa de documentação que ninguém lê.

| Natureza | Pergunta que responde | Onde vive |
|----------|-----------------------|-----------|
| Decisões arquiteturais | Por que foi feito assim? O que foi descartado? | `docs/adr/` |
| Guias de instalação | Como subo X do zero, em ordem? | `docs/guides/<tema>.md` |
| Procedimentos operacionais e troubleshooting | Como opero X? O que pode dar errado? | `docs/runbook/<tema>.md` |
| Visão geral e onboarding | O que é o projeto? Como rodo? | `README.md` |
| Índice de navegação para IA | Onde está cada tipo de conhecimento? | `.claude/CLAUDE.md` |
| Informações locais e pessoais | IPs, paths, credenciais locais | `CLAUDE.local.md` ← não versionar |
| Histórico de mudanças por versão | O que mudou em cada tag? | `CHANGELOG.md` |

A diferença entre `guides/` e `runbook/`: um guia é lido uma vez, do início ao fim, para instalar algo do zero. Um runbook é consultado pontualmente, quando você precisa operar ou corrigir algo que já está rodando. A cronologia do projeto vive no git — em commits e tags. Não criar pastas ou arquivos para representar ordem de execução.

---

## Estrutura canônica

```
k8s-homelab/
├── README.md                        # Visão geral, stack, início rápido, links
├── CHANGELOG.md                     # Histórico de mudanças por versão (semver)
├── CLAUDE.local.md                  # Dados locais — NÃO versionar (.gitignore)
│
├── .claude/
│   ├── CLAUDE.md                    # Índice de navegação para IA — só ponteiros
│   └── skills/
│       ├── semver.md                # Como versionar e taguear o projeto
│       └── project-organization.md # Este arquivo
│
├── terraform/                       # IaC — provisionamento da VM
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── cloud-init/
│
├── scripts/                         # Scripts de instalação e validação
│   └── validate-<milestone>.sh      # Um script por milestone
│
└── docs/
    ├── adr/                         # Decisões arquiteturais
    │   └── ADR-NNN-titulo.md
    ├── guides/                      # Instalação do zero, leitura sequencial
    │   └── <tema>.md
    └── runbook/                     # Operação e troubleshooting, consulta pontual
        └── <tema>.md
```

---

## Regras de ouro

### 1. Zero duplicação
Cada informação existe em exatamente um lugar. `README.md` e `CLAUDE.md` não duplicam conteúdo — o `CLAUDE.md` é índice, o `README.md` é conteúdo.

### 2. ADRs com alternativas rejeitadas
O valor de um ADR está no que foi **descartado** e por quê. Sem essa seção, o ADR é só um registro — não um guia para não repetir os mesmos erros.

### 3. Runbook = procedimento + troubleshooting juntos por tema
Não separar "como instalar" de "problemas encontrados" em arquivos diferentes. Se o tema é Kubernetes, tudo sobre Kubernetes vai em `docs/runbook/kubernetes.md`: instalação, problemas, soluções, gotchas.

### 4. Scripts nomeados por milestone
Cada milestone tem seu script de validação: `validate-vm.sh`, `validate-k8s.sh`, etc. O script é o critério objetivo de que o milestone está concluído.

### 5. Informações locais nunca versionadas
IPs de VM, paths de máquina, credenciais de desenvolvimento — tudo em `CLAUDE.local.md`, que está no `.gitignore`.

### 6. Cronologia no git, não em pastas
Nunca criar `docs/fase-1/`, `v1/`, `old/` ou similares. O git já guarda o histórico. Para marcar estados estáveis, usar tags — ver skill `semver.md`.

---

## Templates

### ADR

```markdown
# ADR-NNN — Título da decisão

**Status:** Aceito | Deprecado | Substituído por ADR-NNN
**Data:** YYYY-MM-DD

## Contexto
Qual problema estava sendo resolvido.

## Decisão
O que foi escolhido e como funciona.

## Consequências aceitas
Trade-offs reais aceitos com essa decisão.

## Alternativas rejeitadas
O que foi considerado e por que foi descartado. (Seção mais valiosa do ADR.)
```

### Entrada de problema em runbook

```markdown
## N. Título do problema

### Sintoma
O que aparece no terminal/log. Incluir mensagem de erro exata.

### Causa
Por que acontece.

### Solução
Comandos exatos para resolver.

### Lição
Generalização para evitar o problema no futuro.
```
