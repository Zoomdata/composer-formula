{%- from 'composer/map.jinja' import composer -%}

include:
{%- if not composer['bootstrap'] %}
  - composer.backup.layout
  - composer.backup.state
  # Stop services only when doing upgrade and services metadata backup
  - composer.services.stop
  {%- if composer['erase'] %}
  # Drop packages which do not being defined for installation.
  # Usually takes effect when switching releases.
  - composer.remove
  {%- endif %}
  - composer.backup.metadata
  - composer.backup.retension
{%- endif %}
  - composer.services.install
  - composer.services.start
