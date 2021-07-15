
#
#
# Nat Gateways
#
#

output "nat_gateways" {
  value = module.nat_gateways
}

module "nat_gateways" {
  source   = "./modules/networking/nat_gateways"
  for_each = try(local.networking.nat_gateways, {})

  settings                   = each.value
  name                       = try(each.value.name, null)
  location                   = try(local.global_settings.regions[each.value.region], local.combined_objects_resource_groups[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.resource_group_key].location)
  resource_group_name        = local.combined_objects_resource_groups[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.resource_group_key].name
  subnet_id                  = try(local.combined_objects_networking[try(each.value.vnet.lz_key, local.client_config.landingzone_key)][try(each.value.vnet.vnet_key, each.value.vnet_key)].subnets[try(each.value.vnet.subnet_key, each.value.subnet_key)].id, null)
  public_ip_address_id       = try(local.combined_objects_public_ip_addresses[try(each.value.public_ip.lz_key, local.client_config.landingzone_key)][try(each.value.public_ip.public_ip_key, each.value.public_ip_key)].id, null)
  idle_timeout_in_minutes    = try(each.value.idle_timeout_in_minutes, null)
  tags                       = try(each.value.tags, null)
  base_tags                  = try(local.global_settings.inherit_tags, false) ? local.combined_objects_resource_groups[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.resource_group_key].tags : {}
}
