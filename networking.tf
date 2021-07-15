output "vnets" {
  depends_on = [azurerm_virtual_network_peering.peering]
  value      = module.networking

}

output "public_ip_addresses" {
  value = module.public_ip_addresses

}


#
#
# Virtual network
#
#

module "networking" {
  source   = "./modules/networking/virtual_network"
  for_each = local.networking.vnets

  application_security_groups       = local.combined_objects_application_security_groups
  client_config                     = local.client_config
  ddos_id                           = try(azurerm_network_ddos_protection_plan.ddos_protection_plan[each.value.ddos_services_key].id, "")
  diagnostics                       = local.combined_diagnostics
  global_settings                   = local.global_settings
  network_security_groups           = module.network_security_groups
  network_security_group_definition = local.networking.network_security_group_definition
  network_watchers                  = try(local.combined_objects_network_watchers, null)
  route_tables                      = module.route_tables
  settings                          = each.value
  tags                              = try(each.value.tags, null)

  resource_group_name = local.combined_objects_resource_groups[try(each.value.resource_group.lz_key, local.client_config.landingzone_key)][try(each.value.resource_group.key, each.value.resource_group_key)].name
  location            = lookup(each.value, "region", null) == null ? local.combined_objects_resource_groups[try(each.value.resource_group.lz_key, local.client_config.landingzone_key)][try(each.value.resource_group.key, each.value.resource_group_key)].location : local.global_settings.regions[each.value.region]
  base_tags           = try(local.global_settings.inherit_tags, false) ? local.combined_objects_resource_groups[try(each.value.resource_group.lz_key, local.client_config.landingzone_key)][try(each.value.resource_group.key, each.value.resource_group_key)].tags : {}
}

#
#
# Public IP Addresses
#
#

# naming convention for public IP address
resource "azurecaf_name" "public_ip_addresses" {
  for_each = local.networking.public_ip_addresses

  name          = try(each.value.name, null)
  resource_type = "azurerm_public_ip"
  prefixes      = local.global_settings.prefixes
  random_length = local.global_settings.random_length
  clean_input   = true
  passthrough   = local.global_settings.passthrough
  use_slug      = local.global_settings.use_slug
}

module "public_ip_addresses" {
  source   = "./modules/networking/public_ip_addresses"
  for_each = local.networking.public_ip_addresses

  name                       = azurecaf_name.public_ip_addresses[each.key].result
  resource_group_name        = local.combined_objects_resource_groups[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.resource_group_key].name
  location                   = lookup(each.value, "region", null) == null ? local.combined_objects_resource_groups[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.resource_group_key].location : local.global_settings.regions[each.value.region]
  sku                        = try(each.value.sku, "Basic")
  allocation_method          = try(each.value.allocation_method, "Dynamic")
  ip_version                 = try(each.value.ip_version, "IPv4")
  idle_timeout_in_minutes    = try(each.value.idle_timeout_in_minutes, null)
  domain_name_label          = try(each.value.domain_name_label, null)
  reverse_fqdn               = try(each.value.reverse_fqdn, null)
  generate_domain_name_label = try(each.value.generate_domain_name_label, false)
  tags                       = try(each.value.tags, null)
  ip_tags                    = try(each.value.ip_tags, null)
  public_ip_prefix_id        = try(each.value.public_ip_prefix_id, null)
  zones = coalesce(
    try(each.value.availability_zone, ""),
    try(tostring(each.value.zones[0]), ""),
    try(each.value.sku, "Basic") == "Basic" ? "No-Zone" : "Zone-Redundant"
  )
  diagnostic_profiles = try(each.value.diagnostic_profiles, {})
  diagnostics         = local.combined_diagnostics
  base_tags           = try(local.global_settings.inherit_tags, false) ? local.combined_objects_resource_groups[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.resource_group_key].tags : {}
}


#
#
# Vnet peering
#  (Support vnet in remote tfstates)
#

# naming convention for peering name
resource "azurecaf_name" "peering" {
  for_each = local.networking.vnet_peerings

  name          = try(each.value.name, "")
  resource_type = "azurerm_virtual_network_peering"
  prefixes      = local.global_settings.prefixes
  random_length = local.global_settings.random_length
  clean_input   = true
  passthrough   = local.global_settings.passthrough
  use_slug      = local.global_settings.use_slug
}

# The code tries to peer to a vnet created in the same landing zone. If it fails it tries with the data remote state
resource "azurerm_virtual_network_peering" "peering" {
  depends_on = [module.networking]
  for_each   = local.networking.vnet_peerings

  name                         = azurecaf_name.peering[each.key].result
  virtual_network_name         = try(each.value.from.virtual_network_name, null) != null ? each.value.from.virtual_network_name : try(each.value.from.lz_key, null) == null ? try(local.combined_objects_networking[local.client_config.landingzone_key][each.value.from.vnet_key].name, null) : try(local.combined_objects_networking[each.value.from.lz_key][each.value.from.vnet_key].name, null)
  resource_group_name          = try(each.value.from.resource_group_name, null) != null ? each.value.from.resource_group_name : try(each.value.from.lz_key, null) == null ? try(local.combined_objects_networking[local.client_config.landingzone_key][each.value.from.vnet_key].resource_group_name, null) : try(local.combined_objects_networking[each.value.from.lz_key][each.value.from.vnet_key].resource_group_name, null)
  remote_virtual_network_id    = try(each.value.to.remote_virtual_network_id, null) != null ? each.value.to.remote_virtual_network_id : try(each.value.to.lz_key, null) == null ? try(local.combined_objects_networking[local.client_config.landingzone_key][each.value.to.vnet_key].id, null) : try(local.combined_objects_networking[each.value.to.lz_key][each.value.to.vnet_key].id, null)
  allow_virtual_network_access = try(each.value.allow_virtual_network_access, true)
  allow_forwarded_traffic      = try(each.value.allow_forwarded_traffic, false)
  allow_gateway_transit        = try(each.value.allow_gateway_transit, false)
  use_remote_gateways          = try(each.value.use_remote_gateways, false)
}

