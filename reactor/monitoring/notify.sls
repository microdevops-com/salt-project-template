{% set data_new = data.get('new')|join(', ')  %}
{% set data_lost = data.get('lost')|join(', ')  %}
monitoring_notify_telegram:
  local.state.sls:
    - tgt: 'telegram:central_notifier:True'
    - tgt_type: pillar
    - arg:
      - telegram.notify
    - kwarg:
        pillar:
          notify_message: 'master: {{ grains['id'] }}%0Atag: {{ tag }}%0Anew: {{ data_new }}%0Alost: {{ data_lost }}'
