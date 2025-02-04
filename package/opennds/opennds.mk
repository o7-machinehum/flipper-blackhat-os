OPENNDS_VERSION = v10.3.0
OPENNDS_SITE = https://github.com/openNDS/openNDS
OPENNDS_SITE_METHOD = git
OPENNDS_DEPENDENCIES = libmicrohttpd nftables

define OPENNDS_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) $(TARGET_CONFIGURE_OPTS)
endef

define OPENNDS_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) $(TARGET_CONFIGURE_OPTS) \
		DESTDIR=$(TARGET_DIR) install
endef

$(eval $(generic-package))
