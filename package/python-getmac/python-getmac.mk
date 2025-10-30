################################################################################
#
# python‑getmac
#
################################################################################

PYTHON_GETMAC_VERSION = 0.9.5

PYTHON_GETMAC_SITE = https://github.com/GhostofGoes/getmac
PYTHON_GETMAC_SITE_METHOD = git
PYTHON_GETMAC_LICENSE = BSD-3-Clause
PYTHON_GETMAC_LICENSE_FILES = LICENSE

PYTHON_GETMAC_SETUP_TYPE = pep517
$(eval $(python-package))
