################################################################################
#
# python‑routersploit
#
################################################################################

PYTHON_ROUTERSPLOIT_VERSION = 3.4.7

PYTHON_ROUTERSPLOIT_SITE = https://github.com/threat9/routersploit
PYTHON_ROUTERSPLOIT_SITE_METHOD = git
PYTHON_ROUTERSPLOIT_LICENSE = BSD-3-Clause
PYTHON_ROUTERSPLOIT_LICENSE_FILES = LICENSE

PYTHON_ROUTERSPLOIT_SETUP_TYPE = pep517

PYTHON_ROUTERSPLOIT_DEPENDENCIES = \
    python-requests \
    python-paramiko \
    python-pysnmp \
    python-pycryptodomex \
    python-telnetlib3

$(eval $(python-package))
