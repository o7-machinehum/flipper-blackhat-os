################################################################################
#
# python‑rich
#
################################################################################

PYTHON_RICH_VERSION = v14.2.0

PYTHON_RICH_SITE = https://github.com/Textualize/rich
PYTHON_RICH_SITE_METHOD = git
PYTHON_RICH_LICENSE = BSD-3-Clause
PYTHON_RICH_LICENSE_FILES = LICENSE

PYTHON_RICH_DEPENDENCIES = \
    python-pygments

PYTHON_RICH_SETUP_TYPE = pep517

$(eval $(python-package))
