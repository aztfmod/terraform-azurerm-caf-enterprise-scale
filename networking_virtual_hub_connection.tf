
#
#
# Virtual WAN peerings with vnets
#
#

output "virtual_hub_connections" {
  value = azurerm_virtual_hub_connection.vhub_connection
}


# Virtual Hub Peerings to virtual networks
resource "azurerm_virtual_hub_connection" "vhub_connection" {
  depends_on = [azurerm_virtual_hub_route_table.route_table, module.azurerm_firewalls]
  for_each   = local.networking.virtual_hub_connections

  name           = each.value.name
  virtual_hub_id = local.azurerm_virtual_hub_connection[each.key].virtual_hub_id
  remote_virtual_network_id = coalesce(
    try(local.combined_objects_networking[try(each.value.vnet.lz_key, local.client_config.landingzone_key)][each.value.vnet.vnet_key].id, ""),
    try(each.value.vnet.resource_id, "")
  )
  internet_security_enabled = try(each.value.internet_security_enabled, null)

  dynamic "routing" {
    for_each = try(each.value.routing, {})

    content {
      associated_route_table_id = try(
        coalesce(
          try(routing.value.id, ""),
          try(azurerm_virtual_hub_route_table.route_table[routing.value.virtual_hub_route_table_key].id, ""),
          try(var.remote_objects.virtual_hub_route_tables[try(routing.value.lz_key, local.client_config.landingzone_key)][routing.value.virtual_hub_route_table_key].id, ""),
          contains(tolist(["defaultRouteTable", "None"]), routing.value.virtual_hub_route_table_key) ? format("%s/hubRouteTables/%s", local.azurerm_virtual_hub_connection[each.key].virtual_hub_id, routing.value.virtual_hub_route_table_key) : "None"
        ),
        null
      )

      dynamic "propagated_route_table" {
        for_each = try(routing.value.propagated_route_table, null) == null ? [] : [1]

        content {
          labels = try(flatten([for label in routing.value.propagated_route_table.labels : label if try(label, "") != ""]), [])
          route_table_ids = coalesce(
            flatten(
              [
                for key in try(routing.value.propagated_route_table.virtual_hub_route_table_keys, []) : contains(tolist(["defaultRouteTable", "None"]), key) ? format("%s/hubRouteTables/%s", local.azurerm_virtual_hub_connection[each.key].virtual_hub_id, key) : local.combined_objects_virtual_hub_route_tables[try(routing.value.lz_key, local.client_config.landingzone_key)][key].id
              ]
            ),
            flatten(
              [
                for id in try(routing.value.propagated_route_table.ids, []) : id
              ]
            )
          )
        }
      }

      dynamic "static_vnet_route" {
        for_each = try(routing.value.static_vnet_route, {})

        content {
          name                = static_vnet_route.value.name
          address_prefixes    = static_vnet_route.value.address_prefixes
          next_hop_ip_address = coalesce(
            try(static_vnet_route.value.next_hop_ip_address, null),
            try(local.combined_objects_azurerm_firewalls[static_vnet_route.value.next_hop.lz_key][static_vnet_route.value.next_hop.key].ip_configuration[static_vnet_route.value.next_hop.interface_index].private_ip_address, null),
            try(local.combined_objects_azurerm_firewalls[static_vnet_route.value.next_hop.lz_key][static_vnet_route.value.next_hop.key].virtual_hub.private_ip_address, null),
            try(local.combined_objects_azurerm_firewalls[local.client_config.landingzone_key][static_vnet_route.value.next_hop.key].ip_configuration[static_vnet_route.value.next_hop.interface_index].private_ip_address, null),
            try(local.combined_objects_azurerm_firewalls[local.client_config.landingzone_key][static_vnet_route.value.next_hop.key].virtual_hub[static_vnet_route.value.next_hop.interface_index].private_ip_address, null)
          )
        }
      }

    }
  }
}

locals {
  azurerm_virtual_hub_connection = {
    for key, value in local.networking.virtual_hub_connections : key => {
      virtual_hub_id = coalesce(
        try(local.combined_objects_virtual_wans[try(value.vhub.lz_key, local.client_config.landingzone_key)][value.vhub.virtual_wan_key].virtual_hubs[value.vhub.virtual_hub_key].id, null),
        try(local.combined_objects_virtual_wans[try(value.virtual_hub.lz_key, local.client_config.landingzone_key)][value.virtual_wan.key].virtual_hubs[value.virtual_hub.key].id, null),
        try(local.combined_objects_virtual_hubs[try(value.virtual_hub.lz_key, local.client_config.landingzone_key)][value.virtual_hub.key].id, null)
      )
    }
  }
}
