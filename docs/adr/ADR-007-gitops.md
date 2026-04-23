# ADR-007 — GitOps com ArgoCD

**Status:** Aceito  
**Data:** 2026-04-22

## Contexto

Com a stack de observabilidade e logs operacional (`v0.4.0`), o próximo
passo é introduzir GitOps — o modelo onde o cluster reconcilia seu estado
a partir de um repositório Git, sem intervenção manual via `kubectl apply`.

O objetivo do milestone `v0.5.0` é demonstrar o ciclo completo: um commit
no repositório de aplicação dispara o CI, que atualiza os manifests no
repositório GitOps, que o ArgoCD detecta e reconcilia no cluster.

A primeira aplicação gerenciada é `nexus-argocd`, uma aplicação
Java/Spring Boot com imagem publicada no GHCR. O repositório `nexus` é
um monorepo — novos microserviços serão adicionados ao namespace `nexus`
em curto espaço de tempo.

Cinco decisões independentes foram tomadas: qual ferramenta GitOps usar,
como organizar os repositórios, como registrar aplicações no ArgoCD, como
atualizar a tag da imagem no ciclo de CI/CD, e como estruturar os manifests
da aplicação.

---

## Decisões

### 1. ArgoCD instalado via Helm

ArgoCD é instalado via Helm chart oficial (`argo/argo-cd`), com um
`values.yaml` versionado no repositório que desabilita os componentes não
utilizados (`dex` e `notifications`). O chart garante instalações
reproduzíveis e upgrades declarativos — o mesmo `values.yaml` aplicado em
qualquer momento resulta no mesmo estado.

O ArgoCD monitora o repositório `k8s-gitops` e reconcilia automaticamente
o cluster quando detecta divergência entre o estado declarado no repositório
e o estado real do cluster. A UI web expõe o status de sincronização, o
histórico de deploys e o estado de cada recurso em tempo real.

**Alternativa rejeitada: `install.yaml` oficial com patches manuais.**
O manifest oficial instala todos os componentes incluindo `dex` e
`notifications`, que ficam ociosos consumindo recursos. Desabilitá-los
exigiria patches manuais pós-instalação — propenso a erro, não reproduzível
e inconsistente com a abordagem declarativa do restante do projeto.

**Alternativa rejeitada: Flux.** Flux implementa o mesmo modelo GitOps mas
opera exclusivamente via CRDs e CLI, sem UI própria. Para um ambiente de
portfólio onde a demonstração visual é relevante, a UI do ArgoCD tem mais
impacto imediato. Ambos são projetos graduados da CNCF; ArgoCD tem adoção
corporativa mais ampla e é mais frequentemente citado em vagas DevOps.

### 2. Três repositórios com responsabilidades separadas

O projeto adota três repositórios distintos:

| Repositório | Responsabilidade |
|-------------|-----------------|
| `nexus` | Código-fonte da aplicação, Dockerfile, workflow de CI |
| `k8s-gitops` | Manifests Kubernetes de todas as aplicações gerenciadas pelo ArgoCD |
| `k8s-homelab` | Infraestrutura: Terraform, Ansible, ArgoCD, stack de observabilidade |

O ArgoCD, instalado e configurado pelo `k8s-homelab`, monitora o
`k8s-gitops`. O `nexus` não tem conhecimento de Kubernetes — apenas publica
imagens e notifica o `k8s-gitops` de novas versões.

Essa separação reflete a prática GitOps estabelecida: Dev, GitOps e Infra
operam em repositórios distintos, com ciclos de release independentes.
Adicionar uma nova aplicação no futuro significa apenas um novo diretório
no `k8s-gitops`, sem tocar nos outros repositórios.

**Alternativa rejeitada: manifests no repositório `nexus`.** Rejeitada
porque acopla o ciclo de release da aplicação aos manifests Kubernetes —
um commit de feature e um commit de deploy ficam no mesmo histórico,
dificultando auditoria. O time de dev não deveria precisar entender
Kubernetes para fazer um deploy.

**Alternativa rejeitada: manifests em `k8s/apps/` dentro do
`k8s-homelab`.** Rejeitada porque mistura infraestrutura com configuração
de aplicação. O `k8s-homelab` gerencia o cluster — não as aplicações que
rodam nele.

