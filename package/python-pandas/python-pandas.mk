################################################################################
#
# python-pandas
#
################################################################################

PYTHON_PANDAS_VERSION = v2.3.3
PYTHON_PANDAS_SITE = https://github.com/pandas-dev/pandas
PYTHON_PANDAS_SITE_METHOD = git
PYTHON_PANDAS_INSTALL_STAGING = YES

PYTHON_PANDAS_LICENSE = BSD
PYTHON_PANDAS_LICENSE_FILES = LICENSE

PYTHON_PANDAS_DEPENDENCIES = \
    bzip2 \
    python-dateutil \
    python-pytz \
    python-numpy \
    host-python-versioneer \
    host-python-numpy \
    host-python-cython

PYTHON_PANDAS_CONF_ENV += \
	_PYTHON_SYSCONFIGDATA_NAME=$(PKG_PYTHON_SYSCONFIGDATA_NAME) \
	PYTHONPATH=$(PYTHON3_PATH)

$(eval $(meson-package))

# PYTHON_PANDAS_SETUP_TYPE = pep517
# $(eval $(python-package))
