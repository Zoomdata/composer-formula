{%- from 'composer/map.jinja' import composer with context %}
{%- import_yaml 'composer/defaults.yaml' as defaults %}

{%- set repositories = [] %}
{%- set default_components = defaults.composer['components'] %}
{%- if composer['base_url'] and composer['release'] %}
  {#- Create list of repos to make full OS dependent entries of them #}
  {%- set repositories = [composer.release] +
                         composer.repositories|default([], true) %}

  {#- Make sure components always have at lest default value.
      GPG key value should be always set, even to ``None`` or ``Null``. #}
  {%- do composer.update({
    'components': composer.components|default(default_components, true),
    'gpgkey': composer.gpgkey|default(none, true),
  }) %}

# FIXME: provision and check sum for repo GnuPG pub key

  {%- if grains['os_family'] == 'Debian'
     and composer.gpgkey %}

# FIXME: due to a bug in Salt 2017.7.2,
# some file downloads and remote hash verifications are broken
composer-gpg-key:
  file.managed:
    - name: {{ composer.repo_keyfile }}
    - makedirs: True
    - user: root
    - group: root
    - mode: "0444"
    - contents: |
        {{ salt['http.query'](composer.gpgkey)['body']|indent(8) }}

  {%- endif %}

{%- else %}

composer-repo-is-mission:
  test.show_notification:
    - text: |
        There is no Composer repository URL and/or release (major) version provided.
        The repo configuration has been skipped.

{%- endif %}

{%- for repo in repositories %}
  {#- Populate configured components only for release repo #}
  {%- if repo == composer.release %}
    {%- set components = composer.components %}
  {%- else %}
    {%- set components = default_components %}
  {%- endif %}

  {%- if grains['os_family'] == 'Debian' %}
    {#- Update merged ``composer`` dictionary with repo information on
        each iteration to reuse it in later state formatting #}
    {%- do composer.update({
      'repo': repo,
      'components': components|join(' '),
    }) %}

{{ composer.repo_name|format(**composer) }}:
  pkgrepo.managed:
    - name: {{ composer.repo_entry|format(**composer) }}
    - file: {{ composer.repo_file|format(**composer) }}
    - clean_file: True
    {%- if composer.gpgkey %}
    - key_url: file://{{ composer.repo_keyfile }}
    - require:
      - file: composer-gpg-key
    {%- endif %}

  {%- elif grains['os_family'] == 'RedHat' %}
    {%- for component in components %}
      {#- Update merged ``composer`` dictionary with repo information on
          each iteration to reuse it in later state formatting #}
      {%- do composer.update({
        'repo': repo,
        'component': component,
      }) %}

{{ composer.repo_name|format(**composer) }}:
  pkgrepo.managed:
    - humanname: {{ composer.repo_desc|format(**composer) }}
    - baseurl: {{ composer.repo_url|format(**composer) }}
    {%- if composer.gpgkey %}
    - gpgcheck: 1
    - gpgkey: {{ composer.gpgkey }}
    {%- else %}
    - gpgcheck: 0
    {%- endif %}

    {%- endfor %}
  {%- endif %}
{%- endfor %}
