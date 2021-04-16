{%- from 'composer/map.jinja' import composer with context %}

{%- set packages = [] %}
{%- set versions = {} %}

{%- for install in (composer, composer.edc, composer.microservices) %}
  {%- for package in install.packages|default([], true) %}
    {%- if package and package not in packages %}
      {%- do packages.append(package) %}
      {%- do versions.update({package: install.get('version')}) %}
    {%- endif %}
  {%- endfor %}
{%- endfor %}

{%- set jdbc = composer.edc.jdbc|default({}, true) %}

include:
  - composer.repo

{%- for package in packages %}

  {%- set version = versions[package] %}
  {%- if version and version != 'latest' and '-' not in version and
         grains['saltversioninfo'] >= [2017, 7, 0, 0] and
         grains['os_family'] == 'Debian' %}
    {#- pkg state on Ubuntu allows wildcards instead of
        specifying the full version #}
    {%- set version = version ~ '-*' %}
  {%- endif %}

{{ package }}_package:
  {%- if package == 'composer-edc-all' %}
  composer.edc_installed:
  {%- else %}
  pkg.installed:
  {%- endif %}
    - name: {{ package }}
    {%- if version %}
    - version: {{ version }}
    {#- Update local package metadata only on the first state.
        This speed ups execution during upgrades. #}
    - refresh: {{ loop.index == 1 }}
    {%- endif %}
    - skip_verify: {{ composer.gpgkey|default(none, true) is none }}
    {%- if not composer['bootstrap']
       and not composer['upgrade']
       and package in composer.local['services'] %}
    - prereq_in:
      - service: {{ package }}_stop_disable
      {%- if composer.backup['destination'] and (
             composer.backup['state'] or
             package in composer.backup['services']|default([], true)) %}
      - file: composer_backup_dir
      {%- endif %}
    {%- endif %}
    {%- if package in composer['services'] %}
    - watch_in:
      - {{ package }}_start_enable
    {%- endif %}

{%- endfor %}

{%- if 'composer-consul' in packages %}

# The Consul data dir needs to be purged on upgrades

composer-consul_data_dir:
  file.directory:
    # This assumes default installation location
    - name: {{ salt['file.join'](composer['prefix'], 'data/consul') }}
    - clean: True
    - onchanges:
      - pkg: composer-consul_package

{%- endif %}

{%- if jdbc['install']|default(false) %}

  {%- for package in composer.edc['packages']|default([], true) %}

{{ package }}_libs:
  composer.libraries:
    - name: {{ package }}
    {#- Check if EDC JDBC driver URLs have been configured #}
    - urls: {{ jdbc.drivers[package|replace('composer-edc-', '', 1)]|default([], true) }}
    - require:
      - {{ package }}_package
    {%- if package in composer['services'] %}
    - watch_in:
      - {{ package }}_start_enable
    {%- endif %}

  {%- endfor %}

{%- endif %}

{%- if composer.limits|default({}) and packages %}

  {%- if salt['test.provider']('service') == 'systemd' %}

# Provision systemd limits Composer services

    {%- for service in packages %}

{{ service }}_systemd_limits:
  file.managed:
    - name: /etc/systemd/system/{{ service }}.service.d/limits.conf
    - source: salt://composer/templates/systemd_unit_override.conf
    - template: jinja
    - user: root
    - group: root
    - mode: "0644"
    - makedirs: True
    - defaults:
        header: {{ composer.header|default('', true)|yaml() }}
        sections:
          Service:
          {%- for item, limit in composer.limits|default({}, true)|dictsort() %}
            {%- if 'hard' in limit|default({}, true) %}
            Limit{{ item|upper() }}: >-
                {{ (limit.get('soft', none), limit.hard)|reject("none")|join(":") }}
            {%- endif %}
          {%- endfor %}
    - require:
      - pkg: {{ service }}_package
    - watch_in:
      - module: systemctl_reload
      {%- if service in composer['services'] %}
      - {{ service }}_start_enable
      {%- endif %}

    {%- endfor %}

  {%- else %}

# Provision global system limits for Composer user

composer-user-limits-conf:
  file.managed:
    - name: /etc/security/limits.d/30-composer.conf
    - source: salt://composer/templates/limits.conf
    - template: jinja
    - user: root
    - group: root
    - mode: "0644"
    - defaults:
        header: {{ composer.header|default('', true)|yaml() }}
        limits: {{ composer.limits|yaml() }}
        user: {{ composer.user|default('root', true) }}
    - require:
      - pkg: {{ packages|first() }}_package
    {%- if composer['services'] %}
    - watch_in:
      {%- for service in composer['services'] %}
      - {{ service }}_start_enable
      {%- endfor %}
    {%- endif %}

  {%- endif %}

{%- endif %}

# Configure Composer environment

{%- for service, environment in composer.environment|default({}, true)|dictsort() %}

  {%- if environment['path']|default('') and service in packages %}

{{ service }}_environment:
  file.managed:
    - name: {{ environment.path }}
    {%- if environment.get('variables') %}
    - source: salt://composer/templates/env.sh
    - template: jinja
    - defaults:
        header: {{ composer.header|default('', true)|yaml() }}
        environment: {{ environment['variables']|yaml() }}
    {%- else %}
    - replace: False
    {%- endif %}
    - user: root
    - group: root
    - mode: "0644"
    - makedirs: True
    {%- if service in packages %}
    - require:
      - pkg: {{ service }}_package
    {%- endif %}
    {%- if service in composer['services'] %}
    - watch_in:
      - {{ service }}_start_enable
    {%- endif %}
    # Prevent `test=True` failures on a fresh system
    - onlyif: getent group | grep -q '\<{{ composer.group }}\>'

  {%- endif %}

{%- endfor %}

# Configure Composer services

{%- for service, config in composer.config|default({}, true)|dictsort() %}

  {%- if config.path|default('') and service in packages %}

{{ service }}_config:
  file.managed:
    - name: {{ config.path }}
    {%- if config.properties|default({}, true) %}
    - source: salt://composer/templates/service.properties
    - template: jinja
    - defaults:
        header: {{ composer.header|default('', true)|yaml() }}
        properties: {{ config['properties']|yaml() }}
    {%- else %}
    - replace: False
    {%- endif %}
    - user: root
    - group: {{ composer.group }}
    - mode: "0640"
    - makedirs: True
    - require:
      - pkg: {{ service }}_package
    {%- if service in composer['services'] %}
    - watch_in:
      - {{ service }}_start_enable
    {%- endif %}
    # Prevent ``test=True`` failures on a fresh system
    - onlyif: getent group | grep -q '\<{{ composer.group }}\>'

  {%- endif %}

  {%- if config.json|default({}, true) and service in packages %}

{{ service }}_json:
  file.serialize:
    - name: {{ config.path }}
    - dataset: {{ config.json|yaml() }}
    - formatter: json
    - user: root
    - group: {{ composer.group }}
    - mode: "0640"
    - makedirs: True
    - require:
      - pkg: {{ service }}_package
    {%- if service in composer['services'] %}
    - watch_in:
      - {{ service }}_start_enable
    {%- endif %}
    # Prevent ``test=True`` failures on a fresh system
    - onlyif: getent group | grep -q '\<{{ composer.group }}\>'

  {%- endif %}

  {%- if config.options|default({}, true) and service in packages %}

    {%- if service.startswith('composer-') %}
      {%- set srv = service|replace('composer-', '', 1) %}
    {%- else %}
      {%- set srv = service %}
    {%- endif %}
    {%- set jvm_file = salt['file.join'](composer.config_dir, srv ~ '.jvm') %}

{{ service }}_jvm:
  file.managed:
    - name: {{ jvm_file }}
    - source: salt://composer/templates/service.jvm
    - template: jinja
    - defaults:
        header: {{ composer.header|default('', true)|yaml() }}
        options: {{ config['options']|yaml() }}
    - user: root
    - group: {{ composer.group }}
    - mode: "0640"
    - makedirs: True
    - require:
      - pkg: {{ service }}_package
    {%- if service in composer['services'] %}
    - watch_in:
      - {{ service }}_start_enable
    {%- endif %}
    # Prevent ``test=True`` failures on a fresh system
    - onlyif: getent group | grep -q '\<{{ composer.group }}\>'

  {%- endif %}

{%- endfor %}

# Run post installation commands

{%- for service, commands in composer.post_install|default({}, true)|dictsort() %}

  {%- if service in packages %}

    {%- for command in commands %}

{{ service }}-post-install-{{ loop.index }}:
  cmd.run:
    - name: {{ command }}
    - timeout: 600
    - require:
      - pkg: {{ service }}_package
    - onlyif: {{ composer['bootstrap']|lower() }}

    {%- endfor %}

  {%- endif %}

{%- endfor %}
