================
composer-formula
================

Install, configure and run the Composer services.

**IMPORTANT!**

This code is experimental and still in development. It is not officially
supported by Logi Analytics, Inc. and provided for evaluation purposes only.

**NOTE**

See the full `Salt Formulas installation and usage instructions
<https://docs.saltstack.com/en/latest/topics/development/conventions/formulas.html>`_.

Available states
================

.. contents::
    :local:

``composer``
------------

Bootstrap the Composer services from scratch or upgrade existing installation.

``composer.backup``
-------------------

Make backup of the Composer installation state and metadata (PostgreSQL)
databases.

``composer.backup.layout``
~~~~~~~~~~~~~~~~~~~~~~~~~~

Prepare a directory on local filesystem to store backups.

``composer.backup.metadata``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Write compressed dumps of PostgreSQL databases.

``composer.backup.retension``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Remove old backups. Keep last 10 by default.

``composer.backup.state``
~~~~~~~~~~~~~~~~~~~~~~~~~

Write a Pillar SLS file that describes current Composer installation state.

``composer.remove``
-------------------

Disable the Composer services and uninstall the Composer packages.

``composer.repo``
-----------------

Configure package repositories for installing the Composer packages.

``composer.restore``
--------------------

Restore the Composer installation from previously made backup.

``composer.restore.metadata``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Restore the Composer databases in a PostgreSQL cluster.

``composer.services``
---------------------

Install, configure, enable and start the Composer services.

``composer.services.install``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Install the Composer packages and write the configuration files.

``composer.services.start``
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Start the Composer services.

``composer.services.stop``
~~~~~~~~~~~~~~~~~~~~~~~~~~

Stop the Composer services.

``composer.setup``
------------------

Setup initial runtime parameters for the Composer server.

``composer.tools``
------------------

Install additional explicitly defined packages from ``tools`` repository.
