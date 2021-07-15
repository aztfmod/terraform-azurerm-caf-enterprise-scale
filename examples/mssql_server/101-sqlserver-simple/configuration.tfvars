global_settings = {
  default_region = "region1"
  environment    = "examples"
  regions = {
    region1 = "southeastasia"
  }
}

resource_groups = {
  sql_region1 = {
    name   = "sql-rg1"
    region = "region1"
  }
}

mssql_servers = {
  sql_rg1 = {
    name                = "sql-rg1"
    region              = "region1"
    resource_group_key  = "sql_region1"
    administrator_login = "sqladmin"
    keyvault_key        = "sql_rg1"
  }
}

keyvaults = {
  sql_rg1 = {
    name               = "sqlrg1"
    resource_group_key = "sql_region1"
    sku_name           = "standard"

    creation_policies = {
      logged_in_user = {
        secret_permissions = ["Set", "Get", "List", "Delete", "Purge"]
      }
    }
  }
}