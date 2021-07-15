global_settings = {
  default_region = "region1"
  regions = {
    region1 = "southeastasia"
  }
}

resource_groups = {
  networking_region1 = {
    name   = "mi-networking-re1"
    region = "region1"
  }
  sqlmi_region1 = {
    name   = "sqlmi-re1"
    region = "region1"
  }
}

vnets = {
  sqlmi_region1 = {
    resource_group_key = "networking_region1"
    vnet = {
      name          = "sqlmi-rg1"
      address_space = ["172.25.88.0/21"]
    }
    subnets = {
      sqlmi1 = {
        name            = "sqlmi1"
        cidr            = ["172.25.88.0/24"]
        nsg_key         = "sqlmi1"
        route_table_key = "sqlmi1"
        delegation = {
          name               = "sqlmidelegation"
          service_delegation = "Microsoft.Sql/managedInstances"
          actions = [
            "Microsoft.Network/virtualNetworks/subnets/join/action",
            "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
            "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
          ]
        }
      }
    }
  }
}

route_tables = {
  sqlmi1 = {
    name               = "sqlmi1"
    resource_group_key = "networking_region1"
  }
}

mssql_managed_instances = {
  sqlmi1 = {
    resource_group_key = "sqlmi_region1"
    name               = "lz-sql-mi"
    sku = {
      name = "GP_Gen5"
    }
    administratorLogin         = "adminuser"
    # administratorLoginPassword = "@dm1nu53r@30102020"

    //networking
    networking = {
      vnet_key   = "sqlmi_region1"
      subnet_key = "sqlmi1"
    }

    storageSizeInGB = 32
    vCores          = 8
  }
}

mssql_managed_databases = {
  managed_db1 = {
    resource_group_key = "sqlmi_region1"
    name               = "lz-sql-managed-db1"
    mi_server_key      = "sqlmi1"
  }
}

azuread_roles = {
  mssql_managed_instances = {
    sqlmi1 = {
      roles = [
        "Directory Readers"
      ]
    }
  }
}

azuread_groups = {
  sql_mi_admins = {
    name        = "sql-mi-admins"
    description = "Administrators of the SQL MI."
    members = {
      user_principal_names = []
      object_ids = [
      ]
      group_keys             = []
      service_principal_keys = []
    }
    owners = {
      user_principal_names = [
      ]
      service_principal_keys = []
      object_ids             = []
    }
    prevent_duplicate_name = false
  }
}

mssql_mi_administrators = {
  sqlmi1 = {
    resource_group_key = "sqlmi_region1"
    mi_server_key      = "sqlmi1"
    login              = "sqlmiadmin-khairi"
    azuread_group_key  = "sql_mi_admins"

    # group key or upn supported
    # user_principal_name = ""
  }
}