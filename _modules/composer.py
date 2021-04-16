# -*- coding: utf-8 -*-
"""
Manage and inspect the Composer installation.

:depends:       urlparse@Py2/urllib.parse@Py3
:platform:      GNU/Linux

"""

import logging
try:
    import urlparse
except ImportError:
    # Py3
    import urllib.parse
    urlparse = urllib.parse
from distutils.version import LooseVersion, StrictVersion

log = logging.getLogger(__name__)

ENVIRONMENT = {
    'composer': '/etc/composer/composer.env',
    'composer-query-engine': '/etc/composer/query-engine.env'
}

PROPERTIES = {
    'composer': '/etc/composer/composer.properties',
    'composer-query-engine': '/etc/composer/query-engine.properties'
}

COMPOSER_BASE_NAME = 'composer'
EDC_NAME_NAME = 'composer-edc'


def _parse_ini(path, chars=(' \'"')):
    """
    Parse ini-like files to a dictionary.

    Those could be Java Spring application properties or shell environment
    variable files.
    """
    ret = {}

    # pylint: disable=undefined-variable
    if __salt__['file.access'](path, 'f'):
        contents = __salt__['file.grep'](path, r'^[^#]\+=.\+$')['stdout']
        for line in contents.splitlines():
            key, value = line.split('=', 1)
            # Strip whitespaces and quotes by default
            key = key.strip(chars)
            value = value.strip(chars)
            ret[key] = value

    if ret:
        return ret

    return None


def environment(path=ENVIRONMENT['composer']):
    """
    Display Composer environment variables as dictionary.

    Returns ``None`` if environment file cannot be read.

    path
        Full path to the environment file

    CLI Example:

    .. code-block:: bash

        salt '*' composer.environment
    """
    return _parse_ini(path)


def properties(path=PROPERTIES['composer']):
    """
    Display Composer properties as dictionary.

    Returns ``None`` if property file cannot be read.

    path
        Full path to the property file

    CLI Example:

    .. code-block:: bash

        salt '*' composer.properties
    """
    return _parse_ini(path)


def list_repos(compact=False):
    """
    List the Composer repositories which are locally configured.

    compact : False
        Set ``True`` to get compact dictionary containing the Composer
        repositories configuration

    CLI Example:

    .. code-block:: bash

        salt '*' composer.list_repos
    """
    repo_config = {
        'base_url': None,
        'gpgkey': None,
        'release': None,
        'repositories': [],
        'components': [],
    }

    repos = {k: v for (k, v) in
             __salt__['pkg.list_repos']().items()  # pylint: disable=undefined-variable
             if k.startswith(COMPOSER_BASE_NAME)}

    if not compact:
        return repos

    for repo in repos:
        # Skip repository discovery if disabled
        if not int(repos[repo].get('enabled', 0)):
            continue

        url = urlparse.urlparse(repos[repo]['baseurl'].strip())
        if not repo_config['base_url']:
            repo_config['base_url'] = urlparse.urlunparse(
                (url.scheme, url.netloc, '', '', '', ''))

        try:
            if not repo_config['gpgkey'] and 'gpgkey' in repos[repo] and \
               int(repos[repo].get('gpgcheck', '0')):
                repo_config['gpgkey'] = repos[repo]['gpgkey'].strip()
        except ValueError:
            pass

        repo_root = url.path.split('/')[1]
        log.debug("composer.list_repos: Processing repo_root: %s" % repo_root)
        try:
            if repo_root == 'latest':
                repo_config['release'] = repo_root
            else:
                if not StrictVersion(repo_root):
                    raise ValueError
                # repo_root is a string like '5.8' or '5.10'
                if isinstance(repo_config['release'], type(None)):
                    repo_config['release'] = repo_root
                elif isinstance(repo_config['release'], str) and \
                        LooseVersion(repo_root) > LooseVersion(repo_config['release']):
                    repo_config['release'] = repo_root
        except ValueError:
            # Collect all other unique repos which are not release numbers,
            # such as ``tools`` for example.
            if repo_root not in repo_config['repositories']:
                repo_config['repositories'].append(repo_root)

        component = url.path.rstrip('/').rsplit('/')[-1]
        if component not in repo_config['components']:
            repo_config['components'].append(component)

    return repo_config


