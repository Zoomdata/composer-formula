{%- from 'composer/map.jinja' import composer %}

{%- if composer.backup['destination'] and composer.backup['state'] -%}
  {%- set backup_dir = salt['file.join'](composer.backup['destination'],
                                         salt['grains.get']('composer:backup:latest', 'latest')) %}
  {%- set state_file = composer.backup['state'] ~ '.sls' %}
  {%- do composer.local.update({'backup': composer.backup}) %}
  {%- do composer.restore.update({'dir': backup_dir}) %}
  {%- do composer.local.update({'restore': composer.restore}) %}

composer_dump_state:
  file.serialize:
    - name: {{ salt['file.join'](backup_dir, state_file) }}
    - dataset: {{ {'composer': composer.local}|yaml() }}
    - formatter: yaml
    - user: root
    - group: root
    # Will contain passwords!
    - mode: "0600"
    # FIXME: subscribe on changes in repository settings
    - onchanges:
      - file: composer_backup_dir

{%- endif %}
