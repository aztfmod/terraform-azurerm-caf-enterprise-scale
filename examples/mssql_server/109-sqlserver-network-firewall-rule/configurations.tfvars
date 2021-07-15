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


# Vnets for network rule demonstration
vnets = {
  vnet1 = {
    resource_group_key = "rg1"
    vnet = {
      name          = "testvnet1"
      address_space = ["10.0.0.0/16"]
    }
    subnets = {
      web = {
        name              = "web-subnet"
        cidr              = ["10.0.1.0/24"]
        service_endpoints = ["Microsoft.Sql"] # Required for network rule application
      }
    }
  }
}


mssql_servers = {
  mssql_server1 = {
    name                          = "example-mssql-server"
    region                        = "region1"
    resource_group_key            = "rg1"
    version                       = "12.0"
    administrator_login           = "sqladmin"
    keyvault_key                  = "kv1"
    connection_policy             = "Default"
    public_network_access_enabled = true # true for firewall rule to be applied
    minimum_tls_version           = "1.2"

    firewall_rules = {
      firewall_rule1 = {
        name             = "firewallrule1"
        start_ip_address = "0.0.0.0"
        end_ip_address   = "0.0.0.0"
        # putting it to 0.0.0.0 enables the feature: Allow access to Azure services
      }
    }

    network_rules = {
      network_rule1 = {
        name       = "networkrule1"
        vnet_key   = "vnet1"
        subnet_key = "web"
        # lz_key = ""

        # subnet_id = ""
      }
    }

  }
}

mssql_databases = {
  mssql_db1 = {
    name               = "exampledb1"
    resource_group_key = "rg1"
    mssql_server_key   = "mssql_server1"
    license_type       = "LicenseIncluded"
    max_size_gb        = 4
    sku_name           = "BC_Gen5_2"

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


