local function escape_label(value)
  value = tostring(value or "")
  value = value:gsub("\\", "\\\\")
  value = value:gsub('"', '\\"')
  value = value:gsub("[\r\n]", "")
  return value
end

local function bounded_label(value, fallback)
  value = tostring(value or fallback or "unknown"):lower()
  if not value:match("^[a-z0-9][a-z0-9_-]*$") then
    error("invalid bounded label in ccsn-nlbwmon-exporter config")
  end
  return escape_label(value)
end

local function automatic_client_id(hostname, mac)
  local normalized = tostring(hostname or ""):lower()
  normalized = normalized:gsub("[^a-z0-9]+", "-")
  normalized = normalized:gsub("^-+", ""):gsub("-+$", "")
  if normalized ~= "" and normalized ~= "unknown" then
    return normalized
  end
  local compact_mac = tostring(mac or ""):gsub("[^0-9a-f]", "")
  return compact_mac ~= "" and "mac_" .. compact_mac or "mac_unknown"
end

local function split_tsv(line)
  local fields = {}
  for field in (line .. "\t"):gmatch("(.-)\t") do
    if field:sub(1, 1) == '"' and field:sub(-1) == '"' then
      field = field:sub(2, -2)
    end
    fields[#fields + 1] = field
  end
  return fields
end

local function ipv4_number(address)
  local a, b, c, d = address:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
  a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
  if not a or a > 255 or b > 255 or c > 255 or d > 255 then
    return nil
  end
  return ((a * 256 + b) * 256 + c) * 256 + d
end

local function cidr_contains(cidr, address)
  local network, prefix = cidr:match("^([^/]+)/(%d+)$")
  local network_number = network and ipv4_number(network)
  local address_number = ipv4_number(address)
  prefix = tonumber(prefix)
  if not network_number or not address_number or not prefix or prefix < 0 or prefix > 32 then
    return false
  end
  local block = 2 ^ (32 - prefix)
  return math.floor(network_number / block) == math.floor(address_number / block)
end

local function load_config()
  local uci = require("uci").cursor()
  local settings = uci:get_all("ccsn-nlbwmon-exporter", "main") or {}
  local pools = {}

  uci:foreach("ccsn-nlbwmon-exporter", "dhcp_pool", function(section)
    local pool_size = tonumber(uci:get("dhcp", section.dhcp_section, "limit"))
    if not pool_size or not tostring(section.cidr or ""):match("^[0-9.]+/%d+$") then
      error("invalid DHCP pool in ccsn-nlbwmon-exporter config")
    end
    pools[#pools + 1] = {
      network = bounded_label(section.network, section[".name"]),
      cidr = section.cidr,
      pool_size = pool_size,
    }
  end)

  return pools, {
    network = bounded_label(settings.default_network or settings.unknown_network, "unknown"),
    traffic_class = bounded_label(settings.default_traffic_class or settings.unknown_traffic_class, "internet"),
  }
end

local function load_hostnames()
  local by_ip, by_mac = {}, {}
  local leases = io.open("/tmp/dhcp.leases", "r")
  if leases then
    for line in leases:lines() do
      local mac, ip, hostname = line:match("^%S+%s+(%S+)%s+(%S+)%s+(%S+)")
      if hostname and hostname ~= "*" then
        by_ip[ip] = hostname
        by_mac[tostring(mac):lower()] = hostname
      end
    end
    leases:close()
  end

  local uci = require("uci").cursor()
  uci:foreach("dhcp", "host", function(section)
    if section.name then
      if section.ip then by_ip[section.ip] = section.name end
      if section.mac then by_mac[tostring(section.mac):lower()] = section.name end
    end
  end)
  return by_ip, by_mac
end

local function network_for_address(pools, address, fallback)
  for _, pool in ipairs(pools) do
    if cidr_contains(pool.cidr, address) then
      return pool.network
    end
  end
  return fallback
end

local function scrape_traffic(pools, defaults)
  local traffic = metric("openwrt_client_traffic_bytes_total", "counter")
  local connections = metric("openwrt_client_connections_total", "counter")
  local hostnames_by_ip, hostnames_by_mac = load_hostnames()
  local handle = io.popen("/usr/bin/nlbw -c csv -n -q 2>/dev/null")
  if not handle then error("unable to execute nlbw") end

  local header_line = handle:read("*l")
  if not header_line then
    handle:close()
    error("nlbw returned no CSV header")
  end
  local header = {}
  for index, name in ipairs(split_tsv(header_line)) do header[name] = index end
  for _, name in ipairs({"family", "proto", "port", "mac", "ip", "conns", "rx_bytes", "tx_bytes"}) do
    if not header[name] then
      handle:close()
      error("nlbw CSV is missing column " .. name)
    end
  end

  for line in handle:lines() do
    local fields = split_tsv(line)
    local mac = tostring(fields[header.mac] or ""):lower()
    local ip = tostring(fields[header.ip] or "")
    local hostname = hostnames_by_ip[ip] or hostnames_by_mac[mac] or "unknown"
    local labels = {
      client_id = automatic_client_id(hostname, mac), network = network_for_address(pools, ip, defaults.network), traffic_class = defaults.traffic_class,
      family = escape_label(fields[header.family]), proto = escape_label(fields[header.proto]),
      port = escape_label(fields[header.port]), mac = escape_label(mac), ip = escape_label(ip),
      hostname = escape_label(hostname),
      layer7 = escape_label(header.layer7 and fields[header.layer7] or "unknown"),
    }
    local receive_labels, transmit_labels = {}, {}
    for key, value in pairs(labels) do receive_labels[key], transmit_labels[key] = value, value end
    receive_labels.direction, transmit_labels.direction = "rx", "tx"
    traffic(receive_labels, tonumber(fields[header.rx_bytes]) or 0)
    traffic(transmit_labels, tonumber(fields[header.tx_bytes]) or 0)
    connections(labels, tonumber(fields[header.conns]) or 0)
  end
  handle:close()
end

local function scrape_dhcp(pools)
  local active_metric = metric("openwrt_dhcp_active_leases", "gauge")
  local capacity_metric = metric("openwrt_dhcp_pool_addresses", "gauge")
  local addresses = {}
  local leases = io.open("/tmp/dhcp.leases", "r")
  if leases then
    for line in leases:lines() do
      local address = line:match("^%S+%s+%S+%s+(%S+)")
      if address then addresses[#addresses + 1] = address end
    end
    leases:close()
  end
  for _, pool in ipairs(pools) do
    local active = 0
    for _, address in ipairs(addresses) do if cidr_contains(pool.cidr, address) then active = active + 1 end end
    active_metric({network=pool.network}, active)
    capacity_metric({network=pool.network}, pool.pool_size)
  end
end

local function scrape()
  local pools, defaults = load_config()
  scrape_traffic(pools, defaults)
  scrape_dhcp(pools)
end

return {scrape = scrape}
