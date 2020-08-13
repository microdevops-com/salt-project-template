heartbeat_mesh:
  sender:
    cron: '*'
    config:
      enabled: True
      receivers:
        __HB_RECEIVER_HN__
          token: __HB_TOKEN__
