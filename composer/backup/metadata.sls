{%- from 'composer/map.jinja' import postgres, composer %}

{%- if composer.backup['destination'] and composer.backup['services'] -%}

  {%- set backup_dir = salt['file.join'](composer.backup['destination'],
                                         salt['grains.get']('composer:backup:latest', 'latest')) %}
composer_backup_compressor:
  pkg.installed:
    - name: {{ composer.backup['compressor'] }}
    - onchanges:
      - file: composer_backup_dir

  {%- for service in composer.backup['services'] %}
    {#- Read service config to retrieve DB connection details later #}
    {%- set config = composer.local.config.get(service, {}).properties|
                     default({}, true) %}

{# Detect if the service configured for backup would be upgraded
during ``composer.services`` SLS run. This will trigger the backup process.
Nothing would happen if nothing to upgrade.
If called directly as ``state.apply composer.backup``, always do the backup. #}

    {%- for properties in postgres['composer_properties'] %}
      {#- The full set of properties: url, user and pw need to be configured #}
      {%- set has_properties = [true] %}
      {%- for property in properties %}
        {%- if property not in config %}
          {%- do has_properties.append(false) %}
        {%- endif %}
      {%- endfor %}

      {%- if has_properties|last %}
        {%- set connection_uri = config[properties[0]]|replace('jdbc:', '', 1) %}
        {%- set database = connection_uri.split('/')|last %}
        {%- set user = config[properties[1]] %}
        {%- set password = config[properties[2]] %}

        {#- Backup all DBs configured for the service,
           or only those which explicitly defined. #}
        {%- if composer.backup['databases']|default(none) == [] or
               database in composer.backup['databases']|default([], true) %}

{{ database }}_db_backup:
  cmd.run:
    - name: >-
        {{ composer.backup['bin'] }}
        {{ connection_uri }} |
        {{ composer.backup['compressor'] }}
        --stdout {{ composer.backup['comp_opts'] }} >
        {{ salt['file.join'](backup_dir, database ~ composer.backup['comp_ext']) }}
    - env:
      - PGUSER: {{ user|yaml() }}
      - PGPASSWORD: {{ password|yaml() }}
    # Files should be owned by user
    # who would be able to read them on restoration.
    - runas: {{ composer.restore['user'] }}
    - require:
      - pkg: composer_backup_compressor
    - onchanges:
      - file: composer_backup_dir
    # Stop highstate execution if backup has failed
    - failhard: True

        {%- endif %}
      {%- endif %}
    {%- endfor %}
  {%- endfor %}
{%- endif %}
