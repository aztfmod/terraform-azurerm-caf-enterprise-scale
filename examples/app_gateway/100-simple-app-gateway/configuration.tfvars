global_settings = {
  default_region = "region1"
  regions = {
    region1 = "southeastasia"
  }
}


resource_groups = {
  agw_region1 = {
    name   = "example-agw"
    region = "region1"
  }
}

application_gateways = {
  agw1 = {
    resource_group_key = "agw_region1"
    name               = "app_gateway_example"
    vnet_key           = "vnet_region1"
    subnet_key         = "app-gateway-subnet"
    sku_name           = "WAF_v2"
    sku_tier           = "WAF_v2"
    capacity = {
      autoscale = {
        minimum_scale_unit = 0
        maximum_scale_unit = 10
      }
    }
    zones        = ["1"]
    enable_http2 = true

    front_end_ip_configurations = {
      public = {
        name          = "public"
        public_ip_key = "example_agw_pip1_rg1"
      }
      private = {
        name                          = "private"
        vnet_key                      = "vnet_region1"
        subnet_key                    = "app-gateway-subnet"
        subnet_cidr_index             = 0 # It is possible to have more than one cidr block per subnet
        private_ip_offset             = 4 # e.g. cidrhost(10.10.0.0/25,4) = 10.10.0.4 => AGW private IP address
        private_ip_address_allocation = "Static"
      }
    }

    front_end_ports = {
      80 = {
        name     = "http"
        port     = 80
        protocol = "Http"
      }
      443 = {
        name     = "https"
        port     = 443
        protocol = "Https"
      }
    }

    waf_configuration = {
      enabled = true
      firewall_mode = "Prevention"  # or Detection
      rule_set_type = "OWASP"       # OWASP
      rule_set_version = "3.1"      # OWASP(2.2.9, 3.0, 3.1, 3.2)
      file_upload_limit_mb = 100
      request_body_check      = true
      max_request_body_size_kb = 128

      # Optional
      disabled_rule_groups = {
        general = {
          rule_group_name = "General"
          rules = ["200004"]
        }
        # Disable a spacific rule in the rule group
        REQUEST-913-SCANNER-DETECTION = {
          rule_group_name = "REQUEST-913-SCANNER-DETECTION"
          rules = ["913102"]
        }
        # Disable all rule in the rule group
        REQUEST-930-APPLICATION-ATTACK-LFI = {
          rule_group_name = "REQUEST-930-APPLICATION-ATTACK-LFI"
        }
      }
      
      # Optional
      exclusions = {
        exc1 = {
          match_variable = "RequestHeaderNames"
          selector_match_operator = "Equals"      # StartsWith, EndsWith, Contains
          selector = "SomeHeader"
        }
      }
    }

  }
}

vnets = {
  vnet_region1 = {
    resource_group_key = "agw_region1"
    vnet = {
      name          = "app_gateway_vnet"
      address_space = ["10.100.100.0/24"]
    }
    specialsubnets = {}
    subnets = {
      app-gateway-subnet = {
        name    = "app_gateway_subnet"
        cidr    = ["10.100.100.0/25"]
        nsg_key = "application_gateway"
      }
    }

  }
}

public_ip_addresses = {
  example_agw_pip1_rg1 = {
    name                    = "example_agw_pip1"
    resource_group_key      = "agw_region1"
    sku                     = "Standard"
    allocation_method       = "Static"
    ip_version              = "IPv4"
    availability_zone       = "1"
    idle_timeout_in_minutes = "4"

  }
}