include $(TOPDIR)/rules.mk

PKG_LICENSE:=Apache-2.0
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

LUCI_TITLE:=CCSN observability configuration interface
LUCI_DESCRIPTION:=Configures Prometheus exporters and DHCP-aware client accounting
LUCI_DEPENDS:=+luci-base +ccsn-nlbwmon-exporter +prometheus-node-exporter-ucode
LUCI_MAINTAINER:=CCSN

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
