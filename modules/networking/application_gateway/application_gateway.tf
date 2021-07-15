resource "azurecaf_name" "agw" {
  name          = var.settings.name
  resource_type = "azurerm_application_gateway"
  prefixes      = var.global_settings.prefixes
  random_length = var.global_settings.random_length
  clean_input   = true
  passthrough   = var.global_settings.passthrough
  use_slug      = var.global_settings.use_slug
}

data "azurerm_key_vault_certificate" "trustedcas" {
  for_each = {
    for key, value in try(var.settings.trusted_root_certificate, {}) : key => value
    if try(value.keyvault_key, null) != null
  }
  name         = each.value.name
  key_vault_id = var.keyvaults[try(each.value.lz_key, var.client_config.landingzone_key)][each.value.keyvault_key].id
}

data "azurerm_key_vault_certificate" "manual_certs" {
  for_each = {
    for key, value in local.listeners : key => value
    if try(value.keyvault_certificate.certificate_name, null) != null
  }
  name         = each.value.keyvault_certificate.certificate_name
  key_vault_id = var.keyvaults[try(each.value.keyvault_certificate.lz_key, var.client_config.landingzone_key)][each.value.keyvault_certificate.keyvault_key].id
}

resource "azurerm_application_gateway" "agw" {
  name                = azurecaf_name.agw.result
  resource_group_name = var.resource_group_name
  location            = var.location

  zones              = try(var.settings.zones, null)
  enable_http2       = try(var.settings.enable_http2, true)
  tags               = try(local.tags, null)
  firewall_policy_id = try(try(var.application_gateway_waf_policies[try(var.settings.waf_policy.lz_key, var.client_config.landingzone_key)][var.settings.waf_policy.key].id, var.settings.firewall_policy_id), null)

  sku {
    name     = var.sku_name
    tier     = var.sku_tier
    capacity = try(var.settings.capacity.autoscale, null) == null ? var.settings.capacity.scale_unit : null
  }

  gateway_ip_configuration {
    name      = azurecaf_name.agw.result
    subnet_id = local.ip_configuration["gateway"].subnet_id
  }

  dynamic "ssl_policy" {
    for_each = try(var.settings.ssl_policy, null) == null ? [] : [1]
    content {
      disabled_protocols   = try(var.settings.ssl_policy.disabled_protocols, null)
      policy_type          = try(var.settings.ssl_policy.policy_type, null)
      policy_name          = try(var.settings.ssl_policy.policy_name, null)
      cipher_suites        = try(var.settings.ssl_policy.cipher_suites, null)
      min_protocol_version = try(var.settings.ssl_policy.min_protocol_version, null)
    }
  }

  dynamic "autoscale_configuration" {
    for_each = try(var.settings.capacity.autoscale, null) == null ? [] : [1]

    content {
      min_capacity = var.settings.capacity.autoscale.minimum_scale_unit
      max_capacity = var.settings.capacity.autoscale.maximum_scale_unit
    }
  }

  dynamic "frontend_ip_configuration" {
    for_each = var.settings.front_end_ip_configurations

    content {
      name                          = frontend_ip_configuration.value.name
      public_ip_address_id          = try(local.ip_configuration[frontend_ip_configuration.key].ip_address_id, null)
      private_ip_address            = try(frontend_ip_configuration.value.public_ip_key, null) == null ? local.private_ip_address : null
      private_ip_address_allocation = try(frontend_ip_configuration.value.private_ip_address_allocation, null)
      subnet_id                     = local.ip_configuration[frontend_ip_configuration.key].subnet_id
    }
  }

  dynamic "frontend_port" {
    for_each = var.settings.front_end_ports

    content {
      name = frontend_port.value.name
      port = frontend_port.value.port
    }
  }

  dynamic "http_listener" {
    for_each = local.listeners

    content {
      name                           = http_listener.value.name
      frontend_ip_configuration_name = var.settings.front_end_ip_configurations[http_listener.value.front_end_ip_configuration_key].name
      frontend_port_name             = var.settings.front_end_ports[http_listener.value.front_end_port_key].name
      protocol                       = var.settings.front_end_ports[http_listener.value.front_end_port_key].protocol
      host_name                      = try(trimsuffix((try(http_listener.value.host_names, null) == null ? try(var.dns_zones[try(http_listener.value.dns_zone.lz_key, var.client_config.landingzone_key)][http_listener.value.dns_zone.key].records[0][http_listener.value.dns_zone.record_type][http_listener.value.dns_zone.record_key].fqdn, http_listener.value.host_name) : null), "."), null)
      host_names                     = try(http_listener.value.host_name, null) == null ? try(http_listener.value.host_names, null) : null
      require_sni                    = try(http_listener.value.require_sni, false)
      ssl_certificate_name           = try(try(try(http_listener.value.keyvault_certificate_request.key, http_listener.value.keyvault_certificate.certificate_key), data.azurerm_key_vault_certificate.manual_certs[http_listener.key].name), null)
      firewall_policy_id             = try(var.application_gateway_waf_policies[try(http_listener.value.waf_policy.lz_key, var.client_config.landingzone_key)][http_listener.value.waf_policy.key].id, null)
    }
  }

  dynamic "request_routing_rule" {
    for_each = local.listeners

    content {
      name                       = "${try(local.request_routing_rules[format("%s-%s", request_routing_rule.value.app_key, request_routing_rule.value.request_routing_rule_key)].rule.prefix, "")}${request_routing_rule.value.name}"
      rule_type                  = try(local.request_routing_rules[format("%s-%s", request_routing_rule.value.app_key, request_routing_rule.value.request_routing_rule_key)].rule.rule_type, "Basic")
      http_listener_name         = request_routing_rule.value.name
      backend_http_settings_name = local.backend_http_settings[request_routing_rule.value.app_key].name
      backend_address_pool_name  = local.backend_pools[request_routing_rule.value.app_key].name
      url_path_map_name = try(local.request_routing_rules[format("%s-%s", request_routing_rule.value.app_key, request_routing_rule.value.request_routing_rule_key)].rule.url_path_map_name, try(local.url_path_maps[format("%s-%s", request_routing_rule.value.app_key,
      local.request_routing_rules[format("%s-%s", request_routing_rule.value.app_key, request_routing_rule.value.request_routing_rule_key)].rule.url_path_map_key)].name, null))


    }
  }

  dynamic "url_path_map" {
    for_each = try(local.url_path_maps)
    content {
      default_backend_address_pool_name  = try(url_path_map.value.default_backend_address_pool_name, var.application_gateway_applications[url_path_map.value.app_key].name)
      default_backend_http_settings_name = try(url_path_map.value.default_backend_http_settings_name, var.application_gateway_applications[url_path_map.value.app_key].name)
      name                               = url_path_map.value.name

      dynamic "path_rule" {
        for_each = try(url_path_map.value.path_rules, [])

        content {
          backend_address_pool_name  = try(var.application_gateway_applications[path_rule.value.backend_pool.app_key].name, var.application_gateway_applications[path_rule.value.backend_pool.app_key].name)
          backend_http_settings_name = try(var.application_gateway_applications[path_rule.value.backend_http_setting.app_key].name, var.application_gateway_applications[url_path_map.value.app_key].name)
          name                       = path_rule.value.name
          paths                      = path_rule.value.paths
        }
      }
    }
  }
  dynamic "probe" {
    for_each = try(local.probes)

    content {
      name                                      = probe.value.name
      host                                      = probe.value.host
      interval                                  = probe.value.interval
      protocol                                  = probe.value.protocol
      path                                      = probe.value.path
      timeout                                   = probe.value.timeout
      unhealthy_threshold                       = probe.value.unhealthy_threshold
      port                                      = try(probe.value.port,null)
      pick_host_name_from_backend_http_settings = try(probe.value.pick_host_name_from_backend_http_settings, false)
      minimum_servers                           = try(probe.value.minimum_servers, 0)
      dynamic "match" {
        for_each = try(probe.value.match, null) == null ? [] : [1]
        content {
          body        = try(probe.value.match.body,null)
          status_code = try(probe.value.match.status_code,null)
        }
      }
    }
  }

  dynamic "backend_http_settings" {
    for_each = local.backend_http_settings

    content {
      name                                = var.application_gateway_applications[backend_http_settings.key].name
      cookie_based_affinity               = try(backend_http_settings.value.cookie_based_affinity, "Disabled")
      port                                = backend_http_settings.value.port
      protocol                            = backend_http_settings.value.protocol
      request_timeout                     = try(backend_http_settings.value.request_timeout, 30)
      pick_host_name_from_backend_address = try(backend_http_settings.value.pick_host_name_from_backend_address, false)
      trusted_root_certificate_names      = try(backend_http_settings.value.trusted_root_certificate_names, null)
      host_name                           = try(backend_http_settings.value.host_name, null)
      probe_name                          = try(local.probes[format("%s-%s",backend_http_settings.key, backend_http_settings.value.probe_key)].name, null)
    }
  }

  dynamic "backend_address_pool" {
    for_each = local.backend_pools

    content {
      name         = var.application_gateway_applications[backend_address_pool.key].name
      fqdns        = try(backend_address_pool.value.fqdns, null)
      ip_addresses = try(backend_address_pool.value.ip_addresses, null)
    }
  }

  dynamic "identity" {
    for_each = try(var.settings.identity, null) == null ? [] : [1]

    content {
      type         = "UserAssigned"
      identity_ids = local.managed_identities
    }

  }

  # authentication_certificate {

  # }



  dynamic "trusted_root_certificate" {
    for_each = {
      for key, value in try(var.settings.trusted_root_certificate, {}) : key => value
    }
    content {
      name = trusted_root_certificate.value.name
      data = try(trusted_root_certificate.value.data, data.azurerm_key_vault_certificate.trustedcas[trusted_root_certificate.key].certificate_data_base64)
    }
  }


  # ssl_policy {

  # }

  # probe {

  # }

  dynamic "ssl_certificate" {
    for_each = try(local.certificate_keys)

    content {
      name                = ssl_certificate.value
      key_vault_secret_id = var.keyvault_certificates[ssl_certificate.value].secret_id
      # data     = try(ssl_certificate.value.key_vault_secret_id, null) == null ? ssl_certificate.value.data : null
      # password = try(ssl_certificate.value.data, null) != null ? ssl_certificate.value.password : null
    }
  }

  dynamic "ssl_certificate" {
    for_each = try(local.certificate_request_keys)

    content {
      name                = ssl_certificate.value
      key_vault_secret_id = var.keyvault_certificate_requests[ssl_certificate.value].secret_id
    }
  }

  dynamic "ssl_certificate" {
    for_each = try(data.azurerm_key_vault_certificate.manual_certs)

    content {
      name                = ssl_certificate.value.name
      key_vault_secret_id = ssl_certificate.value.secret_id
    }
  }
  
  dynamic "waf_configuration" {
    for_each = try(var.settings.waf_configuration, null) == null ? [] : [1]
    content {
      enabled                   = var.settings.waf_configuration.enabled
      firewall_mode             = var.settings.waf_configuration.firewall_mode
      rule_set_type             = var.settings.waf_configuration.rule_set_type
      rule_set_version          = var.settings.waf_configuration.rule_set_version
      file_upload_limit_mb      = try(var.settings.waf_configuration.file_upload_limit_mb, 100)
      request_body_check        = try(var.settings.waf_configuration.request_body_check, true)
      max_request_body_size_kb  = try(var.settings.waf_configuration.max_request_body_size_kb, 128)
      dynamic "disabled_rule_group" {
        for_each = try(var.settings.waf_configuration.disabled_rule_groups, {})
        content {
          rule_group_name       = disabled_rule_group.value.rule_group_name
          rules                 = try(disabled_rule_group.value.rules,null)
        }
      }
      dynamic "exclusion" {
        for_each = try(var.settings.waf_configuration.exclusions, {})
        content {
          match_variable          = exclusion.value.match_variable
          selector_match_operator = try(exclusion.value.selector_match_operator,null)
          selector                = try(exclusion.value.selector,null)
        }
      }
    }
  }

  # custom_error_configuration {}

  # redirect_configuration {}

  # autoscale_configuration {}

  # rewrite_rule_set {}


}

output "certificate_keys" {
  value = local.certificate_keys
}