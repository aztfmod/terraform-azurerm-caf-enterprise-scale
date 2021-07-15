# Admin consent management is not performed in the same way if the logged in user is a service principal or a user
# We have two local variables to accomodate that.
locals {
  api_permissions = {
    for api_permission in
    flatten(
      [
        for key, resources in var.azuread_api_permissions : [
          for resource_name, resource in resources.resource_access : {
            aad_app_key     = key
            resource_name   = resource_name
            resource_app_id = resources.resource_app_id
            id              = resource.id
            type            = resource.type
          } if resource.type == "Role"
        ]
      ]
    ) : format("%s-%s", api_permission.aad_app_key, api_permission.resource_name) => api_permission
  }
}


resource "null_resource" "grant_admin_consent" {
  depends_on = [time_sleep.propagate_to_azuread]

  triggers = {
    resourceAppId  = each.value.resource_app_id
    appRoleId      = each.value.id
    principalId    = azuread_service_principal.app.object_id
    application_id = azuread_service_principal.app.application_id
  }

  for_each = {
    for key, permission in local.api_permissions : key => permission
  }

  provisioner "local-exec" {
    command     = format("%s/scripts/grant_consent.sh", path.module)
    interpreter = ["/bin/bash"]
    on_failure  = fail

    environment = {
      resourceAppId  = self.triggers.resourceAppId
      appRoleId      = self.triggers.appRoleId
      principalId    = self.triggers.principalId
      application_id = self.triggers.application_id
    }
  }
}
