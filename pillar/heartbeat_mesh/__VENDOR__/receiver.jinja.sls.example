heartbeat_mesh:
  receiver:
    config:
      enabled: True
      clients:
{% for client_name, client_vars in clients.items() | sort(attribute="0") %}
{%   if "templates" in client_vars["configuration_management"] %}
        {{ client_name }}:
          token: {{ client_vars["configuration_management"]["templates"]["heartbeat_mesh"]["sender"]["token"] }}
          timeout: 1
{%     if not ("monitoring_disabled" in client_vars["configuration_management"]["templates"] and client_vars["configuration_management"]["templates"]["monitoring_disabled"]) %}
          resources:
{%       for asset_fqdn, asset_licenses in asset_licenses[client_name].items() | sort(attribute="0") %}
{%         if "monitoring" in asset_licenses and asset_dicts[client_name][asset_fqdn]["kind"] == "server" %}
            {{ asset_fqdn }}: {}
{%         endif %}
{%       endfor %}
{%     else %}
          resources: {}
{%     endif %}
{%   endif %}
{% endfor %}
