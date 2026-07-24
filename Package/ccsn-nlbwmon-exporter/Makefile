include $(TOPDIR)/rules.mk

PKG_NAME:=ccsn-nlbwmon-exporter
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=CCSN

include $(INCLUDE_DIR)/package.mk

Build/Compile:=

define Package/$(PKG_NAME)
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=CCSN nlbwmon collector for Prometheus node exporter
  DEPENDS:=+prometheus-node-exporter-lua +libuci-lua +nlbwmon
endef

define Package/$(PKG_NAME)/description
 Installs the CCSN nlbwmon client-traffic collector for the official
 prometheus-node-exporter-lua runtime. Client identity mappings and DHCP pools
 remain local UCI configuration under /etc/config/ccsn-nlbwmon-exporter.
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/prometheus-collectors
	$(INSTALL_DATA) ./files/ccsn_nlbwmon.lua $(1)/usr/lib/lua/prometheus-collectors/ccsn_nlbwmon.lua
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/ccsn-nlbwmon-exporter.config $(1)/etc/config/ccsn-nlbwmon-exporter
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/ccsn-nlbwmon-exporter
endef

$(eval $(call BuildPackage,$(PKG_NAME)))

define Package/luci-app-ccsn-observability
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=CCSN observability configuration interface
  DEPENDS:=+luci-base +$(PKG_NAME) +prometheus-node-exporter-ucode
endef

define Package/luci-app-ccsn-observability/description
 LuCI configuration interface for the CCSN nlbwmon collector and the two
 Prometheus exporter endpoints.
endef

define Package/luci-app-ccsn-observability/install
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/ccsn-observability
	$(INSTALL_DATA) ./files/luci/overview.js $(1)/www/luci-static/resources/view/ccsn-observability/overview.js
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./files/luci/menu.json $(1)/usr/share/luci/menu.d/luci-app-ccsn-observability.json
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./files/luci/acl.json $(1)/usr/share/rpcd/acl.d/luci-app-ccsn-observability.json
endef

$(eval $(call BuildPackage,luci-app-ccsn-observability))
