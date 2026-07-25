# CCSN nlbwmon exporter package

This local package installs `ccsn_nlbwmon.lua` into the official
`prometheus-node-exporter-lua` collector directory and creates a minimal UCI
configuration for default client labels and DHCP pool definitions.

The package is selected by `Config/GENERAL.txt`. It does not bind an exporter
to a network interface or create a firewall rule: those values depend on the
router's management topology and must be set after flashing.

Configure the Lua exporter on the management interface and enable it:

```sh
uci set prometheus-node-exporter-lua.main.listen_interface='MANAGEMENT_INTERFACE'
uci set prometheus-node-exporter-lua.main.listen_port='9100'
uci commit prometheus-node-exporter-lua
service nlbwmon enable
service nlbwmon restart
service prometheus-node-exporter-lua enable
service prometheus-node-exporter-lua restart
```

`client_id` is derived automatically from DHCP/static-lease hostnames. Devices
without a hostname use a stable `mac_<hex>` fallback, so no MAC-to-ID alias map
is required. Client network labels are inferred from DHCP pool CIDRs. Add DHCP
pools to `/etc/config/ccsn-nlbwmon-exporter`. The
source-of-truth configuration examples and firewall guidance are maintained
with the Kubernetes GitOps repository at `network/openwrt/nlbwmon-exporter/`.

The included `luci-app-ccsn-observability` page under **Services → CCSN
Observability** manages both exporter endpoints, default client labels, and DHCP
pools.
The official **Services → Bandwidth Monitoring** page remains responsible for
nlbwmon's accounting engine and history.

The firmware also includes the official **Services → SNMPD** page with the
SSL-enabled Net-SNMP daemon. Manage its runtime configuration outside the
firmware image: disable the upstream v1/v2c `public` example, configure SNMPv3,
then allow UDP/161 only from the monitoring network.
