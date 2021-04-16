{%- from 'composer/map.jinja' import composer -%}

{%- if 'tools' in composer.repositories|default([], true) -%}

include:
  - composer.repo

  {%- if composer.tools['packages'] %}

composer-tools:
  pkg.installed:
    - pkgs: {{ composer.tools['packages']|yaml() }}
    - version: {{ composer.tools.version|default(none, true) }}
    - skip_verify: {{ composer.gpgkey|default(none, true) is none }}
    - require:
      - sls: composer.repo

  {%- endif %}

{%- endif %}
