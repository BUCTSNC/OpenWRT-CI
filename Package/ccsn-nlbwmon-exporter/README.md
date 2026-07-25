# CCSN nlbwmon exporter package

This local package installs `ccsn_nlbwmon.lua` into the official
`prometheus-node-exporter-lua` collector directory and creates a minimal UCI
configuration anchor used by the LuCI page.

The package is selected by `Config/GENERAL.txt`. It does not bind an exporter
to a network interface or create a firewall rule: those values depend on the
router's management topology and must be set after flashing.

Configure both Prometheus endpoints in **Services → CCSN Observability**. Its
system-metrics and client-accounting switches each write only their respective
exporter's UCI `enabled` option, following the SmartDNS model; Apply reloads
those services through their standard UCI triggers. Configure and manage
nlbwmon itself only in **Services → Bandwidth Monitoring**. CCSN Observability
never starts, stops, or changes it.

For non-LuCI recovery only, the equivalent Lua exporter settings are:

```sh
uci set prometheus-node-exporter-lua.main.listen_interface='MANAGEMENT_INTERFACE'
uci set prometheus-node-exporter-lua.main.listen_port='9100'
uci commit prometheus-node-exporter-lua
service prometheus-node-exporter-lua restart
```

`client_id` is derived automatically from DHCP/static-lease hostnames. Devices
without a hostname use a stable `mac_<hex>` fallback, so no MAC-to-ID alias map
is required. The `interface` label is inferred exclusively from active OpenWrt
logical interfaces and their IPv4, IPv6, and DHCPv6-PD assignment prefixes;
DHCP is never required for traffic accounting. The `family` label is normalized
to `ipv4` or `ipv6`. nlbwmon only retains connections crossing its configured local
network boundary, and the collector exports those rows with
`traffic_class="internet"`. Add every LAN, VLAN, VPN, and other non-Internet
routed network to nlbwmon's **Local interfaces** or **Local subnets**, and do
not add WAN or Internet prefixes. The source-of-truth configuration examples
and firewall guidance are maintained with the Kubernetes GitOps repository at
`network/openwrt/nlbwmon-exporter/`.

The included `luci-app-ccsn-observability` page under **Services → CCSN
Observability** manages both exporter endpoints.
The official **Services → Bandwidth Monitoring** page remains responsible for
nlbwmon's accounting engine and history.

The firmware also includes the official **Services → SNMPD** page with the
SSL-enabled Net-SNMP daemon. Manage its runtime configuration outside the
firmware image: disable the upstream v1/v2c `public` example, configure SNMPv3,
then allow UDP/161 only from the monitoring network.
