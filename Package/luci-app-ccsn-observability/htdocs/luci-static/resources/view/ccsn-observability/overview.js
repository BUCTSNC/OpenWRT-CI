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
			_("Configure Prometheus endpoints and DHCP-aware client accounting. Client IDs use DHCP hostnames and fall back to MAC addresses when no hostname is available. Firewall access is managed separately.")
		);

		s = m.section(form.NamedSection, "main", "settings");
		s.anonymous = true;
		s.tab("endpoints", _("Exporter endpoints"));
		s.tab("dhcp", _("DHCP pools"));

		o = s.taboption("endpoints", form.Value, "_ucode_interface", _("System exporter interface"), _("Logical management interface for system, Wi-Fi, dnsmasq, and conntrack metrics on TCP/9101. Do not bind this endpoint to an untrusted WAN interface."));
		o.datatype = "uciname";
		exporterOption(o, "prometheus-node-exporter-ucode", "main", "listen_interface", "loopback");

		o = s.taboption("endpoints", form.Value, "_ucode_port", _("System exporter port"));
		o.datatype = "range(1,65535)";
		exporterOption(o, "prometheus-node-exporter-ucode", "main", "listen_port", "9101");

		o = s.taboption("endpoints", form.Flag, "_wifi_stations", _("Collect Wi-Fi station totals"), _("Collect station-level metrics locally. The Kubernetes scrape policy drops raw Wi-Fi station series before ingestion."));
		o.enabled = "1";
		o.disabled = "0";
		exporterOption(o, "prometheus-node-exporter-ucode", "wifi", "stations", "1");

		o = s.taboption("endpoints", form.Value, "_lua_interface", _("Client-accounting exporter interface"), _("Logical management interface for nlbwmon client accounting on TCP/9100."));
		o.datatype = "uciname";
		exporterOption(o, "prometheus-node-exporter-lua", "main", "listen_interface", "loopback");

		o = s.taboption("endpoints", form.Value, "_lua_port", _("Client-accounting exporter port"));
		o.datatype = "range(1,65535)";
		exporterOption(o, "prometheus-node-exporter-lua", "main", "listen_port", "9100");

		o = s.taboption("endpoints", form.Value, "default_network", _("Fallback client network"), _("Used only when a client address does not match any DHCP pool CIDR."));
		o.rmempty = false;
		o.validate = labelValidator(_("Fallback client network"));

		o = s.taboption("endpoints", form.Value, "default_traffic_class", _("Default traffic class"), _("Bounded label attached to client traffic, for example internet or internal."));
		o.rmempty = false;
		o.validate = labelValidator(_("Default traffic class"));

		s = m.section(form.GridSection, "dhcp_pool", _("DHCP pools"), _("Each pool maps an IPv4 CIDR to a network label. Pool capacity is read from the referenced DHCP section; active leases and client network labels are inferred automatically."));
		s.anonymous = true;
		s.addremove = true;

		o = s.option(form.Value, "network", _("Network label"), _("Stable label such as lan, guest, or iot."));
		o.rmempty = false;
		o.validate = labelValidator(_("Network label"));

		o = s.option(form.Value, "dhcp_section", _("DHCP section"), _("UCI section name in /etc/config/dhcp, usually lan."));
		o.datatype = "uciname";
		o.rmempty = false;

		o = s.option(form.Value, "cidr", _("IPv4 CIDR"), _("Subnet used to assign clients to this network label."));
		o.datatype = "cidr4";
		o.rmempty = false;

		return m.render();
	}
});
