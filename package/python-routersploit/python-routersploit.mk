################################################################################
#
# python‑routersploit
#
################################################################################

PYTHON_ROUTERSPLOIT_VERSION = 3f693b7e7c572a8a5663593572cfd535dd21a567

PYTHON_ROUTERSPLOIT_SITE = https://github.com/o7-machinehum/routersploit
PYTHON_ROUTERSPLOIT_SITE_METHOD = git
PYTHON_ROUTERSPLOIT_LICENSE = BSD-3-Clause
PYTHON_ROUTERSPLOIT_LICENSE_FILES = LICENSE

PYTHON_ROUTERSPLOIT_SETUP_TYPE = pep517

PYTHON_ROUTERSPLOIT_DEPENDENCIES = \
    python-requests \
    python-paramiko \
    python-pysnmp \
    python-pycryptodome \
    python-telnetlib3 \

$(eval $(python-package))
