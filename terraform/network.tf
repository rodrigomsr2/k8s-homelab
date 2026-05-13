# ─── Rede homelab ────────────────────────────────────────────────────────────────
# Rede NAT dedicada ao homelab, separada da rede "default" do libvirt.
# Razões para uma rede própria (ADR-012):
#   - IPs estáticos previsíveis para integração entre VMs (k8s ↔ MongoDB ↔ Kafka)
#   - Gerenciada por código, recriável do zero junto com o resto do ambiente
#   - Isolamento lógico: VMs do homelab vivem numa subnet própria
#
# Convenção de endereçamento na rede:
#   192.168.123.1                gateway (libvirt)
#   192.168.123.10  – .49        IPs estáticos reservados (VMs gerenciadas)
#   192.168.123.50  – .99        reservado (livre)
#   192.168.123.100 – .254       pool DHCP (VMs efêmeras / testes)
#
# Alocação atual:
#   192.168.123.10  → k8s-node-01
#   192.168.123.20  → mongodb-01 (v0.6.0)
#   192.168.123.30  → kafka-01   (v0.7.0)

resource "libvirt_network" "homelab" {
  name      = "homelab"
  autostart = true

  forward = {
    mode = "nat"
  }

  bridge = {
    name = "virbr-homelab"
  }

  ips = [
    {
      address = "192.168.123.1"
      family  = "ipv4"
      prefix  = 24

      dhcp = {
        ranges = [
          {
            start = "192.168.123.100"
            end   = "192.168.123.254"
          }
        ]
      }
    }
  ]
}
