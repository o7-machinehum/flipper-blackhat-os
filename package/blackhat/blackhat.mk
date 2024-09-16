# Flipper Blackhat script

BLACKHAT_VERSION = 1.0
BLACKHAT_SITE = $(BLACKHAT_PKGDIR)/src
BLACKHAT_SITE_METHOD = local
BLACKHAT_DEPENDENCIES =

define BLACKHAT_BUILD_CMDS
endef

define BLACKHAT_INSTALL_TARGET_CMDS
    $(INSTALL) -D -m 0755 $(@D)/blackhat.sh $(TARGET_DIR)/usr/bin/bh
    cp $(@D)/blackhat.conf $(TARGET_DIR)/etc/blackhat.conf
endef

$(eval $(generic-package))
