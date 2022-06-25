-----------------------------
-- MTPOIMAP by beaver700nh --
-----------------------------

local function mtpoimap_get_map_name(title, escape)
  local name = minetest.formspec_escape(title)

  if name == "" then
    name = "[Unnamed Map]"

    if escape then name = minetest.formspec_escape(name) end
  else
    name = "'" .. name .. "'"
  end

  return name
end

local function mtpoimap_parse_escapes(text)
  local esctab = {
    ["\\r"] = "\r",
    ["\\n"] = "\n",
    ["\\t"] = "\t",
  }

  text = string.gsub(text, "%%", "<#>!__PERCENT__!<#>")

  for i, o in pairs(esctab) do
    text = string.gsub(text, "([^\\\\])(" .. i .. ")", "%1" .. o)
  end

  text = string.gsub(text, "<#>!__PERCENT__!<#>", "%%%%")

  return text
end

local function mtpoimap_icon_aliases(color)
  local colortab = {
    ["violet"] = "purple",
    ["grey"  ] = "gray",
  }

  for i, o in pairs(colortab) do
    color = string.gsub(color, "(" .. i .. ")", o)
  end

  return color
end

local function mtpoimap_formspec_base()
  return [=[
    formspec_version[4]
    size[12,12.5]
  ]=]
end

local function mtpoimap_formspec_title(title)
  return "label[0.5,0.5;=== Map of " .. mtpoimap_get_map_name(title, true) .. " === ]"
end

local function mtpoimap_formspec_map(file)
  return "background[0.5,1;11,11;" .. minetest.formspec_escape(file) .. "]"
end

local function mtpoimap_formspec_pois(pois)
  local fname = minetest.get_modpath("mtpoimap") .. "/" .. pois
  local file = io.open(fname, "r")

  if not file then return "" end

  local _pois = ""

  while true do
    local poi = file:read()
    if not poi then break end

    local x, y, icon, text = string.match(poi, "([^,]+),([^|]+)|([^|]+)|%s*(.*)")

    x = (tonumber(x) + 1.0) / 2 * 11.0 - 0.1
    y = (tonumber(y) + 1.0) / 2 * 11.0 - 0.1
    icon = mtpoimap_icon_aliases(string.match(icon, "^%s*(.-)%s*$"))
    text = mtpoimap_parse_escapes(text)

    local rect = string.format("%f,%f;0.2,0.2", x, y)

    _pois = _pois .. string.format("image[%s;mtpoimap_poiicon_%s.png]tooltip[%s;%s]", rect, icon, rect, text)
  end

  file:close()

  return "container[0.5,1]" .. _pois .. "container_end[]"
end

local function mtpoimap_formspec_reload()
  return "button[10,0.25;1.5,0.5;reload;Reload]"
end

local function mtpoimap_formspec_full(title, file, pois)
  return (
    mtpoimap_formspec_base() ..
    mtpoimap_formspec_title(title) ..
    mtpoimap_formspec_map(file) ..
    mtpoimap_formspec_pois(pois) ..
    mtpoimap_formspec_reload()
  )
end

local function mtpoimap_formspec_init()
  return [=[
    formspec_version[4]
    size[8,7]
    field[1,1;6,1;map_name;Name of map for infotext;Points of Interest]
    field[1,3;6,1;map_file;File name of map texture;defaultmap.png]
    field[1,5;6,1;map_pois;Relative path to POI list file;pois/defaultpois.txt]
  ]=]
end

local function mtpoimap_after_place_node(pos, placer, itemstack, pointed_thing)
  if not (placer and placer:is_player() and minetest.check_player_privs(placer, "creative")) then return end

  local meta = minetest.get_meta(pos)

  meta:set_string("infotext", "Uninitialized POI Map")
  meta:set_string("formspec", mtpoimap_formspec_init())
end

local function mtpoimap_on_receive_fields(pos, formname, fields, sender)
  if fields.map_name and fields.map_file then
    if fields.map_file == "" then
      if sender:is_player() then
        minetest.chat_send_player(sender:get_player_name(), "Error: You must specify the file name of the map.")
      end

      return
    end

    local infotext = "POI Map: " .. mtpoimap_get_map_name(fields.map_name, false)
    local formspec = mtpoimap_formspec_full(fields.map_name, fields.map_file, fields.map_pois)

    local meta = minetest.get_meta(pos)

    meta:set_string("infotext", infotext)
    meta:set_string("formspec", formspec)
    meta:set_string("poisfile", fields.map_pois)

  elseif fields.reload then
    if not sender:is_player() then return end
    if not minetest.check_player_privs(sender, "server") then
      minetest.chat_send_player(sender:get_player_name(), "Error: You must have access to the server to reload a POI map.")
    end

    local meta = minetest.get_meta(pos)

    local oldfs = meta:get_string("formspec")
    local pois = mtpoimap_formspec_pois(meta:get_string("poisfile"))
    local newfs = string.gsub(oldfs, "(container.*)", pois .. mtpoimap_formspec_reload())

    meta:set_string("formspec", newfs)
  end
end

minetest.register_on_player_receive_fields(mtpoimap_on_receive_fields)

minetest.register_node(
  "mtpoimap:mtpoimap",
  {
    description = "Point of Interest Map",
    tiles = {"mtpoimap_mtpoimap.png"},
    is_ground_content = false,
    groups = {oddly_breakable_by_hand = 1, choppy = 2, not_in_creative_inventory = 1},
    after_place_node = mtpoimap_after_place_node,
    on_receive_fields = mtpoimap_on_receive_fields,
  }
)
