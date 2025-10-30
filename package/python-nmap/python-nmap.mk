################################################################################
#
# python‑nmap
#
################################################################################

PYTHON_NMAP_VERSION = 0d2cf4650778c95ba1463d709894138829e6c1a9

PYTHON_NMAP_SITE = https://bitbucket.org/xael/python-nmap
PYTHON_NMAP_SITE_METHOD = git
PYTHON_NMAP_LICENSE = BSD-3-Clause
PYTHON_NMAP_LICENSE_FILES = LICENSE

PYTHON_NMAP_SETUP_TYPE = pep517

$(eval $(python-package))
