include $(TOPDIR)/rules.mk

PKG_NAME:=ccsn-nlbwmon-exporter
PKG_VERSION:=1
PKG_RELEASE:=3

PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=CCSN

include $(INCLUDE_DIR)/package.mk

Build/Compile:=

define Package/$(PKG_NAME)
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=CCSN nlbwmon collector for Prometheus node exporter
  DEPENDS:=+prometheus-node-exporter-lua +prometheus-node-exporter-ucode +libuci-lua +libubus-lua +nlbwmon
endef

define Package/$(PKG_NAME)/description
 Installs the CCSN nlbwmon client-traffic collector for the official
 prometheus-node-exporter-lua runtime. It exports nlbwmon boundary traffic as
 Internet traffic and attributes clients to active OpenWrt logical interfaces.
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/prometheus-collectors
	$(INSTALL_DATA) ./files/ccsn_nlbwmon.lua $(1)/usr/lib/lua/prometheus-collectors/ccsn_nlbwmon.lua
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/ccsn-nlbwmon-exporter.config $(1)/etc/config/ccsn-nlbwmon-exporter
	# Register upstream services in the image; their UCI enabled options decide runtime state.
	$(INSTALL_DIR) $(1)/etc/rc.d
	$(LN) ../init.d/prometheus-node-exporter-lua $(1)/etc/rc.d/S60prometheus-node-exporter-lua
	$(LN) ../init.d/prometheus-node-exporter-ucode $(1)/etc/rc.d/S60prometheus-node-exporter-ucode
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/ccsn-nlbwmon-exporter
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
