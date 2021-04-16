{%- from 'composer/map.jinja' import composer %}

{%- if composer.backup['destination'] and (
       composer.backup['state'] or composer.backup['services']) %}

  {%- set timestamp = salt['status.time'](composer.backup['strptime']) %}
  {%- do salt['grains.set']('composer:backup:latest', timestamp) %}
  {%- set backup_dir = salt['file.join'](composer.backup['destination'], timestamp) %}
  {%- set state_file = composer.backup['state'] ~ '.sls' %}

composer_backup_dir:
  file.directory:
    - name: {{ backup_dir }}
    - user: root
    - group: {{ composer.restore['user']|default('root', true) }}
    - mode: "0775"
    - makedirs: True

composer_backup_latest:
  file.symlink:
    - name: {{ salt['file.join'](composer.backup['destination'], 'latest') }}
    - target: {{ timestamp|yaml() }}
    - force: True
    - onchanges:
      - file: composer_backup_dir

composer_dump_readme:
  file.managed:
    - name: {{ salt['file.join'](composer.backup['destination'], 'README') }}
    - contents: |
        This directory contains Composer databases and state backups. If there
        is a file called {{ state_file }} in any of subdirectories, you may
        copy it to the Salt Pillar directory (usually at /srv/pillar/composer)
        on Salt Master or Salt Masterless Minion and optionally edit the Pillar
        top file (/srv/pillar/top.sls) to enable it. That would allow to do
        full restoration of backed up Composer installation including package
        versions and running services by executing command

          sudo salt-call state.apply composer.restore

        on target host.
    - user: root
    - group: root
    - mode: "0644"
    - onchanges:
      - file: composer_backup_dir

{%- endif %}
