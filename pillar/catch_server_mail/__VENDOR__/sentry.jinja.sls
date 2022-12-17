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
