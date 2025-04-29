################################################################################
#
# python‑pywifi
#
################################################################################

PYTHON_PYWIFI_VERSION = 719baf73d8d32c623dbaf5e9de5d973face152a4
PYTHON_PYWIFI_SITE = https://github.com/awkman/pywifi
PYTHON_PYWIFI_SITE_METHOD = git
PYTHON_PYWIFI_LICENSE = BSD-3-Clause
PYTHON_PYWIFI_LICENSE_FILES = LICENSE

PYTHON_PYWIFI_SETUP_TYPE = pep517

$(eval $(python-package))
