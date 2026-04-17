# Runbook — Logs (Loki + Promtail)

---

## 1. compactor.delete-request-store obrigatório com retenção habilitada

### Sintoma
O pod `loki-0` entra em `CrashLoopBackOff` imediatamente após a instalação. Os logs exibem:

```
level=error msg="validating config" err="CONFIG ERROR: invalid compactor config:
compactor.delete-request-store should be configured when retention is enabled"
```

### Causa
O campo `compactor.retention_enabled: true` exige que `compactor.delete_request_store` esteja configurado — o Loki precisa saber onde armazenar as requisições de deleção para processar a retenção.

### Solução
Adicionar `delete_request_store` no bloco `compactor` do `loki-values.yaml`:

```yaml
loki:
  compactor:
    retention_enabled: true
    delete_request_store: filesystem
```

Aplicar com `helm upgrade`:

```bash
helm upgrade loki grafana/loki \
  --kubeconfig=$HOME/.kube/k8s-homelab.yaml \
  --namespace monitoring \
  --values k8s/monitoring/loki-values.yaml
```

### Lição
Ao habilitar retenção no Loki, os campos `retention_enabled` e `delete_request_store` são obrigatórios em conjunto. O valor de `delete_request_store` deve corresponder ao backend de storage configurado — `filesystem` para instalações locais.

---

## 2. chunksCache e resultsCache inviáveis em homelab

### Sintoma
O pod `loki-chunks-cache-0` fica em `Pending` indefinidamente. O `kubectl describe` exibe:

```
0/1 nodes are available: 1 Insufficient memory.
```

### Causa
O chart do Loki habilita por padrão dois pods Memcached — `chunksCache` e `resultsCache` — como cache de leitura. O `chunksCache` solicita **9830Mi (~9.6GB)** de memória, inviável em um node com 8GB de RAM total.

### Solução
Desabilitar ambos os caches no `loki-values.yaml`:

```yaml
chunksCache:
  enabled: false

resultsCache:
  enabled: false
```

### Lição
Os defaults do chart do Loki são dimensionados para produção. Em homelab com recursos limitados, inspecionar os recursos solicitados pelos subcharts antes de instalar via `helm show values grafana/loki > /tmp/loki-default-values.yaml`.

---

## 3. volumeMount duplicado no helm install do Promtail

### Sintoma
O primeiro `helm install` do Promtail falha com:

```
DaemonSet.apps "promtail" is invalid:
spec.template.spec.containers[0].volumeMounts[4].mountPath: Invalid value:
"/var/log/pods": must be unique
```

### Causa
O chart do Promtail já monta `/var/log/pods` por padrão. Adicionar o mesmo path em `extraVolumeMounts` causa duplicação.

### Solução
Remover `/var/log/pods` dos `extraVolumeMounts` no `promtail-values.yaml` — manter apenas o path específico do k3s:

```yaml
extraVolumes:
  - name: containers-logs
    hostPath:
      path: /var/lib/rancher/k3s/agent/containerd

extraVolumeMounts:
  - name: containers-logs
    mountPath: /var/lib/rancher/k3s/agent/containerd
    readOnly: true
```

### Lição
Antes de adicionar volumes em `extraVolumeMounts`, verificar quais paths o chart já monta por padrão via `helm show values grafana/promtail`.

---

## 4. Container do Loki sem wget nem curl

### Sintoma
Testes de API via `kubectl exec` falham:

```
exec: "wget": executable file not found in $PATH
exec: "curl": executable file not found in $PATH
```

### Causa
A imagem do Loki é minimalista e não inclui ferramentas de diagnóstico como `wget` ou `curl`.

### Solução
Usar port-forward para acessar a API do Loki a partir do host:

```bash
kubectl --kubeconfig=$HOME/.kube/k8s-homelab.yaml \
  port-forward -n monitoring pod/loki-0 3100:3100 &
sleep 2
curl -s http://localhost:3100/ready
curl -s -H "X-Scope-OrgID: homelab" http://localhost:3100/loki/api/v1/labels
kill %1
```

### Lição
Imagens de produção frequentemente não incluem ferramentas de diagnóstico. Para testar APIs de pods sem essas ferramentas, port-forward é a alternativa correta — evita a necessidade de instalar pacotes no container.

---

## 5. Loki logando tudo no stderr

### Sintoma
Todos os logs do Loki aparecem no `stderr`, incluindo entradas de nível `info`. Isso pode causar confusão ao inspecionar logs via `kubectl logs`.

### Causa
Decisão de design da Grafana — o Loki escreve todos os logs no `stderr` independente do nível para garantir que nenhuma entrada seja descartada por pipelines que filtram um dos streams.

### Solução
Não requer correção. Ao inspecionar logs do Loki, ignorar que o stream é `stderr` e focar no campo `level=` dentro da mensagem para determinar a severidade real.

### Lição
`stderr` em containers não indica necessariamente erro — é apenas um stream de saída. O nível real do log está sempre no conteúdo da mensagem.
