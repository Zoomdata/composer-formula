{%- from 'composer/map.jinja' import composer %}

{#- Always fall back to defaults to construct connection URL #}
{%- set props = salt['defaults.merge'](
  salt['defaults.get']('composer:composer:config:composer:properties'),
  composer.config.composer.properties|default({}, true)
) %}
{#- We assume Composer Web server is binded on local loopback interaface #}
{%- set url = 'http://localhost:%s%s'|format(
  props['server.port'],
  props['server.servlet.context-path']
) %}
{%- set api = (url, composer.setup['api'])|join('/') %}

{%- set users = {} %}
{%- set generated_passwords = {} %}

{%- for user in composer.setup.passwords|default({}, true) %}
  {%- if not composer.setup.passwords[user] or
             composer.setup.passwords[user] == 'random' %}

    {%- set password = salt['grains.get']('composer:users:' ~ user) %}

    {%- if not password %}
      {%- set password = '%s_%s'|format(salt['random.get_str'](range(8, 15)|random()),
                                        grains['server_id']|string()|random()) %}
      {%- do generated_passwords.update({user: password}) %}
    {%- endif %}

  {%- else %}
    {%- set password = composer.setup.passwords[user] %}
  {%- endif %}

  {%- do users.update({user: password}) %}
{%- endfor -%}

# Wait until Composer server will be available
composer-wait:
  http.wait_for_successful_query:
    - name: "{{ (url, composer.setup['probe'])|join('/') }}"
    - wait_for: {{ composer.setup['timeout'] }}
    - status: 200
    - failhard: True
    # Works only for Salt >= 2017.7
    - request_interval: 30

{%- if users %}

composer-setup-passwords:
  composer.init_users:
    - name: '{{ api }}'
    - users: {{ users|yaml() }}

{%- endif %}

{%- if generated_passwords %}

composer-save-generated-passwords:
  grains.present:
    - name: composer:users
    - value: {{ generated_passwords|yaml() }}
    - onchanges:
      - composer: composer-setup-passwords

{%- endif %}

{%- if 'supervisor' in users %}

  {%- if composer.setup.branding['css']|default(none, true)
      or composer.setup.branding['file']|default(none, true) %}

composer-branding:
  composer.branding:
    - name: '{{ api }}'
    - username: supervisor
    - password: {{ users['supervisor'] }}
    - css: {{ composer.setup.branding['css']|default(none, true) }}
    - login_logo: {{ composer.setup.branding['login_logo']|default(none, true) }}
    - json_file: {{ composer.setup.branding['file']|default(none, true) }}
    {%- if 'supervisor' in generated_passwords %}
    - onchanges:
      - composer: composer-setup-passwords
    {%- endif %}

  {%- endif %}

  {%- for key, value in composer.setup.connectors|dictsort %}

composer-connector-{{ key }}:
  http.query:
    - name: '{{ api }}/connection/types/{{ key }}'
    - status: 200
    - method: PATCH
    - header_dict: {{ composer.setup['headers']|yaml }}
    - username: supervisor
    - password: {{ users['supervisor'] }}
    - data: '{"enabled": {{ value | string | lower }} }'
    {%- if 'supervisor' in generated_passwords %}
    - onchanges:
      - composer: composer-setup-passwords
    {%- endif %}

  {%- endfor %}

  {%- if composer.setup.license['URL']|default(none, true) %}

composer-license:
  composer.licensing:
    - name: '{{ api }}'
    - username: supervisor
    - password: {{ users['supervisor'] }}
    - url: {{ composer.setup.license['URL'] }}
    - expire: {{ composer.setup.license['expirationDate']|yaml }}
    - license_type: {{ composer.setup.license['licenseType'] }}
    - users: {{ composer.setup.license['userCount'] }}
    - sessions: {{ composer.setup.license['concurrentSessionCount'] }}
    - concurrency: {{ composer.setup.license['enforcementLevel'] }}
    - force: {{ composer.setup.license['force'] }}
    {%- if 'supervisor' in generated_passwords %}
    - onchanges:
      - composer: composer-setup-passwords
    {%- endif %}

  {%- endif %}

  {%- for key, value in composer.setup.toggles|dictsort %}

composer-supervisor-toggle-{{ key }}:
  http.query:
    - name: '{{ api }}/system/variables/ui/{{ key }}'
    - status: 204
    - method: POST
    - header_dict:
        Accept: '*/*'
        Content-Type: 'text/plain'
    - username: supervisor
    - password: {{ users['supervisor'] }}
    - data: '{{ value | string | lower }}'
    {%- if 'supervisor' in generated_passwords %}
    - onchanges:
      - composer: composer-setup-passwords
    {%- endif %}

  {%- endfor %}

{%- endif %}

{%- if not composer.setup|default({}, true) %}

composer-setup:
  test.show_notification:
    - text: |-
        The Composer installation has been completed. Nothing to setup.
        Configure the ``composer:setup:passwords`` Pillar values to
        automatically set passswords for users.

{%- endif %}
