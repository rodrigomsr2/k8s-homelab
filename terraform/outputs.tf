output "k8s_vm_name" {
  description = "Nome da VM do Kubernetes"
  value       = module.k8s.vm_name
}

output "k8s_vm_ip" {
  description = "IP estático da VM do Kubernetes na rede homelab"
  value       = "192.168.123.10"
}

output "homelab_network_name" {
  description = "Nome da rede libvirt gerenciada para o homelab"
  value       = libvirt_network.homelab.name
}

output "ssh_user" {
  description = "Usuário SSH padrão das VMs (convenção do projeto)"
  value       = "devops"
}

output "private_key_path" {
  description = "Caminho da chave SSH privada compartilhada"
  value       = local_sensitive_file.private_key.filename
  sensitive   = true
}
