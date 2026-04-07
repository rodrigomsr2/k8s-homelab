# ADR-002 — k3s como distribuição Kubernetes

**Status:** Aceito  
**Data:** 2025-01

---

## Contexto

O cluster Kubernetes vai rodar numa única VM com 8 GB de RAM. Precisamos de
uma distribuição que seja minimalista o suficiente para esse ambiente, mas
que exponha os conceitos reais do Kubernetes sem abstrações excessivas.
O objetivo é estudo, não produção.

---

## Decisão

Usar **k3s** (Rancher/SUSE) como distribuição Kubernetes.

k3s é uma distribuição certificada pela CNCF que empacota todos os componentes
do control plane num único binário de ~70 MB. Remove dependências externas
(etcd pode ser substituído por SQLite em clusters single-node), mas mantém
total compatibilidade com a API do Kubernetes. Ideal para single-node,
edge e ambientes com recurso limitado.

---

## Consequências aceitas

- etcd substituído por SQLite no single-node — não representa um cluster
  multi-node real, mas isso é aceitável para fins de estudo
- Alguns componentes opcionais do k8s upstream não vêm incluídos por padrão
  (ex: cloud-controller-manager) — irrelevante para o escopo do projeto
- A instalação é via script curl, não via package manager — aceitável pois
  será documentada e reproduzível

---

## Alternativas rejeitadas

**kubeadm**
A forma "oficial" de bootstrapar um cluster Kubernetes. Mais próximo do que
se faz em produção, mas requer configuração manual de vários componentes
(CRI, CNI, etcd) que aumentam a complexidade sem agregar valor educacional
nesta fase. Reservado para estudo específico de administração de cluster.

**minikube**
Excelente para desenvolvimento local, mas roda Kubernetes dentro de um
container ou VM adicional. Adiciona uma camada de abstração que não faz
sentido quando já temos uma VM dedicada. Não representa bem um cluster real.

**kind (Kubernetes in Docker)**
Kubernetes dentro de containers Docker — ainda mais abstrato que minikube
para o propósito deste projeto. Útil para CI/CD, não para estudo de infra.

**microk8s**
Alternativa válida da Canonical, distribuída como snap. Escolhemos k3s pela
documentação mais ampla, comunidade maior e por ser mais comum em projetos
open source de homelab/edge.
