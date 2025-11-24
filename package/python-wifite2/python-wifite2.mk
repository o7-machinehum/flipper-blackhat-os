################################################################################
#
# python‑wifite2
#
################################################################################

PYTHON_WIFITE2_VERSION = e09fbea887cf4db4b15c8dd5b980c15d176a5c79

PYTHON_WIFITE2_SITE = https://github.com/kimocoder/wifite2
PYTHON_WIFITE2_SITE_METHOD = git
PYTHON_WIFITE2_LICENSE = BSD-3-Clause
PYTHON_WIFITE2_LICENSE_FILES = LICENSE

PYTHON_WIFITE2_SETUP_TYPE = pep517

PYTHON_WIFITE2_DEPENDENCIES = \
    python-chardet \
    python-requests \
    python-rich \
    python-scapy \
    python-version

$(eval $(python-package))
