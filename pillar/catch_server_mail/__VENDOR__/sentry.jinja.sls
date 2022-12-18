{{ "{" }}%
set env_per_server = {
{% for asset_fqdn, asset_dicts in asset_dicts["_self"].items() | sort(attribute="0") %}
{% if asset_dicts["kind"] == "server" %}
  "{{ asset_fqdn }}": "{{ asset_dicts["environment"] if "environment" in asset_dicts else "infra" }}",
{% endif %}
{% endfor %}
}
%{{ "}" }}
{{ "{" }}%
set location_per_server = {
{% for asset_fqdn, asset_dicts in asset_dicts["_self"].items() | sort(attribute="0") %}
{% if asset_dicts["kind"] == "server" %}
  "{{ asset_fqdn }}": "{{ asset_dicts["location"] if "location" in asset_dicts else "" }}",
{% endif %}
{% endfor %}
}
%{{ "}" }}
{{ "{" }}%
set description_per_server = {
{% for asset_fqdn, asset_dicts in asset_dicts["_self"].items() | sort(attribute="0") %}
{% if asset_dicts["kind"] == "server" %}
  "{{ asset_fqdn }}": "{{ asset_dicts["description"] if "description" in asset_dicts else "" }}",
{% endif %}
{% endfor %}
}
%{{ "}" }}
catch_server_mail:
{{ "{" }}%
if grains["id"] in [
{% for asset_fqdn, asset_licenses in asset_licenses["_self"].items() | sort(attribute="0") %}
{% if "monitoring" in asset_licenses and asset_dicts["_self"][asset_fqdn]["kind"] == "server" %}
"{{ asset_fqdn }}",
{% endif %}
{% endfor %}
]
%{{ "}" }}
  enabled: __MONITORING_ENABLED__
{{ "{" }}% else %{{ "}" }}
  enabled: False
{{ "{" }}% endif %{{ "}" }}
  sentry:
    all_users: True
    domain: __SENTRY_DOMAIN__
    org-slug: __CLIENT__
    project-slug: server_mail
    auth_token: __SENTRY_AUTH_TOKEN__
    dsn_public: __SENTRY_DSN_PUBLIC__
    environment: {{ "{{" }} env_per_server[grains["id"]] if grains["id"] in env_per_server else "infra" {{ "}}" }}
    location: {{ "{{" }} location_per_server[grains["id"]] if grains["id"] in location_per_server else "" {{ "}}" }}
    description: {{ "{{" }} description_per_server[grains["id"]] if grains["id"] in description_per_server else "" {{ "}}" }}
