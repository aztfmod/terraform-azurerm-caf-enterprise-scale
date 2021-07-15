global_settings = {
  default_region = "region1"
  regions = {
    region1 = "southeastasia" # You can adjust the Azure Region you want to use to deploy NAT Gateway
    # region2 = "eastasia"            # Optional - Add additional regions
  }
}
resource_groups = {
  nat_gateway_re1 = {
    name   = "nat_gateway_re1"
    region = "region1"
  }
}

vnets = {
  vnet_nat_gateway_re1 = {
    resource_group_key = "nat_gateway_re1"
    region             = "region1"
    vnet = {
      name          = "vnet_nat_gateway_re1"
      address_space = ["10.100.80.0/22"]
    }
    subnets = {
      subnet1 = {
        name = "subnet1"
        cidr = ["10.100.81.0/24"]
      }
    } //subnets

    specialsubnets = {}

  }
} //vnets

public_ip_addresses = {

  public_ip_nat_gateway1 = {
    name                    = "public_ip_nat_gateway1"
    region                  = "region1"
    resource_group_key      = "nat_gateway_re1"
    sku                     = "Standard"
    allocation_method       = "Static"
    ip_version              = "IPv4"
    idle_timeout_in_minutes = "4"
  }
}

nat_gateways = {
  nat_gateway1 = {
     name = "nat_gateway1"
     region = "region1" #we need to use the CAF regions rather than using location value
     idle_timeout_in_minutes = 10 #optional if not defined will default to 4 minutes
     #zones                   = ["1"] #optional need to match public ip zone
     #vnet_key = "vnet_nat_gateway_re1"
     resource_group_key = "nat_gateway_re1"
    }

  nat_gateway2 = {
     name = "nat_gateway2"
     region = "region1" #we need to use the CAF regions rather than using location value
     idle_timeout_in_minutes = 10 #optional if not defined will default to 4 minutes
     #zones                   = ["1"] #optional need to match public ip zone
     vnet_key = "vnet_nat_gateway_re1"
     subnet_key = "subnet1"
     public_ip_key = "public_ip_nat_gateway1"
     resource_group_key = "nat_gateway_re1"
  }
}