output "resource_guid" {
  value       = azurerm_nat_gateway.nat_gateway.resource_guid
  description = "The resource GUID property of the NAT Gateway."
}

output "id" {
  value       = azurerm_nat_gateway.nat_gateway.id
  description = "The ID of the NAT Gateway."
}
