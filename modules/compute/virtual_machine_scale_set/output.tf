output "id" {
  value = local.os_type == "linux" ? try(azurerm_linux_virtual_machine_scale_set.vmss["linux"].id, null) : try(azurerm_linux_virtual_machine_scale_set.vmss["windows"].id, null)
}

output "os_type" {
  value = local.os_type
}

output "admin_username" {
  value       = try(local.admin_username, null) == null ? var.settings.vmss_settings[local.os_type].admin_username : local.admin_username
  description = "Local admin username"
}

output "admin_password_secret_id" {
  value       = try(azurerm_key_vault_secret.admin_password[local.os_type].id, null)
  description = "Local admin password Key Vault secret id"
}

output "winrm" {
  value = local.os_type == "windows" ? {
    keyvault_id     = local.keyvault.id
    certificate_url = try(azurerm_key_vault_certificate.self_signed_winrm[local.os_type].secret_id, null)
  } : null
}

output "ssh_keys" {
  value = local.create_sshkeys ? {
    keyvault_id              = local.keyvault.id
    ssh_private_key_pem      = azurerm_key_vault_secret.ssh_private_key[local.os_type].name
    ssh_public_key_open_ssh = azurerm_key_vault_secret.ssh_public_key_openssh[local.os_type].name
    ssh_private_key_open_ssh = azurerm_key_vault_secret.ssh_public_key_openssh[local.os_type].name #for backard compat, wrong name, will be removed in future version.
  } : null
}
