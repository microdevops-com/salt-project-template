{{ "{" }}%
set env_per_server = {
{% for asset_fqdn, asset_dicts in asset_dicts["_self"].items() | sort(attribute="0") %}
{% if asset_dicts["kind"] == "server" %}
  "{{ asset_fqdn }}": "{{ asset_dicts["environment"] if "environment" in asset_dicts else "infra" }}",
{% endif %}
{% endfor %}
}
{{ "{" }}%
set location_per_server = {
{% for asset_fqdn, asset_dicts in asset_dicts["_self"].items() | sort(attribute="0") %}
{% if asset_dicts["kind"] == "server" %}
  "{{ asset_fqdn }}": "{{ asset_dicts["location"] if "location" in asset_dicts else "" }}",
{% endif %}
{% endfor %}
}
%{{ "}" }}
notify_devilry:
{{ "{" }}%
if grains["id"] in [
{% for asset_fqdn, asset_licenses in asset_licenses["_self"].items() | sort(attribute="0") %}
{% if "monitoring" in asset_licenses and asset_dicts["_self"][asset_fqdn]["kind"] == "server" %}
"{{ asset_fqdn }}",
{% endif %}
{% endfor %}
]
%{{ "}" }}
  config_file: salt://notify_devilry/__VENDOR__/notify_devilry.yaml
{{ "{" }}% else %{{ "}" }}
  config_file: salt://notify_devilry/__VENDOR__/notify_devilry_disabled.yaml
{{ "{" }}% endif %{{ "}" }}
  defaults:
    group: {{ "{{" }} grains["id"] {{ "}}" }}
    environment: {{ "{{" }} env_per_server[grains["id"]] if grains["id"] in env_per_server else "infra" {{ "}}" }}
    location: {{ "{{" }} location_per_server[grains["id"]] if grains["id"] in location_per_server else "" {{ "}}" }}
