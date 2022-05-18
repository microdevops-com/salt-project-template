notify_devilry:
{{ "{" }}%
if grains["id"] in [
{% for asset_fqdn, asset_licenses in asset_licenses["_self"].items() | sort(attribute="0") %}
{% if "monitoring" in asset_licenses and asset_dicts["_self"][asset_fqdn]["kind"] == "server" %}
"{{ asset_fqdn }}", 
{% endif %}
{% endfor %}
]" 
%{{ "}" }}
  config_file: salt://notify_devilry/__VENDOR__/notify_devilry.yaml
{{ "{" }}% else %{{ "}" }}
  config_file: salt://notify_devilry/__VENDOR__/notify_devilry_disabled.yaml
{{ "{" }}% endif %{{ "}" }}