#
#
# Route tables and routes
#
#
resource "azurecaf_name" "route_tables" {
  for_each = local.networking.route_tables

  name          = try(each.value.name, null)
  resource_type = "azurerm_route_table"
  prefixes      = local.global_settings.prefixes
  random_length = local.global_settings.random_length
  clean_input   = true
  passthrough   = local.global_settings.passthrough
  use_slug      = local.global_settings.use_slug
}

module "route_tables" {
  source   = "./modules/networking/route_tables"
  for_each = local.networking.route_tables

  name                          = azurecaf_name.route_tables[each.key].result
  resource_group_name           = local.combined_objects_resource_groups[try(each.value.resource_group.lz_key, local.client_config.landingzone_key)][try(each.value.resource_group.key, each.value.resource_group_key)].name
  location                      = lookup(each.value, "region", null) == null ? local.combined_objects_resource_groups[try(each.value.resource_group.lz_key, local.client_config.landingzone_key)][try(each.value.resource_group.key, each.value.resource_group_key)].location : local.global_settings.regions[each.value.region]
  base_tags                     = try(local.global_settings.inherit_tags, false) ? local.combined_objects_resource_groups[try(each.value.resource_group.lz_key, local.client_config.landingzone_key)][try(each.value.resource_group.key, each.value.resource_group_key)].tags : {}
  disable_bgp_route_propagation = try(each.value.disable_bgp_route_propagation, null)
  tags                          = try(each.value.tags, null)
}

resource "azurecaf_name" "routes" {
  for_each = local.networking.azurerm_routes

  name          = try(each.value.name, null)
  resource_type = "azurerm_route"
  prefixes      = local.global_settings.prefixes
  random_length = local.global_settings.random_length
  clean_input   = true
  passthrough   = local.global_settings.passthrough
  use_slug      = local.global_settings.use_slug
}


module "routes" {
  source   = "./modules/networking/routes"
  for_each = local.networking.azurerm_routes

  name                   = azurecaf_name.routes[each.key].result
  resource_group_name    = local.combined_objects_resource_groups[try(each.value.resource_group.lz_key, local.client_config.landingzone_key)][try(each.value.resource_group.key, each.value.resource_group_key)].name
  route_table_name       = module.route_tables[each.value.route_table_key].name
  address_prefix         = each.value.address_prefix
  next_hop_type          = each.value.next_hop_type
  next_hop_in_ip_address = try(lower(each.value.next_hop_type), null) == "virtualappliance" ? try(each.value.next_hop_in_ip_address, null) : null
  next_hop_in_ip_address_fw = try(lower(each.value.next_hop_type), null) == "virtualappliance" ? try(
    try(local.combined_objects_azurerm_firewalls[try(each.value.private_ip_keys.azurerm_firewall.lz_key, local.client_config.landingzone_key)][each.value.private_ip_keys.azurerm_firewall.key].ip_configuration[each.value.private_ip_keys.azurerm_firewall.interface_index].private_ip_address, null),
    try(local.combined_objects_azurerm_firewalls[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.private_ip_keys.azurerm_firewall.key].ip_configuration[each.value.private_ip_keys.azurerm_firewall.interface_index].private_ip_address, null),
    null
  ) : null

}

#
#
# Azure DDoS
#
#

# naming convention
resource "azurecaf_name" "ddos_protection_plan" {
  for_each = local.networking.ddos_services

  name          = try(each.value.name, null)
  resource_type = "azurerm_network_ddos_protection_plan"
  prefixes      = local.global_settings.prefixes
  random_length = local.global_settings.random_length
  clean_input   = true
  passthrough   = local.global_settings.passthrough
  use_slug      = local.global_settings.use_slug
}

resource "azurerm_network_ddos_protection_plan" "ddos_protection_plan" {
  for_each = local.networking.ddos_services

  name                = azurecaf_name.ddos_protection_plan[each.key].result
  location            = lookup(each.value, "region", null) == null ? local.combined_objects_resource_groups[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.resource_group_key].location : local.global_settings.regions[each.value.region]
  resource_group_name = local.combined_objects_resource_groups[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.resource_group_key].name
  tags                = try(local.global_settings.inherit_tags, false) ? merge(local.combined_objects_resource_groups[try(each.value.lz_key, local.client_config.landingzone_key)][each.value.resource_group_key].tags, each.value.tags) : try(each.value.tags, null)
}

#
#
# Network Watchers
#
#
module "network_watchers" {
  source   = "./modules/networking/network_watcher"
  for_each = local.networking.network_watchers

  resource_group_name = local.combined_objects_resource_groups[try(each.value.resource_group.lz_key, local.client_config.landingzone_key)][try(each.value.resource_group.key, each.value.resource_group_key)].name
  location            = lookup(each.value, "region", null) == null ? local.combined_objects_resource_groups[try(each.value.resource_group.lz_key, local.client_config.landingzone_key)][try(each.value.resource_group.key, each.value.resource_group_key)].location : local.global_settings.regions[each.value.region]
  base_tags           = try(local.global_settings.inherit_tags, false) ? local.combined_objects_resource_groups[try(each.value.resource_group.lz_key, local.client_config.landingzone_key)][try(each.value.resource_group.key, each.value.resource_group_key)].tags : {}
  settings            = each.value
  tags                = try(each.value.tags, null)
  global_settings     = local.global_settings
}