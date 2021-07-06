resource "azuread_application" "app" {

  display_name = var.global_settings.passthrough ? format("%s", var.settings.application_name) : format("%v-%s", try(var.global_settings.prefixes[0], ""), var.settings.application_name)

  owners = [
    # Removing as it causes issue with Switch from User to Service Prinicpal
    #var.client_config.object_id
  ]

  reply_urls                 = try(var.settings.reply_urls, null)
  logout_url                 = try(var.settings.logout_url, null)
  identifier_uris            = try(var.settings.identifier_uris, null)
  available_to_other_tenants = try(var.settings.available_to_other_tenants, false)
  public_client              = try(var.settings.public_client, false)
  oauth2_allow_implicit_flow = try(var.settings.oauth2_allow_implicit_flow, false)
  group_membership_claims    = try(var.settings.group_membership_claims, "All")
  prevent_duplicate_names    = try(var.settings.identifier_uris, false)

  dynamic "required_resource_access" {
    for_each = var.azuread_api_permissions

    content {
      resource_app_id = required_resource_access.value.resource_app_id

      dynamic "resource_access" {
        for_each = {
          for key, resource in required_resource_access.value.resource_access : key => resource
        }

        content {
          id   = resource_access.value.id
          type = resource_access.value.type
        }
      }
    }
  }

}

resource "azuread_service_principal" "app" {
  application_id               = azuread_application.app.application_id
  app_role_assignment_required = try(var.settings.app_role_assignment_required, false)
  tags                         = try(var.settings.tags, null)
}

resource "azuread_service_principal_password" "pwd" {
  service_principal_id = azuread_service_principal.app.id
  value                = random_password.pwd.result
  end_date             = timeadd(time_rotating.pwd.id, format("%sh", local.password_policy.expire_in_days * 24))

  lifecycle {
    create_before_destroy = false
  }
}

locals {
  password_policy = try(var.settings.password_policy, var.password_policy)
}

resource "time_rotating" "pwd" {
  rotation_minutes = try(local.password_policy.rotation.mins, null)
  rotation_days    = try(local.password_policy.rotation.days, null)
  rotation_months  = try(local.password_policy.rotation.months, null)
  rotation_years   = try(local.password_policy.rotation.years, null)
}

# Will force the password to change every month
resource "random_password" "pwd" {
  keepers = {
    frequency = time_rotating.pwd.id
  }
  length  = local.password_policy.length
  special = local.password_policy.special
  upper   = local.password_policy.upper
  number  = local.password_policy.number
}
