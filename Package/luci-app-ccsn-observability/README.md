# luci-app-ccsn-observability

This LuCI application edits only the UCI configuration for the two Prometheus
exporters and the CCSN nlbwmon collector. It does not create firewall rules,
configure SNMP, or embed router-specific interface and client data.

OpenWrt logical interfaces are the only network identity. Their active IPv4,
IPv6, and DHCPv6-PD assignment prefixes are discovered automatically, so local
DHCP, external DHCP, DHCP relay, and static-address VLANs all work without
additional configuration. Client IDs are
derived from locally known DHCP/static-lease hostnames and fall back to
`mac_<hex>`. DHCP is optional and only enables pool-capacity and active-lease
metrics for local DHCP sections. Simplified Chinese translations live under
`po/zh_Hans/` and are compiled by the standard LuCI build system. After changing
user-visible JavaScript or menu/ACL JSON strings, run `sh tools/update-po.sh`
from an OpenWrt build tree. The script uses the official LuCI `i18n-scan.pl`
scanner; set `LUCI_I18N_SCAN` only when the scanner is outside the normal
`feeds/luci/build/` path. Translate every new entry before building.
