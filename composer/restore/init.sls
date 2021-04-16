{%- do salt['grains.set']('composer:bootstrap', true) %}

include:
  - composer.restore.metadata
  - composer.remove
  - composer.services.install
  - composer.services.start

composer-completed:
  grains.absent:
    - name: 'composer:bootstrap'
    - require:
      - sls: composer.services.start
