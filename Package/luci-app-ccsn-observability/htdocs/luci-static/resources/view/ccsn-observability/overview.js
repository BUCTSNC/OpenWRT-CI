"use strict";
"require form";
"require tools.widgets as widgets";
"require uci";
"require view";

function exporterOption(option, config, section, name, fallback) {
	option.cfgvalue = function() {
		return uci.get(config, section, name) || fallback;
	};
	option.write = function(sectionId, value) {
		uci.set(config, section, name, value);
	};
	option.remove = function() {
		uci.unset(config, section, name);
	};
	option.rmempty = false;
}

function exporterEnabledOption(option, config) {
	option.cfgvalue = function() {
		return uci.get(config, "main", "enabled") === "0" ? "0" : "1";
	};
	option.write = function(_, value) {
		uci.set(config, "main", "enabled", value);
	};
	option.remove = function() {
		uci.unset(config, "main", "enabled");
	};
	option.rmempty = false;
}

return view.extend({
	load: function() {
		return Promise.all([
			uci.load("ccsn-nlbwmon-exporter"),
			uci.load("prometheus-node-exporter-lua"),
			uci.load("prometheus-node-exporter-ucode")
		]);
	},

	render: function() {
		var m, s, o;

		m = new form.Map(
			"ccsn-nlbwmon-exporter",
			_("CCSN Observability"),
			_("Configure Prometheus endpoints and client accounting. OpenWrt logical interfaces are the only network identity; their active IPv4, IPv6, and DHCPv6-PD assignment prefixes are discovered automatically. VLANs work with local DHCP, external DHCP, DHCP relay, or static addressing. Client IDs use locally known hostnames and fall back to MAC addresses. Firewall access is managed separately.")
		);

		s = m.section(form.NamedSection, "main", "settings");
		s.anonymous = true;
		s.tab("general", _("General"));
		s.tab("endpoints", _("Exporter endpoints"));

		o = s.taboption("general", form.Flag, "_ucode_enabled", _("Enable system metrics exporter"), _("Enable the system, Wi-Fi, dnsmasq, and conntrack endpoint on TCP/9101. Apply reloads this exporter from its own UCI configuration."));
		o.enabled = "1";
		o.disabled = "0";
		o.default = "1";
		exporterEnabledOption(o, "prometheus-node-exporter-ucode");

		o = s.taboption("general", form.Flag, "_lua_enabled", _("Enable client-accounting exporter"), _("Enable the nlbwmon client-accounting endpoint on TCP/9100. This controls only the Prometheus endpoint; configure nlbwmon accounting separately in Services → Bandwidth Monitoring."));
		o.enabled = "1";
		o.disabled = "0";
		o.default = "1";
		exporterEnabledOption(o, "prometheus-node-exporter-lua");

		o = s.taboption("endpoints", widgets.NetworkSelect, "_ucode_interface", _("System exporter interface"), _("Logical management interface for system, Wi-Fi, dnsmasq, and conntrack metrics on TCP/9101. Do not bind this endpoint to an untrusted WAN interface."));
		o.nocreate = true;
		exporterOption(o, "prometheus-node-exporter-ucode", "main", "listen_interface", "loopback");

		o = s.taboption("endpoints", form.Value, "_ucode_port", _("System exporter port"));
		o.datatype = "range(1,65535)";
		exporterOption(o, "prometheus-node-exporter-ucode", "main", "listen_port", "9101");

		o = s.taboption("endpoints", form.Flag, "_wifi_stations", _("Collect Wi-Fi station totals"), _("Collect station-level metrics locally. The Kubernetes scrape policy drops raw Wi-Fi station series before ingestion."));
		o.enabled = "1";
		o.disabled = "0";
		exporterOption(o, "prometheus-node-exporter-ucode", "wifi", "stations", "1");

		o = s.taboption("endpoints", widgets.NetworkSelect, "_lua_interface", _("Client-accounting exporter interface"), _("Logical management interface for nlbwmon client accounting on TCP/9100."));
		o.nocreate = true;
		exporterOption(o, "prometheus-node-exporter-lua", "main", "listen_interface", "loopback");

		o = s.taboption("endpoints", form.Value, "_lua_port", _("Client-accounting exporter port"));
		o.datatype = "range(1,65535)";
		exporterOption(o, "prometheus-node-exporter-lua", "main", "listen_port", "9100");

		return m.render();
	}
});
