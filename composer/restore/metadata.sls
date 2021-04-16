{%- from 'composer/map.jinja' import composer, postgres with context %}

{%- if composer.restore['dir']
   and (not postgres['connection_uri']
        or (postgres['connection_uri'] and postgres['password'])
       ) %}

include:
  - composer.services.stop

  {%- for service in composer.backup['services'] %}
    {%- set config = composer.config.get(service, {}).properties|
                     default({}, true) %}

    {%- for properties in postgres.composer_properties %}
      {#- The full set of properties: url, user and pw need to be configured #}
      {%- set has_properties = [true] %}
      {%- for property in properties %}
        {%- if property not in config %}
          {%- do has_properties.append(false) %}
        {%- endif %}
      {%- endfor %}

      {%- if has_properties|last() %}
        {%- set user = config[properties[1]] %}
        {%- set password = config[properties[2]] %}

{{ service }}_{{ properties[1] }}:
  postgres_user.present:
    - name: {{ user }}
    - password: {{ password }}
    - user: {{ composer.restore['user'] }}

      {%- endif %}
    {%- endfor %}

  {%- endfor %}

composer_backup_decompressor:
  pkg.installed:
    - name: {{ composer.backup['compressor'] }}

  {%- for dump in salt['file.readdir'](composer.restore['dir']) %}
    {%- if dump.endswith(composer.backup['comp_ext']) %}

composer_restore_{{ salt['file.basename'](composer.restore['dir']) }}_{{ dump }}:
  cmd.run:
    - name: >-
        {{ composer.backup['compressor'] }}
        --decompress --stdout {{ composer.backup['comp_opts'] }}
        {{ dump }} |
        {{ composer.restore['bin'] }} {{ postgres.connection_uri }}
    - cwd: "{{ composer.restore['dir'] }}"
    - runas: {{ composer.restore['user'] }}
      {#- The password is required for remote connections #}
      {%- if postgres.password %}
    - env:
      - PGUSER: {{ postgres.user|yaml() }}
      - PGPASSWORD: {{ postgres.password|yaml() }}
      {%- endif %}
    - require:
      - sls: composer.services.stop
      - pkg: composer_backup_decompressor

    {%- endif %}
  {%- endfor %}

{%- else %}

composer_restore:
  test.fail_without_changes:
   - name: 'Please define `composer:restore:dir` Pillar value.'
   - failhard: True

{%- endif %}
