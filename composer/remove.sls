{%- from 'composer/map.jinja' import composer -%}

{%- if 'composer-edc-all' in composer.edc['packages'] %}
  {%- do composer.edc.update({
    'packages': salt['composer.list_pkgs_edc'](from_repo=true)
  }) %}
{%- endif %}

{%- set packages = composer['packages'] +
                   composer.edc['packages'] +
                   composer.microservices['packages'] +
                   composer.tools['packages'] %}

{%- if composer['erase'] %}
  {%- set installed = salt['composer.list_pkgs']() %}
  {%- set uninstall = [] %}

  {%- for pkg in installed %}
    {%- if pkg not in packages %}
      {%- do uninstall.append(pkg) %}
    {%- endif %}
  {%- endfor %}
{%- else %}
  {%- set uninstall = packages %}
{%- endif %}

composer-remove:
  pkg.purged:
    - pkgs: {{ uninstall|yaml() }}