def list_pkgs(include_edc=True, include_microservices=True, include_tools=True):
    """
    List currently installed Composer packages.

    include_edc : True
        Include EDC packages as well

    include_microservices : True
        Include microservices packages as well

    include_tools : True
        Include tool packages as well

    CLI Example:

    .. code-block:: bash

        salt '*' composer.list_pkgs include_tools=False
    """
    # pylint: disable=undefined-variable
    zd_pkgs = [i for i in __salt__['pkg.list_pkgs']() if i.startswith(COMPOSER_BASE_NAME)]

    if not include_edc:
        zd_pkgs = list(set(zd_pkgs) - set(list_pkgs_edc()))

    if not include_microservices:
        zd_pkgs = list(set(zd_pkgs) - set(list_pkgs_microservices()))

    if not include_tools:
        zd_pkgs = list(set(zd_pkgs) - set(list_pkgs_tools()))

    return sorted(zd_pkgs)


def list_pkgs_edc(from_repo=False):
    """
    List available Composer EDC (data connector) packages.

    from_repo : False
        By default, return only locally installed packages. If set ``True``,
        return all connector packages available from configured repositories.

    CLI Example:

    .. code-block:: bash

        salt '*' composer.list_pkgs_edc
    """
    # pylint: disable=undefined-variable
    if from_repo:
        edc_pkgs = list(__salt__['pkg.list_repo_pkgs'](EDC + '-*'))
    else:
        edc_pkgs = [i for i in __salt__['pkg.list_pkgs']() if i.startswith(EDC_BASE_NAME)]

    return sorted(edc_pkgs)


def list_pkgs_microservices():
    """
    List only currently installed Composer microservice packages.

    CLI Example:

    .. code-block:: bash

        salt '*' composer.list_pkgs_microservices
    """
    # pylint: disable=undefined-variable
    m_s = __salt__['defaults.get']('composer:composer:microservices:packages', [])
    m_s.extend(__salt__['pillar.get']('composer:microservices:packages') or [])
    ms_pkgs = [i for i in __salt__['pkg.list_pkgs']() if i in list(set(m_s))]

    return sorted(ms_pkgs)


def list_pkgs_tools():
    """
    List only currently installed Composer tool packages.

    CLI Example:

    .. code-block:: bash

        salt '*' composer.list_pkgs_tools
    """
    # pylint: disable=undefined-variable
    tools = [i for i in __salt__['pkg.list_pkgs']()
             if i.startswith(COMPOSER_BASE_NAME) and i not in __salt__['service.get_all']()]

    return sorted(tools)


def version(full=True):
    """
    Display Composer packages version.

    full : True
        Return full version. If set False, return only short version (X.Y.Z).

    CLI Example:

    .. code-block:: bash

        salt '*' composer.version
    """
    zd_version = ''
    zd_pkgs = list_pkgs(include_edc=False, include_tools=False)
    if not zd_pkgs:
        return zd_version

    # pylint: disable=undefined-variable
    zd_version = __salt__['pkg.version'](zd_pkgs[0])
    return zd_version.split('-')[0] if not full else zd_version


def version_edc(full=True):
    """
    Display Composer EDC (datasource connector) packages version.

    CLI Example:

    full : True
        Return full version. If set False, return only short version (X.Y.Z).

    .. code-block:: bash

        salt '*' composer.version_edc
    """
    edc_version = ''
    edc_pkgs = list_pkgs_edc()

    if not edc_pkgs:
        return edc_version

    # pylint: disable=undefined-variable
    edc_version = __salt__['pkg.version'](edc_pkgs[0])
    return edc_version.split('-')[0] if not full else edc_version


