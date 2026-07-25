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
    error("invalid bounded label in ccsn-nlbwmon-exporter")
  end
  return escape_label(value)
end

local function is_bounded_label(value)
  return tostring(value or ""):lower():match("^[a-z0-9][a-z0-9_-]*$") ~= nil
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

local function ipv4_groups(address)
  local a, b, c, d = address:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
  a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
  if not a or a > 255 or b > 255 or c > 255 or d > 255 then
    return nil
  end
  return {a, b, c, d}
end

local function ipv6_groups(address)
  address = tostring(address or ""):lower():gsub("%%.*$", "")
  local ipv4_tail = address:match("([^:]+)$")
  if ipv4_tail and ipv4_tail:find(".", 1, true) then
    local octets = ipv4_groups(ipv4_tail)
    if not octets then return nil end
    address = address:sub(1, #address - #ipv4_tail)
      .. string.format("%x:%x", octets[1] * 256 + octets[2], octets[3] * 256 + octets[4])
  end

  if address:find(":::", 1, true) then return nil end
  local compressed_at = address:find("::", 1, true)
  if compressed_at and address:find("::", compressed_at + 2, true) then return nil end
  if not compressed_at and (address:sub(1, 1) == ":" or address:sub(-1) == ":") then return nil end

  local function parse_part(part)
    local groups = {}
    if part == "" then return groups end
    for group in part:gmatch("[^:]+") do
      if not group:match("^[0-9a-f]+$") or #group > 4 then return nil end
      groups[#groups + 1] = tonumber(group, 16)
    end
    return groups
  end

  local left, right
  if compressed_at then
    left = parse_part(address:sub(1, compressed_at - 1))
    right = parse_part(address:sub(compressed_at + 2))
  else
    left, right = parse_part(address), {}
  end
  if not left or not right then return nil end

  local missing = 8 - #left - #right
  if (compressed_at and missing < 1) or (not compressed_at and missing ~= 0) then return nil end
  for _ = 1, missing do left[#left + 1] = 0 end
  for _, group in ipairs(right) do left[#left + 1] = group end
  return #left == 8 and left or nil
end

local function parse_ip(address)
  local ipv4 = ipv4_groups(tostring(address or ""))
  if ipv4 then return ipv4, 8, 32, "ipv4" end
  local ipv6 = ipv6_groups(address)
  if ipv6 then return ipv6, 16, 128, "ipv6" end
  return nil
end

local function cidr_parts(cidr)
  local address, prefix = tostring(cidr or ""):match("^([^/]+)/(%d+)$")
  local groups, unit_bits, total_bits, family = parse_ip(address)
  prefix = tonumber(prefix)
  if not groups or not prefix or prefix < 0 or prefix > total_bits then return nil end
  return groups, unit_bits, total_bits, family, prefix
end

local function cidr_contains(cidr, address)
  local network, unit_bits, total_bits, _, prefix = cidr_parts(cidr)
  local candidate, candidate_unit_bits, candidate_total_bits = parse_ip(address)
  if not network or not candidate or unit_bits ~= candidate_unit_bits or total_bits ~= candidate_total_bits then
    return false
  end

  local full_groups = math.floor(prefix / unit_bits)
  for index = 1, full_groups do
    if network[index] ~= candidate[index] then return false end
  end
  local remaining_bits = prefix % unit_bits
  if remaining_bits > 0 then
    local block = 2 ^ (unit_bits - remaining_bits)
    local index = full_groups + 1
    if math.floor(network[index] / block) ~= math.floor(candidate[index] / block) then return false end
  end
  return true
end

local function normalized_cidr_key(cidr)
  local groups, unit_bits, _, family, prefix = cidr_parts(cidr)
  if not groups then return nil end
  local normalized = {}
  for index, group in ipairs(groups) do
    local remaining_bits = prefix - ((index - 1) * unit_bits)
    if remaining_bits >= unit_bits then
      normalized[index] = group
    elseif remaining_bits <= 0 then
      normalized[index] = 0
    else
      local block = 2 ^ (unit_bits - remaining_bits)
      normalized[index] = math.floor(group / block) * block
    end
  end
  return family .. ":" .. table.concat(normalized, ":") .. "/" .. tostring(prefix)
end

local function cidr_prefix(cidr)
  local _, _, _, _, prefix = cidr_parts(cidr)
  return prefix
end

local function normalized_family(value)
  value = tostring(value or ""):lower()
  if value == "4" or value == "ipv4" then return "ipv4" end
  if value == "6" or value == "ipv6" then return "ipv6" end
  error("nlbw CSV contains an unsupported address family")
end

local function load_interfaces()
  local interfaces, interface_keys = {}, {}
  local function add_interface(name, cidr)
    local cidr_key = normalized_cidr_key(cidr)
    if not is_bounded_label(name) or not cidr_key then return end
    local key = tostring(name):lower() .. "|" .. cidr_key
    if not interface_keys[key] then
      interface_keys[key] = true
      interfaces[#interfaces + 1] = {interface = bounded_label(name), cidr = cidr}
    end
  end

  local loaded, ubus = pcall(require, "ubus")
  if not loaded then error("unable to load ubus for interface discovery") end

  local connected, connection = pcall(ubus.connect)
  if not connected or not connection then error("unable to connect to ubus for interface discovery") end

  local called, status = pcall(function()
    return connection:call("network.interface", "dump", {})
  end)
  if connection and connection.close then pcall(connection.close, connection) end
  if not called or type(status) ~= "table" or type(status.interface) ~= "table" then
    error("unable to query active interfaces from ubus")
  end

  for _, interface_status in ipairs(status and status.interface or {}) do
    local name = interface_status.interface
    for _, address in ipairs(interface_status["ipv4-address"] or {}) do
      add_interface(name, tostring(address.address or "") .. "/" .. tostring(address.mask or ""))
    end
    for _, address in ipairs(interface_status["ipv6-address"] or {}) do
      add_interface(name, tostring(address.address or "") .. "/" .. tostring(address.mask or ""))
    end
    for _, assignment in ipairs(interface_status["ipv6-prefix-assignment"] or {}) do
      local address = assignment["local-address"] or assignment
      add_interface(name, tostring(address.address or "") .. "/" .. tostring(address.mask or ""))
    end
  end
  if #interfaces == 0 then error("ubus returned no active IP prefixes for logical interfaces") end
  return interfaces
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

local function interface_for_address(interfaces, address)
  local matched_interface, matched_prefix = nil, -1
  for _, interface in ipairs(interfaces) do
    if cidr_contains(interface.cidr, address) then
      local prefix = cidr_prefix(interface.cidr)
      if prefix and prefix > matched_prefix then
        matched_interface, matched_prefix = interface.interface, prefix
      elseif prefix == matched_prefix and matched_interface ~= interface.interface then
        error("ambiguous logical interface for client address")
      end
    end
  end
  return matched_interface or "unknown"
end

local function scrape_traffic(interfaces)
  local traffic = metric("openwrt_client_traffic_bytes_total", "counter")
  local connections = metric("openwrt_client_connections_total", "counter")
  local hostnames_by_ip, hostnames_by_mac = load_hostnames()
  local handle = io.popen("/usr/sbin/nlbw -c csv -n -q 2>/dev/null")
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
      client_id = automatic_client_id(hostname, mac), interface = interface_for_address(interfaces, ip), traffic_class = "internet",
      family = normalized_family(fields[header.family]), proto = escape_label(fields[header.proto]),
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

local function interface_contains_address(interfaces, interface_name, address)
  for _, interface in ipairs(interfaces) do
    if interface.interface == interface_name and cidr_contains(interface.cidr, address) then
      return true
    end
  end
  return false
end

local function scrape_dhcp(interfaces)
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
  local uci = require("uci").cursor()
  uci:foreach("dhcp", "dhcp", function(section)
    local limit = tonumber(section.limit)
    local dhcp_interfaces = type(section.interface) == "table" and section.interface or {section.interface}
    if section.ignore ~= "1" and limit then
      for _, interface_name in ipairs(dhcp_interfaces) do
        if is_bounded_label(interface_name) then
          local active, found = 0, false
          local label = bounded_label(interface_name)
          for _, interface in ipairs(interfaces) do
            if interface.interface == label then
              found = true
              break
            end
          end
          if found then
            for _, address in ipairs(addresses) do
              if interface_contains_address(interfaces, label, address) then active = active + 1 end
            end
            active_metric({interface=label}, active)
            capacity_metric({interface=label}, limit)
          end
        end
      end
    end
  end)
end

local function scrape()
  local interfaces = load_interfaces()
  scrape_traffic(interfaces)
  scrape_dhcp(interfaces)
end

return {scrape = scrape}
