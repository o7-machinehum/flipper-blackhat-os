################################################################################
#
# python‑pycryptodome
#
################################################################################

PYTHON_PYCRYPTODOME_VERSION = v3.22.0

PYTHON_PYCRYPTODOME_SITE = https://github.com/Legrandin/pycryptodome
PYTHON_PYCRYPTODOME_SITE_METHOD = git
PYTHON_PYCRYPTODOME_LICENSE = BSD-3-Clause
PYTHON_PYCRYPTODOME_LICENSE_FILES = LICENSE

PYTHON_PYCRYPTODOME_SETUP_TYPE = pep517

$(eval $(python-package))
