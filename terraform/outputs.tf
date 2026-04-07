output "vm_name" {
  description = "Nome da VM"
  value       = libvirt_domain.vm.name
}

output "private_key_path" {
  description = "Caminho da chave SSH privada"
  value       = local_sensitive_file.private_key.filename
  sensitive   = true
}

output "ssh_user" {
  description = "Usuário SSH da VM"
  value       = var.vm_user
}
