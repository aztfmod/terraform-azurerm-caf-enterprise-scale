module "custom_roles" {
  source   = "./modules/roles/custom_roles"
  for_each = var.custom_role_definitions

  global_settings      = local.global_settings
  subscription_primary = data.azurerm_subscription.primary.id
  custom_role          = each.value
}

#
# Roles assignments
#
# Require the modules output an rbac_id that is set to the principal_id
#

resource "azurerm_role_assignment" "for" {
  for_each = try(local.roles_to_process, {})

  scope                = local.services_roles[each.value.scope_resource_key][var.current_landingzone_key][each.value.scope_key_resource].id
  role_definition_name = each.value.mode == "built_in_role_mapping" ? each.value.role_definition_name : null
  role_definition_id   = each.value.mode == "custom_role_mapping" ? module.custom_roles[each.value.role_definition_name].role_definition_resource_id : null
  principal_id         = each.value.object_id_resource_type == "object_ids" ? each.value.object_id_key_resource : try(local.services_roles[each.value.object_id_resource_type][each.value.lz_key][each.value.object_id_key_resource].rbac_id, local.services_roles[each.value.object_id_resource_type][var.current_landingzone_key][each.value.object_id_key_resource].rbac_id)

  lifecycle {
    ignore_changes = [
      principal_id
    ]

    create_before_destroy = true
  }

}

data "azurerm_management_group" "level" {
  for_each = {
    for key, value in try(var.role_mapping.built_in_role_mapping.management_group, {}) : key => value
  }

  name = lower(each.key) == "root" ? data.azurerm_client_config.current.tenant_id : each.key
}

locals {

  management_groups = tomap(
    {
      (var.current_landingzone_key) = {
        for key, value in try(var.role_mapping.built_in_role_mapping.management_group, {}) :
        key => {
          id = data.azurerm_management_group.level[key].id
        }
      }
    }
  )

  services_roles = {
    aks_clusters                = local.combined_objects_aks_clusters
    app_config                  = local.combined_objects_app_config
    app_service_environments    = local.combined_objects_app_service_environments
    app_service_plans           = local.combined_objects_app_service_plans
    app_services                = local.combined_objects_app_services
    availability_sets           = local.combined_objects_availability_sets
    azure_container_registries  = local.combined_objects_azure_container_registries
    azuread_applications        = local.combined_objects_azuread_applications
    azuread_apps                = local.combined_objects_azuread_apps
    azuread_groups              = local.combined_objects_azuread_groups
    azuread_service_principals  = local.combined_objects_azuread_service_principals
    azuread_users               = local.combined_objects_azuread_users
    azurerm_firewalls           = local.combined_objects_azurerm_firewalls
    dns_zones                   = local.combined_objects_dns_zones
    event_hub_namespaces        = local.combined_objects_event_hub_namespaces
    keyvaults                   = local.combined_objects_keyvaults
    logged_in                   = local.logged_in
    machine_learning_workspaces = local.combined_objects_machine_learning
    managed_identities          = local.combined_objects_managed_identities
    management_group            = local.management_groups
    mssql_databases             = local.combined_objects_mssql_databases
    mssql_elastic_pools         = local.combined_objects_mssql_elastic_pools
    mssql_managed_databases     = local.combined_objects_mssql_managed_databases
    mssql_managed_instances     = local.combined_objects_mssql_managed_instances
    mssql_servers               = local.combined_objects_mssql_servers
    mysql_servers               = local.combined_objects_mysql_servers
    network_watchers            = local.combined_objects_network_watchers
    networking                  = local.combined_objects_networking
    postgresql_servers          = local.combined_objects_postgresql_servers
    private_dns                 = local.combined_objects_private_dns
    proximity_placement_groups  = local.combined_objects_proximity_placement_groups
    public_ip_addresses         = local.combined_objects_public_ip_addresses
    recovery_vaults             = local.combined_objects_recovery_vaults
    resource_groups             = local.combined_objects_resource_groups
    storage_accounts            = local.combined_objects_storage_accounts
    subscriptions               = local.combined_objects_subscriptions
    synapse_workspaces          = local.combined_objects_synapse_workspaces
  }


  logged_in = tomap(
    {
      (var.current_landingzone_key) = {
        user = {
          rbac_id = local.client_config.logged_user_objectId
        }
        app = {
          rbac_id = local.client_config.logged_aad_app_objectId
        }
      }
    }
  )

  roles_to_process = {
    for mapping in
    flatten(
      [                                                                 # Variable
        for key_mode, all_role_mapping in var.role_mapping : [          #  built_in_role_mapping = {
          for key, role_mappings in all_role_mapping : [                #       aks_clusters = {
            for scope_key_resource, role_mapping in role_mappings : [   #         seacluster = {
              for role_definition_name, resources in role_mapping : [   #           "Azure Kubernetes Service Cluster Admin Role" = {
                for object_id_key, object_resources in resources : [    #             azuread_group_keys = {
                  for object_id_key_resource in object_resources.keys : #               keys = [ "aks_admins" ] ----End of variable
                  {                                                     # "seacluster_Azure_Kubernetes_Service_Cluster_Admin_Role_aks_admins" = {
                    mode                    = key_mode                  #   "mode" = "built_in_role_mapping"
                    scope_resource_key      = key
                    scope_key_resource      = scope_key_resource
                    role_definition_name    = role_definition_name
                    object_id_resource_type = object_id_key
                    object_id_key_resource  = object_id_key_resource #   "object_id_key_resource" = "aks_admins"
                    lz_key                  = try(object_resources.lz_key, null)
                  } if(object_id_key != "logged_in") || (object_id_key_resource == "user" && local.client_config.logged_user_objectId != null)
                  || (object_id_key_resource == "app" && local.client_config.logged_aad_app_objectId != null)
                ]
              ]
            ]
          ]
        ]
      ]
    ) : format("%s_%s_%s_%s", mapping.object_id_resource_type, mapping.scope_key_resource, replace(mapping.role_definition_name, " ", "_"), mapping.object_id_key_resource) => mapping
  }
}