### 3. ApplicationSet em vez de Application individual

O ArgoCD é configurado com um `ApplicationSet` usando o gerador de
diretórios, em vez de um objeto `Application` por serviço. O
`ApplicationSet` monitora o path `apps/nexus/*` no `k8s-gitops` e gera
automaticamente uma `Application` para cada subdiretório encontrado.

```
k8s-gitops/apps/nexus/
  nexus-argocd/    → Application gerada automaticamente
  novo-servico/    → Application gerada automaticamente
  outro-servico/   → Application gerada automaticamente
```

Adicionar um novo microserviço ao ambiente significa apenas criar o
diretório correspondente no `k8s-gitops` — sem nenhuma alteração na
configuração do ArgoCD.

**Alternativa rejeitada: objeto `Application` individual por serviço.**
Rejeitada porque exige criação manual de um novo objeto `Application` a
cada novo microserviço adicionado. Com múltiplos microserviços chegando
em curto espaço de tempo, isso se tornaria um overhead operacional
relevante e um ponto de esquecimento — o serviço deployado sem
`Application` correspondente ficaria fora do controle do ArgoCD.

### 4. GitHub Actions atualiza o manifest no k8s-gitops

O workflow de CI no `nexus` é responsável por:

1. Build da imagem Docker
2. Push para o GHCR com tag `sha-<commit>`
3. Commit no `k8s-gitops` atualizando o campo `image:` no manifest da aplicação

O ArgoCD detecta o novo commit no `k8s-gitops` e reconcilia o cluster.
O fluxo completo é auditável no histórico do workflow do GitHub Actions.

**Alternativa rejeitada: ArgoCD Image Updater.** Componente adicional do
ecossistema ArgoCD que monitora o registry e atualiza os manifests
automaticamente. Rejeitado porque adiciona complexidade ao cluster sem
benefício para o aprendizado — o fluxo fica distribuído entre o cluster e
o repositório, menos legível para quem revisa o projeto.

### 5. Manifests Kubernetes puros para a aplicação

Os manifests da aplicação `nexus-argocd` no `k8s-gitops` são YAML puros
(Deployment + Service + Ingress), sem Helm nem Kustomize. Para um único
ambiente e uma única aplicação de demonstração, a camada adicional de
templating não adiciona valor.

**Alternativa rejeitada: Helm chart próprio.** O benefício do Helm é
parametrizar valores para múltiplos ambientes. Com um ambiente único, é
boilerplate sem retorno.

**Alternativa rejeitada: Kustomize.** Overlays por ambiente não fazem
sentido com um ambiente único. Kustomize é um candidato natural para uma
evolução futura do projeto com múltiplos ambientes.

---

## Consequências aceitas

- O ArgoCD adiciona o namespace `argocd` ao cluster com 5 pods permanentes.
  `dex` e `notifications` são desabilitados via `values.yaml`. Em um cluster
  de 1 node, o impacto de recursos é aceitável para um ambiente de estudo.
- A UI do ArgoCD será exposta via Ingress Traefik, seguindo o padrão
  estabelecido no `v0.3.0` para Grafana e Prometheus.
- O repositório `k8s-gitops` precisa existir e ter manifests válidos antes
  da criação do `ApplicationSet` no ArgoCD.
- O `k8s-gitops` é público — o ArgoCD não precisa de credenciais para
  acessá-lo. Se se tornar privado no futuro, será necessário registrar
  credenciais no ArgoCD via Secret.
- O workflow de CI no `nexus` precisa de permissão de escrita no
  `k8s-gitops` — isso será configurado via GitHub Personal Access Token
  ou GitHub App armazenado como secret no repositório `nexus`.
- A aplicação expõe duas portas: `8080` (tráfego) e `8081` (actuator +
  micrometer). Os manifests incluirão anotações para scrape automático
  pelo Prometheus já operacional no cluster.
- A tag da imagem é gerenciada pelo CI — atualizações de imagem exigem
  um novo commit no `nexus`, que dispara o workflow e atualiza o
  `k8s-gitops`. Esse é o comportamento esperado em GitOps.