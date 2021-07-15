#
# Process membership for var.azuread_groups in members attribute
#

data "azuread_user" "upn" {
  for_each = toset(try(var.settings.members.user_principal_names, []))

  user_principal_name = each.value
}

module "user_principal_names" {
  source   = "./member"
  for_each = toset(try(var.settings.members.user_principal_names, []))

  group_object_id  = var.group_id
  member_object_id = data.azuread_user.upn[each.key].id
}

module "service_principals" {
  source   = "./member"
  for_each = toset(try(var.settings.members.service_principal_keys, []))

  group_object_id  = var.group_id
  member_object_id = var.azuread_apps[each.key].azuread_service_principal.object_id
}

module "azuread_service_principals" {
  source   = "./member"
  for_each = toset(try(var.settings.members.azuread_service_principal_keys, []))

  group_object_id  = var.group_id
  member_object_id = var.azuread_service_principals[each.key].object_id
}

module "object_id" {
  source   = "./member"
  for_each = toset(try(var.settings.members.object_ids, []))

  group_object_id  = var.group_id
  member_object_id = each.value
}

data "azuread_group" "name" {
  for_each = toset(try(var.settings.members.group_names, []))

  display_name = each.value
}

module "group_name" {
  source   = "./member"
  for_each = toset(try(var.settings.members.group_names, []))

  group_object_id  = var.group_id
  member_object_id = data.azuread_group.name[each.key].id
}

module "group_keys" {
  source   = "./member"
  for_each = toset(try(var.settings.members.group_keys, []))

  group_object_id  = var.group_id
  member_object_id = var.azuread_groups[each.key].id
}