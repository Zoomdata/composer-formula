{%- from 'composer/map.jinja' import composer -%}

include:
  - composer.services
  - composer.tools
{%- if 'composer' in composer['services']|default([], true) %}
  - composer.setup
{%- endif %}

{%- if composer['bootstrap'] %}

# Entering special "Bootstrap Composer" mode:
# make sure that initial installation has been completed when
# bypassing state enforcement (``enforce: False`` Pillar setting).
#
# If the ``bootstrap`` key (or grain value) is present, it means
# that we should still apply configured setting from Pillar.

composer-bootstrap:
  grains.present:
    - name: 'composer:bootstrap'
    - value: {{ composer['bootstrap'] }}
    {%- if grains['saltversioninfo'] >= [2017, 7, 2, 0] %}
    - require_in:
      # The requisite type and full sls name is mandatory here.
      # Relative names do not work with ``require_in``.
      - sls: composer.services.install
    {%- else %}
    # The ``require_in`` requisite for a whole sls is
    # not supported in older Salt versions.
    - order: 1
    {%- endif %}

composer-completed:
  grains.absent:
    - name: 'composer:bootstrap'
    - require:
      - sls: composer.services.start

{%- endif %}
