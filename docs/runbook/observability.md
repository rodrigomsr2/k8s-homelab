# Runbook — Observabilidade (Prometheus + Grafana + Node Exporter)

---

## 1. Dashboard 315 com painéis sem dados após importação

### Sintoma
Painéis do dashboard Kubernetes cluster monitoring (ID 315) aparecem vazios ou com mensagem `No data` após importação no Grafana.

### Causa
O dashboard 315 foi criado para versões antigas do Kubernetes com Docker como runtime. Três incompatibilidades com k3s/containerd:

- Label `pod_name` foi renomeado para `pod` no Kubernetes 1.16
- Filtro `name=~"^k8s_.*"` era específico para containers Docker, que prefixava nomes com `k8s_`. O containerd não segue esse padrão — o filtro descarta todos os containers
- Label `systemd_service_name` é específico para ambientes Docker/systemd e não existe no containerd

### Solução
Editar cada painel afetado e aplicar as seguintes correções nas queries:

| De | Para |
|----|------|
| `pod_name` | `pod` |
| `name=~"^k8s_.*"` | `container!=""` |
| `systemd_service_name!=""` agrupado por `systemd_service_name` | `image!="",container!=""` agrupado por `namespace` |

Para métricas de rede, remover `container!=""` — as métricas `container_network_*` são coletadas no nível do pod e não têm o label `container` preenchido.

### Lição
Dashboards da comunidade Grafana frequentemente assumem Docker como runtime e versões antigas do Kubernetes. Sempre verificar a compatibilidade com a versão do Kubernetes e o runtime em uso antes de importar. O JSON adaptado para k3s/containerd está versionado em `k8s/monitoring/dashboards/kubernetes-cluster-monitoring-315.json`.

---

## 2. Node Exporter sem acesso ao /run/udev

### Sintoma
Log do Node Exporter exibe o seguinte aviso na inicialização:

```
caller=diskstats_linux.go:265 level=error collector=diskstats
msg="Failed to open directory, disabling udev device properties"
path=/run/udev/data
```

Painéis de disco no Grafana aparecem sem labels de modelo, fabricante e número de série do dispositivo.

### Causa
O container não tem acesso ao diretório `/run/udev/data` do host, onde o udev armazena metadados de dispositivos de hardware. Sem esse acesso, o Node Exporter não consegue enriquecer as métricas de disco com informações do dispositivo.

### Solução
Adicionar o mount do `/run/udev` no DaemonSet do Node Exporter:

```yaml
volumeMounts:
  - name: udev
    mountPath: /run/udev
    readOnly: true

volumes:
  - name: udev
    hostPath:
      path: /run/udev
```

### Lição
O Node Exporter precisa de acesso a vários recursos do host para coletar métricas completas. Além do sistema de arquivos raiz (`/`), o `/run/udev` é necessário para métricas de dispositivos. Sempre verificar os logs na primeira inicialização para identificar collectors com problemas de acesso.

---

## 3. Painéis Graph (old) com eixo X poluído

### Sintoma
Painéis do tipo `Graph (old)` exibem timestamps muito densos no eixo X, tornando a leitura impossível. O problema não é reproduzido no modo de edição do painel.

### Causa
O componente `Graph (old)` é o visualizador legado do Grafana baseado em Angular, descontinuado a partir do Grafana 10. Ele tem problemas de renderização conhecidos que não são corrigidos por configurações de resolução (`Min step`).

### Solução
Trocar o tipo do painel de `Graph (old)` para `Time series` no editor do Grafana. As queries permanecem as mesmas — apenas o componente de visualização muda.

No editor do painel: canto superior direito → tipo do painel → selecionar **Time series**.

### Lição
O Grafana 10 descontinuou o componente Angular. Dashboards importados da comunidade que usam `Graph (old)` devem ter seus painéis migrados para `Time series`. A migração é simples e não requer alteração nas queries.

---

## 4. Métricas de rede com legenda poluída

### Sintoma
Painéis de rede exibem múltiplas séries na legenda para o mesmo pod, uma para cada interface de rede (incluindo loopback `lo`).

### Causa
As métricas `container_network_receive_bytes_total` e `container_network_transmit_bytes_total` geram uma série por interface de rede. Sem filtro de interface, o loopback (`lo`) aparece junto com as interfaces reais, poluindo a visualização.

### Solução
Adicionar o filtro `interface!="lo"` nas queries de rede:

```promql
sum(rate(container_network_receive_bytes_total{image!="",interface!="lo",kubernetes_io_hostname=~"^$Node$"}[1m])) by (pod)
```

O filtro `interface!="lo"` é preferível a `interface="eth0"` porque funciona independente do nome da interface (`eth0`, `ens3`, `enp0s3`, etc.).

### Lição
Métricas de rede do cAdvisor incluem todas as interfaces do pod, incluindo loopback. Sempre filtrar `interface!="lo"` em queries de rede para evitar séries redundantes na legenda.

---

## 5. Script de validação falhando em checks de targets UP

### Sintoma
O script `validate-observability.sh` reporta falha nos checks de targets UP mesmo com todos os jobs aparecendo como `UP` no Prometheus (`/targets`).

### Causa
A query da API do Prometheus continha chaves `{}` e aspas que eram interpretadas pelo shell antes de serem enviadas via `curl`, corrompendo a URL. O `grep` usado para detectar o valor `"1"` na resposta também era frágil para o formato JSON retornado.

### Solução
URL-encodar os caracteres especiais na query (`{` → `%7B`, `}` → `%7D`) e substituir o `grep` por `python3` para parsing correto do JSON:

```bash
UP=$(curl -s "$PROM_URL/api/v1/query?query=up%7Bjob%3D%22$job%22%7D" 2>/dev/null \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('data', {}).get('result', [])
up = sum(1 for r in results if r.get('value', [None, None])[1] == '1')
print(up)
")
```

### Lição
Queries com caracteres especiais passadas via shell para `curl` precisam ser URL-encoded. Para parsing de respostas JSON em scripts bash, `python3` é mais robusto que `grep` — evita falsos negativos causados por variações no formato da resposta.
