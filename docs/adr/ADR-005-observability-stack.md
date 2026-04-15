# ADR-005 — Stack de observabilidade: deploy e configuração

**Status:** Aceito
**Data:** 2026-04-09

## Contexto

Com o cluster Kubernetes operacional (`v0.2.0`), o próximo milestone é a stack de observabilidade: Prometheus coletando métricas do cluster e Grafana visualizando dashboards. Várias decisões de deploy precisavam ser tomadas antes de escrever os manifests.

## Decisões

### 1. Dentro do cluster

Prometheus e Grafana rodam dentro do cluster Kubernetes, não na máquina host.

O objetivo do ambiente é monitorar o Kubernetes — faz sentido que as ferramentas de observabilidade usem os mesmos mecanismos que qualquer outra aplicação no cluster: Deployments, Services, Ingress. Rodar fora adicionaria complexidade de rede sem agregar aprendizado relevante.

### 2. Namespace dedicado

Todos os recursos de observabilidade vivem no namespace `monitoring`, separados dos pods do sistema (`kube-system`) e de futuras aplicações.

### 3. Manifests escritos à mão, sem Helm

Os manifests são escritos diretamente em YAML, sem uso de charts Helm ou operadores. O objetivo é consolidar o conhecimento da estrutura dos recursos Kubernetes — Deployments, Services, ConfigMaps, PersistentVolumeClaims, Ingress, RBAC, DaemonSets.

### 4. Acesso via Ingress por host

Grafana e Prometheus são expostos via recurso `Ingress` com roteamento por host, usando o Traefik já instalado pelo k3s como Ingress Controller:

- `grafana.homelab.local` → Service `grafana:3000`
- `prometheus.homelab.local` → Service `prometheus:9090`

O acesso por host requer entradas no `/etc/hosts` da máquina host. O Prometheus é exposto para facilitar debug e inspeção de targets de scrape.

### 5. Persistência via PersistentVolumeClaim

O Grafana usa um `PersistentVolumeClaim` referenciando a StorageClass `local-path`, provisionada automaticamente pelo `local-path-provisioner` do k3s. Isso garante que dashboards e configurações sobrevivam a reinicializações do pod.

O Prometheus não usa volume persistente neste milestone — métricas históricas são descartadas ao reiniciar o pod. Persistência do Prometheus pode ser adicionada em milestone futuro.

### 6. Descoberta de targets via anotações

O Prometheus descobre os targets de scrape via anotações nos pods, configuradas no `prometheus.yml`. É a abordagem mais simples e não requer CRDs.

A abordagem via `ServiceMonitor` (CRD do Prometheus Operator) será revisitada após o `v1.0.0`.

### 7. Node Exporter como DaemonSet

O Node Exporter é instalado como `DaemonSet` para garantir que um pod rode em cada node do cluster, coletando métricas de hardware do host — CPU, memória, disco e rede a nível de sistema operacional.

O pod é configurado com `hostNetwork: true`, `hostPID: true` e monta o sistema de arquivos raiz do host (`/`) e o diretório `/run/udev` para acesso completo às métricas de dispositivos. A descoberta pelo Prometheus é feita via anotações no próprio pod do DaemonSet.

### 8. Dashboard customizado para k3s/containerd

O dashboard Kubernetes cluster monitoring (ID 315 do Grafana Labs) foi importado e adaptado para compatibilidade com k3s e containerd. As seguintes correções foram aplicadas:

- Label `pod_name` substituído por `pod` (renomeado no Kubernetes 1.16)
- Filtro `name=~"^k8s_.*"` removido (específico para Docker, incompatível com containerd)
- Label `systemd_service_name` substituído por agregação por `namespace`
- Filtro `interface!="lo"` adicionado nas métricas de rede para excluir loopback
- Painéis do tipo `Graph (old)` migrados para `Time series` (componente moderno do Grafana 10)

O JSON do dashboard adaptado está versionado em `k8s/monitoring/dashboards/kubernetes-cluster-monitoring-315.json`.

O dashboard Node Exporter Full (ID 1860) foi importado sem modificações e não está versionado no repositório — pode ser importado diretamente pelo ID no Grafana.

## Consequências aceitas

- Entradas manuais no `/etc/hosts` da máquina host para resolver `grafana.homelab.local` e `prometheus.homelab.local`
- Métricas do Prometheus são perdidas ao reiniciar o pod
- Targets de scrape precisam ser atualizados manualmente no `prometheus.yml` quando novos serviços são adicionados
- Node Exporter requer privilégios elevados (`privileged: true`) para acessar métricas de hardware do host

## Alternativas rejeitadas

**Helm com kube-prometheus-stack**
Chart oficial que instala Prometheus, Grafana, Alertmanager, exporters e dashboards em um único comando. Descartado porque oculta a estrutura dos manifests — o objetivo deste milestone é justamente entender o que cada recurso faz.

**Rodar fora do cluster**
Prometheus e Grafana como serviços systemd na máquina host. Descartado porque exige configuração de rede extra para alcançar a API do Kubernetes, e não usa os mecanismos nativos do cluster.

**Acesso via `kubectl port-forward`**
Túnel temporário gerenciado pelo kubectl, adequado para debug pontual. Descartado porque não é permanente e não exercita o recurso Ingress.

**Acesso via path (`192.168.122.86/grafana`)**
Mais simples que o roteamento por host — não requer entrada no `/etc/hosts`. Descartado em favor do roteamento por host, que é o padrão em ambientes reais e demonstra melhor o uso do Ingress.

**Dashboard 315 sem adaptações**
O dashboard original usa labels e filtros específicos para Docker e versões antigas do Kubernetes. Importar sem modificações resultaria em painéis sem dados. A adaptação foi necessária para compatibilidade com k3s/containerd e Kubernetes 1.16+.