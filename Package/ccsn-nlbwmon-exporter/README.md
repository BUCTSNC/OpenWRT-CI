# CCSN nlbwmon exporter package

This local package installs `ccsn_nlbwmon.lua` into the official
`prometheus-node-exporter-lua` collector directory and creates an initially
empty `/etc/config/ccsn-nlbwmon-exporter` UCI configuration.

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

Then add controlled device aliases and DHCP pools to
`/etc/config/ccsn-nlbwmon-exporter`. The source-of-truth configuration examples
and firewall guidance are maintained with the Kubernetes GitOps repository at
`network/openwrt/nlbwmon-exporter/`.
