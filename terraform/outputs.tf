# Outputs de recursos compartilhados entre todas as VMs.
# Outputs específicos de cada VM ficam no .tf da VM correspondente
# (k8s.tf, mongodb.tf, etc.).

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
