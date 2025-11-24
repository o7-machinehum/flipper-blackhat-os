################################################################################
#
# python‑version
#
################################################################################


PYTHON_VERSION_VERSION = 5232eea250ab72cc5cb72b0b75efb35d2192b906

PYTHON_VERSION_SITE = https://gitlab.com/halfak/python_version
PYTHON_VERSION_SITE_METHOD = git
PYTHON_VERSION_LICENSE = BSD-3-Clause
PYTHON_VERSION_LICENSE_FILES = LICENSE

PYTHON_VERSION_SETUP_TYPE = pep517

$(eval $(python-package))
