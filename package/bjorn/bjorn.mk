################################################################################
#
# bjorn
#
################################################################################

BJORN_VERSION = 1.0
BJORN_SITE = $(BJORN_PKGDIR)/bjorn
BJORN_SITE_METHOD = local

define BJORN_INSTALL_TARGET_CMDS
    mkdir -p $(TARGET_DIR)/root/bjorn
    cp -r $(@D)/* $(TARGET_DIR)/root/bjorn/
endef

BJORN_DEPENDENCIES = \
    lsof \
    gnutls \
    wget \
    python-netifaces \
    python-pip \
    python-pymysql \
    python-pysmb \
    python-smbprotocol \
    python-sqlalchemy \
    python-legacy-cgi

BJORN_LICENSE = MIT
BJORN_LICENSE_FILES = LICENSE

$(eval $(generic-package))
