# luci-app-ccsn-observability

This LuCI application edits only the UCI configuration for the two Prometheus
exporters and the CCSN nlbwmon collector. It does not create firewall rules,
configure SNMP, or embed router-specific interface and client data.

Client IDs are derived from DHCP/static-lease hostnames and fall back to
`mac_<hex>`. DHCP pool CIDRs assign the `network` label and provide pool capacity
for monitoring. Simplified Chinese translations live under `po/zh_Hans/` and
are compiled by the standard LuCI build system. After changing user-visible
JavaScript strings, run `sh tools/update-po.sh` and translate any new entries.