def version_microservices(full=True):
    """
    Display Composer microservice packages version.

    CLI Example:

    full : True
        Return full version. If set False, return only short version (X.Y.Z).

    .. code-block:: bash

        salt '*' composer.version_microservices
    """
    ms_version = ''
    ms_pkgs = list_pkgs_microservices()

    if not ms_pkgs:
        return ms_version

    # pylint: disable=undefined-variable
    ms_version = __salt__['pkg.version'](pkg)
    return ms_version.split('-')[0] if not full else ms_version


def version_tools(full=True):
    """
    Display Composer tool packages version.

    CLI Example:

    full : True
        Return full version. If set False, return only short version (X.Y.Z).

    .. code-block:: bash

        salt '*' composer.version_tools
    """
    t_version = ''
    tools = list_pkgs_tools()

    if not tools:
        return t_version

    # pylint: disable=undefined-variable
    t_version = __salt__['pkg.version'](tools[0])
    return t_version.split('-')[0] if not full else t_version


def services(running=False):
    """
    Return a list of available Composer services.

    running : False
        Return only running services

    CLI Example:

    .. code-block:: bash

        salt '*' composer.services true
    """
    # pylint: disable=undefined-variable
    zd_services = []
    for srv in __salt__['service.get_all']():
        if srv.startswith(COMPOSER_BASE_NAME):
            if running:
                if __salt__['service.status'](srv):
                    zd_services.append(srv)
            else:
                zd_services.append(srv)

    if COMPOSER_BASE_NAME in zd_services:
        # Put composer service to the end of the list,
        # because it is better to be started last
        zd_services.remove(COMPOSER_BASE_NAME)
        zd_services.append(COMPOSER_BASE_NAME)

    return zd_services


def inspect(limits=False,
            versions=False,
            full=True):
    """
    Inspect Composer installation and return info as dictionary.

    limits : False
        Detect system limits. Currently not implemented, so this parameter
        just returns ``None`` for ``limits`` key.

    versions : False
        Include exact versions of Composer and EDC installed

    full : True
        Return full version. If set False, return only short version (X.Y.Z).
        Has effect only when ``versions`` parameter set True.

    CLI Example:

    .. code-block:: bash

        salt --out=yaml '*' composer.inspect
    """
    ret = {}
    env = {}
    config = {}

    ret[COMPOSER_BASE_NAME] = list_repos(compact=True)

    for service in ENVIRONMENT:
        parsed_env = environment(ENVIRONMENT[service])
        if parsed_env:
            # file with environment is present
            env[service] = {
                'path': ENVIRONMENT[service],
                'variables': parsed_env,
            }
        else:
            env[service] = None

    for service in PROPERTIES:
        new_config = properties(PROPERTIES[service])

        if new_config:
            config[service] = {
                # Disable merging with defaults is mandatory here
                'merge': False,
                'path': PROPERTIES[service],
                'properties': new_config,
            }
        else:
            config[service] = None

    ret[COMPOSER_BASE_NAME].update(
        {
            'packages': list_pkgs(include_edc=False,
                                  include_microservices=False,
                                  include_tools=False),
            'edc': {
                'packages': list_pkgs_edc(),
            },
            'microservices': {
                'packages': list_pkgs_microservices(),
            },
            'tools': {
                'packages': list_pkgs_tools(),
            },
            'environment': env,
            'config': config,
            'services': services(True),
        }
    )

    if limits:
        # TO DO: implement reading limits.
        # Just skip limits configuration for now to omit defaults.
        ret[COMPOSER_BASE_NAME].update({
            'limits': None,
        })

    if versions:
        ret[COMPOSER_BASE_NAME].update({
            'version': version(full=full),
        })
        ret[COMPOSER_BASE_NAME]['edc'].update({
            'version': version_edc(full=full),
        })
        ret[COMPOSER_BASE_NAME]['microservices'].update({
            # The auxiliary services usually do not share package iteration
            # (build) number, so we strip it off
            'version': version_microservices(full=False),
        })
        ret[COMPOSER_BASE_NAME]['tools'].update({
            'version': version_tools(full=full),
        })

    return ret
