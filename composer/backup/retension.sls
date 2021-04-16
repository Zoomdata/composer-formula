{%- from 'composer/map.jinja' import composer %}

{%- if composer.backup['destination'] and composer.backup['retention'] %}

composer_backup_retension:
  file.retention_schedule:
    - name: {{ composer.backup['destination'] }}
    - retain:
        most_recent: {{ composer.backup['retention'] }}
    - strptime_format: {{ composer.backup['strptime']|yaml() }}
    {%- if not composer['bootstrap'] and (
           composer.backup['state'] or composer.backup['services']) %}
    # Subscribe on changes only when any backup type is going to be made
    - onchanges:
      - file: composer_backup_dir
    {%- else %}
    # FIXME: the state is really not stateful
    - onlyif: test -d "{{ composer.backup['destination'] }}"
    {%- endif %}

{%- endif %}
