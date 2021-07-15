
output "mssql_managed_instances" {
  value = module.mssql_managed_instances

}
output "mssql_managed_instances_secondary" {
  value = module.mssql_managed_instances_secondary
}

module "mssql_managed_instances" {
  source     = "./modules/databases/mssql_managed_instance"
  for_each   = local.database.mssql_managed_instances
  depends_on = [module.routes]

  global_settings     = local.global_settings
  settings            = each.value
  resource_group_name = local.combined_objects_resource_groups[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.resource_group_key].name
  location            = try(local.global_settings.regions[each.value.region], local.combined_objects_resource_groups[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.resource_group_key].location)
  subnet_id           = local.combined_objects_networking[try(each.value.networking.lz_key, local.client_config.landingzone_key)][each.value.networking.vnet_key].subnets[each.value.networking.subnet_key].id
  base_tags           = try(local.global_settings.inherit_tags, false) ? local.resource_groups[each.value.resource_group_key].tags : {}
  keyvault_id         = try(each.value.administratorLoginPassword, null) == null ? module.keyvaults[each.value.keyvault_key].id : null
}

module "mssql_managed_instances_secondary" {
  source     = "./modules/databases/mssql_managed_instance"
  for_each   = local.database.mssql_managed_instances_secondary
  depends_on = [module.routes]

  global_settings     = local.global_settings
  settings            = each.value
  resource_group_name = local.combined_objects_resource_groups[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.resource_group_key].name
  location            = try(local.global_settings.regions[each.value.region], local.combined_objects_resource_groups[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.resource_group_key].location)
  subnet_id           = local.combined_objects_networking[try(each.value.networking.lz_key, local.client_config.landingzone_key)][each.value.networking.vnet_key].subnets[each.value.networking.subnet_key].id
  primary_server_id   = module.mssql_managed_instances[each.value.primary_server.mi_server_key].id
  base_tags           = try(local.global_settings.inherit_tags, false) ? local.resource_groups[each.value.resource_group_key].tags : {}
  keyvault_id         = try(each.value.administratorLoginPassword, null) == null ? module.keyvaults[each.value.keyvault_key].id : null
}

module "mssql_mi_failover_groups" {
  source   = "./modules/databases/mssql_managed_instance/failover_group"
  for_each = local.database.mssql_mi_failover_groups

  global_settings          = local.global_settings
  settings                 = each.value
  resource_group_name      = local.combined_objects_resource_groups[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.resource_group_key].name
  primaryManagedInstanceId = local.combined_objects_mssql_managed_instances[try(each.value.primary_server.lz_key, local.client_config.landingzone_key)][each.value.primary_server.mi_server_key].id
  partnerManagedInstanceId = module.mssql_managed_instances_secondary[each.value.secondary_server.mi_server_key].id
  partnerRegion            = module.mssql_managed_instances_secondary[each.value.secondary_server.mi_server_key].location
}

module "mssql_mi_administrators" {
  source = "./modules/databases/mssql_managed_instance/administrator"

  depends_on = [module.azuread_roles_sql_mi, module.azuread_roles_sql_mi_secondary]
  for_each   = local.database.mssql_mi_administrators

  resource_group_name = local.combined_objects_resource_groups[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.resource_group_key].name
  mi_name             = try(module.mssql_managed_instances[each.value.mi_server_key].name, module.mssql_managed_instances_secondary[each.value.mi_server_key].name)
  settings            = each.value
  user_principal_name = try(each.value.user_principal_name, null)
  group_id            = try(local.combined_objects_azuread_groups[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.azuread_group_key].id, null)
  group_name          = try(local.combined_objects_azuread_groups[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.azuread_group_key].name, null)
}

module "mssql_mi_secondary_tde" {
  source = "./modules/databases/mssql_managed_instance/tde"

  //depends_on =
  for_each = local.database.mssql_mi_secondary_tdes

  resource_group_name = local.combined_objects_resource_groups[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.resource_group_key].name
  mi_name             = module.mssql_managed_instances_secondary[each.value.mi_server_key].name
  keyvault_key        = try(local.combined_objects_keyvault_keys[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.keyvault_key_key], null)
  is_secondary_tde    = true
  secondary_keyvault  = try(local.combined_objects_keyvaults[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.secondary_keyvault_key], null)
}

#Both initial setup and rotation of the TDE protector must be done on the secondary first, and then on primary.
module "mssql_mi_tde" {
  source     = "./modules/databases/mssql_managed_instance/tde"
  depends_on = [module.mssql_mi_secondary_tde]

  //depends_on =
  for_each = local.database.mssql_mi_tdes

  resource_group_name = local.combined_objects_resource_groups[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.resource_group_key].name
  mi_name             = module.mssql_managed_instances[each.value.mi_server_key].name
  keyvault_key        = try(local.combined_objects_keyvault_keys[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.keyvault_key_key], null)
}