# The code transform this input format to
#   custom_role_mapping = {
#     subscription_keys = {
#       logged_in_subscription = {
#         "caf-launchpad-contributor" = {
#           azuread_group_keys = [
#             "keyvault_level0_rw", "keyvault_level1_rw", "keyvault_level2_rw", "keyvault_level3_rw", "keyvault_level4_rw",
#           ]
#           managed_identity_keys = [
#             "level0", "level1", "level2", "level3", "level4"
#           ]
#         }
#       }
#     }
#   }

#  built_in_role_mapping = {
#       aks_clusters = {
#         seacluster = {
#           "Azure Kubernetes Service Cluster Admin Role" = {
#             azuread_group_keys = {
#               keys = [ "aks_admins" ]
#             }
#             managed_identity_keys = {
#               keys = [ "jumpbox" ]
#             }
#           }
#         }
#       }
#       azure_container_registries = {
#         acr1 = {
#           "AcrPull" = {
#             aks_cluster_keys = {
#               keys = [ "seacluster" ]
#             }
#           }
#         }
#       }
#       storage_accounts = {
#         scripts_region1 = {
#           "Storage Blob Data Contributor" = {
#             logged_in = {
#               keys = [ "user" ]
#             }
#             managed_identities = {
#               lz_key = "launchpad"
#               keys = [ "level0", "level1" ]
#             }
#           }
#         }
#       }
#     }
# ......

## Generates a transformed structure for azurerm_role_assignment to process
# built_in_roles = {
# "acr1_AcrPull_seacluster" = {
#   "mode" = "built_in_role_mapping"
#   "object_id_key_resource" = "seacluster"
#   "object_id_resource_type" = "aks_cluster_keys"
#   "role_definition_name" = "AcrPull"
#   "scope_key_resource" = "acr1"
#   "scope_resource_key" = "azure_container_registries"
# }
# "scripts_region1_Storage_Blob_Data_Contributor_level0" = {
#   "lz_key" = "launchpad"
#   "mode" = "built_in_role_mapping"
#   "object_id_key_resource" = "level0"
#   "object_id_resource_type" = "managed_identities"
#   "role_definition_name" = "Storage Blob Data Contributor"
#   "scope_key_resource" = "scripts_region1"
#   "scope_resource_key" = "storage_accounts"
# }
# "scripts_region1_Storage_Blob_Data_Contributor_level1" = {
#   "lz_key" = "launchpad"
#   "mode" = "built_in_role_mapping"
#   "object_id_key_resource" = "level1"
#   "object_id_resource_type" = "managed_identities"
#   "role_definition_name" = "Storage Blob Data Contributor"
#   "scope_key_resource" = "scripts_region1"
#   "scope_resource_key" = "storage_accounts"
# }
# "scripts_region1_Storage_Blob_Data_Contributor_user" = {
#   "mode" = "built_in_role_mapping"
#   "object_id_key_resource" = "user"
#   "object_id_resource_type" = "logged_in"
#   "role_definition_name" = "Storage Blob Data Contributor"
#   "scope_key_resource" = "scripts_region1"
#   "scope_resource_key" = "storage_accounts"
# }
# "seacluster_Azure_Kubernetes_Service_Cluster_Admin_Role_aks_admins" = {
#   "mode" = "built_in_role_mapping"
#   "object_id_key_resource" = "aks_admins"
#   "object_id_resource_type" = "azuread_group_keys"
#   "role_definition_name" = "Azure Kubernetes Service Cluster Admin Role"
#   "scope_key_resource" = "seacluster"
#   "scope_resource_key" = "aks_clusters"
# }
# "seacluster_Azure_Kubernetes_Service_Cluster_Admin_Role_jumpbox" = {
#   "mode" = "built_in_role_mapping"
#   "object_id_key_resource" = "jumpbox"
#   "object_id_resource_type" = "managed_identity_keys"
#   "role_definition_name" = "Azure Kubernetes Service Cluster Admin Role"
#   "scope_key_resource" = "seacluster"
#   "scope_resource_key" = "aks_clusters"
# }
# .......
