{%- from 'composer/map.jinja' import composer %}

{%- if composer.backup['destination'] and (
       composer.backup['state'] or composer.backup['services']) %}

include:
  - composer.backup.layout
  - composer.backup.state
  - composer.services.stop
  - composer.backup.metadata
  - composer.backup.retension
  - composer.services.start

{%- else %}

composer-backup:
  test.show_notification:
    - name: The backup has been disabled
    - text: |
        To make a backup of Composer installation state or metadata you must
        set ``composer:backup:state`` or ``composer:backup:services`` Pillar
        values respectively.

{%- endif %}
