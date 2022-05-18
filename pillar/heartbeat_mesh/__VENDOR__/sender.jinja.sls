heartbeat_mesh:
  sender:
    cron: '*'
    config:
{{ "{" }}%
if grains["id"] in [
{% for asset_fqdn, asset_licenses in asset_licenses["_self"].items() | sort(attribute="0") %}
{% if "monitoring" in asset_licenses and asset_dicts["_self"][asset_fqdn]["kind"] == "server" %}
"{{ asset_fqdn }}", 
{% endif %}
{% endfor %}
]" 
%{{ "}" }}
      enabled: __MONITORING_ENABLED__
{{ "{" }}% else %{{ "}" }}
      enabled: False
{{ "{" }}% endif %{{ "}" }}
      receivers:
        __HB_RECEIVER_HN__:
          token: __HB_TOKEN__
