# ─── SSH Key ────────────────────────────────────────────────────────────────────
# Gera um par de chaves ED25519 dedicado ao projeto e salva localmente em .ssh/
# A chave privada nunca é versionada (.gitignore)

resource "tls_private_key" "homelab" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.homelab.private_key_openssh
  filename        = "${path.module}/../.ssh/homelab_ed25519"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content  = tls_private_key.homelab.public_key_openssh
  filename = "${path.module}/../.ssh/homelab_ed25519.pub"
}
