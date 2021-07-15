#TODO: Implement right naming convention
# resource "azurecaf_name" "nat_gateway" {
#   name          = var.name
#   resource_type = "azurerm_nat_gateway"
#   prefixes      = var.global_settings.prefixes
#   random_length = var.global_settings.random_length
#   clean_input   = true
#   passthrough   = var.global_settings.passthrough
#   use_slug      = var.global_settings.use_slug
# }


resource "azurerm_nat_gateway" "nat_gateway" {
  name                     = var.name
  location                 = var.location
  resource_group_name      = var.resource_group_name
  idle_timeout_in_minutes  = var.idle_timeout_in_minutes
  zones                    = try(var.settings.zones, null)
  tags                     = local.tags
}

module "nat_gateway_subnet" {
  count  = try(var.settings.subnet_key, null) == null ? 0 : 1
  source = "./subnet_association"

  subnet_id      = var.subnet_id
  nat_gateway_id = azurerm_nat_gateway.nat_gateway.id
}

module "nat_gateway_public_ip" {
  count  = try(var.settings.public_ip_key, null) == null ? 0 : 1
  source = "./public_ip_association"

  public_ip_address_id = var.public_ip_address_id
  nat_gateway_id       = azurerm_nat_gateway.nat_gateway.id
}