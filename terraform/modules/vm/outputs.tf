output "vm_name" {
  description = "Nome da VM (igual ao input — útil para encadeamento)"
  value       = libvirt_domain.vm.name
}
