{%- from 'composer/map.jinja' import init_available,
                                     packages,
                                     composer with context %}

{%- if init_available %}

  {%- set services = composer.local['services'] %}
  {%- if 'composer-consul' in services %}
    {#- The ``composer-consul`` is a special kind of service
        and should be stopped last. #}
    {%- do services.remove('composer-consul') %}
    {%- do services.append('composer-consul') %}
  {%- endif %}

  {%- for service in services %}

{{ service }}_stop_disable:
  service.dead:
    - name: {{ service }}
    - disabled: {{ service not in composer['services'] }}

  {%- endfor %}

{%- else %}

  {#- If there is no init system, just do nothing.
      The states here are rendered to satisfy upper level
      dependecies only. #}
  {%- for service in packages %}

{{ service }}_stop_disable:
  test.nop:
    - name: {{ service }}

  {%- endfor %}

{%- endif %}
