# ADR-001 — KVM/libvirt como hypervisor

**Status:** Aceito  
**Data:** 2025-01

---

## Contexto

O projeto roda num host Ubuntu 24.04 e precisa de uma VM Linux isolada para
hospedar o cluster Kubernetes. O hypervisor precisa ser gerenciável via
Terraform (infraestrutura como código) e próximo do que se usa em ambientes
enterprise.

---

## Decisão

Usar **KVM + libvirt** como stack de virtualização, gerenciado pelo provider
Terraform `dmacvicar/libvirt`.

KVM (Kernel-based Virtual Machine) roda no kernel Linux como módulo nativo.
O libvirt é a camada de gerenciamento padrão usada por OpenStack, Proxmox e
oVirt. A combinação permite descrever VMs inteiramente em HCL via Terraform,
incluindo disco, rede, cloud-init e alocação de recursos.

---

## Consequências aceitas

- Só funciona em hosts Linux — sem portabilidade para macOS/Windows
- Requer que o usuário esteja no grupo `libvirt` e `kvm`
- Curva de aprendizado maior que VirtualBox para quem não conhece virsh/libvirt

---

## Alternativas rejeitadas

**VirtualBox + provider `virtualbox`**
Mais simples de instalar e multiplataforma, mas não é usado em ambientes
enterprise. O provider Terraform para VirtualBox é mantido pela comunidade
e menos estável. Performance inferior ao KVM por ser hypervisor tipo 2
sem integração com o kernel.

**VMware Workstation**
Performance excelente e muito usado em enterprise, mas é proprietário e pago.
Não faz sentido para um projeto de estudo open source.

**Vagrant**
Abstrai o hypervisor e facilita o provisionamento, mas adiciona uma camada
entre o Terraform e a VM que obscurece exatamente o que estamos querendo
demonstrar (IaC com Terraform). O objetivo do projeto é expor as camadas,
não abstraí-las.
