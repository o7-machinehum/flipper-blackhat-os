################################################################################
#
# python‑nmap
#
################################################################################

PYTHON_NMAP_VERSION = 1.9.2

PYTHON_NMAP_SITE = https://github.com/nmmapper/python3-nmap
PYTHON_NMAP_SITE_METHOD = git
PYTHON_NMAP_LICENSE = BSD-3-Clause
PYTHON_NMAP_LICENSE_FILES = LICENSE

PYTHON_NMAP_SETUP_TYPE = pep517

PYTHON_NMAP_DEPENDENCIES = \
    python-simplejson

$(eval $(python-package))
