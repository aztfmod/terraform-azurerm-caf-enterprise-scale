locals {
  backend_http_settings = {
    for key, value in var.application_gateway_applications : key => merge({ name = value.name }, value.backend_http_setting)
    if lookup(value, "backend_http_setting", false) != false
  }

  listeners = {
    for listener in
    flatten(
      [
        for app_key, config in var.application_gateway_applications : [
          for listener_key, value in try(config.listeners, []) : {
            listener_key = listener_key
            app_key      = app_key
            value        = merge({ app_key = app_key }, value)
          }
        ]
      ]
    ) : format("%s-%s", listener.app_key, listener.listener_key) => listener.value
  }

  request_routing_rules = {
    for request_routing_rule in
    flatten(
      [
        for app_key, config in var.application_gateway_applications : [
          for request_key, value in try(config.request_routing_rules, []) : {
            name        = config.name
            request_key = request_key
            app_key     = app_key
            rule        = value
          }
        ]
      ]
    ) : format("%s-%s", request_routing_rule.app_key, request_routing_rule.request_key) => request_routing_rule
  }

  url_path_maps = {
    for url_path_map in
    flatten(
      [
        for app_key, config in var.application_gateway_applications : [
          for key, value in try(config.url_path_maps, []) : {
            value = merge({ app_key = app_key, url_path_map_key = key }, value)
          }
        ]
      ]
    ) : format("%s-%s", url_path_map.value.app_key, url_path_map.value.url_path_map_key) => url_path_map.value
  }

  probes = {
    for probe in
    flatten(
      [
        for app_key, config in var.application_gateway_applications : [
          for key, value in try(config.probes, []) : {
            value = merge({ app_key = app_key, probe_key = key }, value)
          }
        ]
      ]
    ) : format("%s-%s", probe.value.app_key, probe.value.probe_key) => probe.value
  }

  certificate_keys = distinct(flatten([
    for key, value in local.listeners : [try(value.keyvault_certificate.certificate_key, [])]
  ]))

  certificate_request_keys = distinct(flatten([
    for key, value in local.listeners : [try(value.keyvault_certificate_request.key, [])]
  ]))
}