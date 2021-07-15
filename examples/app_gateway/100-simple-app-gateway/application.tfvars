application_gateway_applications = {
  demo_app1_80 = {

    application_gateway_key = "agw1"
    name                    = "demoapp1"

    listeners = {
      private = {
        name                           = "demo-app1-80"
        front_end_ip_configuration_key = "private"
        front_end_port_key             = "80"
        host_name                      = "cafdemo.internal"
        request_routing_rule_key       = "default"
      }
    }

    request_routing_rules = {
      default = {
        rule_type = "Basic"
      }
    }

    backend_http_setting = {
      port                                = 443
      protocol                            = "Https"
      pick_host_name_from_backend_address = true
      probe_key                           = "probe_1"
    }

    backend_pool = {
      fqdns = [
        "cafdemo.appserviceenvironment.net"
      ]
    }

    probes = {
          probe_1 = {
              name                = "probe-backend-443"
              protocol            = "Https"
              path                = "/status-0123456789abcdef"
              host                = "cafdemo.appserviceenvironment.net"
              interval            = 30
              timeout             = 30
              unhealthy_threshold = 3
              match               = {
                  status_code = ["200-399"]
              }
          }
     }

  }
}