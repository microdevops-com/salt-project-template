heartbeat_mesh:
  sender:
    cron: '*'
    config:
      enabled: __MONITORING_ENABLED__
      receivers:
        __HB_RECEIVER_HN__:
          resource: {{ grains["id"] }}
          token: __HB_TOKEN__
