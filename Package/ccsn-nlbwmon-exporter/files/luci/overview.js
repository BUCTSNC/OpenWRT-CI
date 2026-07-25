"use strict";
"require form";
"require uci";
"require view";

function boundedLabel(value) {
	return /^[a-z0-9][a-z0-9_-]*$/.test(value);
}

function labelValidator(title) {
	return function(sectionId, value) {
		return boundedLabel(value) || _("%s must use lowercase letters, digits, hyphens, or underscores.").format(title);
	};
}

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
			_("Configure Prometheus exporter endpoints and stable client aliases. The official Netlink Bandwidth Monitor pages remain available under Services > Bandwidth Monitoring.")
		);

		s = m.section(form.NamedSection, "main", "settings");
		s.anonymous = true;
		s.tab("endpoints", _("Exporter endpoints"));
		s.tab("dhcp", _("DHCP pools"));

		o = s.taboption("endpoints", form.Value, "_ucode_interface", _("System exporter interface"), _("Logical interface for the ucode endpoint on TCP/9101. Use the management interface, not an untrusted WAN interface."));
		o.datatype = "uciname";
		exporterOption(o, "prometheus-node-exporter-ucode", "main", "listen_interface", "loopback");

		o = s.taboption("endpoints", form.Value, "_ucode_port", _("System exporter port"));
		o.datatype = "range(1,65535)";
		exporterOption(o, "prometheus-node-exporter-ucode", "main", "listen_port", "9101");

		o = s.taboption("endpoints", form.Flag, "_wifi_stations", _("Collect Wi-Fi station totals"), _("Raw station MAC series are dropped before metrics ingestion."));
		o.enabled = "1";
		o.disabled = "0";
		exporterOption(o, "prometheus-node-exporter-ucode", "wifi", "stations", "1");

		o = s.taboption("endpoints", form.Value, "_lua_interface", _("Client-accounting exporter interface"), _("Logical interface for the Lua endpoint on TCP/9100."));
		o.datatype = "uciname";
		exporterOption(o, "prometheus-node-exporter-lua", "main", "listen_interface", "loopback");

		o = s.taboption("endpoints", form.Value, "_lua_port", _("Client-accounting exporter port"));
		o.datatype = "range(1,65535)";
		exporterOption(o, "prometheus-node-exporter-lua", "main", "listen_port", "9100");

		o = s.taboption("endpoints", form.Value, "default_network", _("Default client network"));
		o.rmempty = false;
		o.validate = labelValidator(_("Default client network"));

		o = s.taboption("endpoints", form.Value, "default_traffic_class", _("Default traffic class"));
		o.rmempty = false;
		o.validate = labelValidator(_("Default traffic class"));

		s = m.section(form.GridSection, "dhcp_pool", _("DHCP pools"), _("Capacity is read from the referenced DHCP section; active leases and client network labels are inferred from this IPv4 CIDR."));
		s.anonymous = true;
		s.addremove = true;

		o = s.option(form.Value, "network", _("Network"));
		o.rmempty = false;
		o.validate = labelValidator(_("Network"));

		o = s.option(form.Value, "dhcp_section", _("DHCP section"));
		o.datatype = "uciname";
		o.rmempty = false;

		o = s.option(form.Value, "cidr", _("IPv4 CIDR"));
		o.datatype = "cidr4";
		o.rmempty = false;

		return m.render();
	}
});
