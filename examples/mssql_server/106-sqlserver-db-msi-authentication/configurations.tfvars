global_settings = {
  default_region = "region1"
  regions = {
    region1 = "southeastasia"
  }
}


resource_groups = {
  rg1 = {
    name   = "example-sqldb"
    region = "region1"
  }
}

keyvaults = {
  kv1 = {
    name               = "examplekv"
    resource_group_key = "rg1"
    sku_name           = "standard"

    creation_policies = {
      logged_in_user = {
        secret_permissions = ["Set", "Get", "List", "Delete", "Purge"]
      }
    }
  }
}

managed_identities = {
  webapp_mi = {
    name               = "example_db_mi"
    resource_group_key = "rg1"
  }
}



azuread_groups = {
  sqlserver_admin = {
    name        = "example-sqlserver-admins"
    description = "Administrators of the sales SQL server."
    members = {
      user_principal_names = []

      # NOTE: To ensure DB users can be created, sqlserver admin needs to add the rover agent's system assigned identity object ID added
      # NOTE: since the authentication uses SQLCMD + DSN, UID cannot be supplied to the connection string, thus only system assigned identity is possible at this stage.
      object_ids = [
        # Add object id of rover agent with system assigned identity here.
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


mssql_servers = {
  mssqlserver1 = {
    name                = "example-mssqlserver"
    region              = "region1"
    resource_group_key  = "rg1"
    version             = "12.0"
    administrator_login = "sqluseradmin"
    keyvault_key        = "kv1"
    connection_policy   = "Default"

    public_network_access_enabled = true

    azuread_administrator = {

      azuread_group_key = "sqlserver_admin"
    }
    identity = {
      type = "SystemAssigned"
    }
  }
}

mssql_databases = {

  mssql_db1 = {
    name               = "exampledb1"
    resource_group_key = "rg1"
    mssql_server_key   = "mssqlserver1"
    license_type       = "LicenseIncluded"
    max_size_gb        = 4
    sku_name           = "BC_Gen5_2"

    # Only works with SystemAssigned MSI, logged_in users will not be able to provision the db_permission for now.
    db_permissions = {
      group1 = { # group_name
        db_roles = ["db_owner", "db_accessadmin"]
        managed_identities = {
          examples = { # lz_key
            managed_identity_keys = ["webapp_mi"]
          }
          # remote_mi = {
          #   managed_identity_keys = ["mi1"]
          # }
        }
      }
    }

  }
}

azuread_roles = {
  mssql_servers = {
    mssqlserver1 = {
      roles = ["Directory Readers"]
    }
  }
}
