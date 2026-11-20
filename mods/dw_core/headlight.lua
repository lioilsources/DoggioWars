-- doggiowars/headlight.lua
-- Světlomet — kužel světla před stíhačkou, ať se v provrtaných tunelech
-- dá letět.
--
-- Luanti nemá dynamická světla: světlo umí jen node. Proto každých pár
-- desetin sekundy vystřelíme z hráčova pohledu svazek paprsků (kužel),
-- a kde paprsek narazí do stěny, posadíme do vzduchu před ní neviditelný
-- svítící node. Světlo se z něj rozlije na okolní stěny. Při dalším
-- kroku se staré nody uklidí a nové přisednou o kus dál.
--
-- Na denním světle se nic nesází (get_natural_light) — venku by to jen
-- zbytečně přepočítávalo osvětlení mapy.

local S = minetest.get_translator("dw_core")

local HEADLIGHT   = "doggiowars:headlight"
local INTERVAL    = 0.15    -- s mezi přepočty kuželu
local RANGE       = 32      -- m dosvit paprsku
local START       = 3       -- m před pilotem (ať nesvítí do vlastního trupu)
local CONE_HALF   = math.rad(20)  -- poloviční úhel kuželu
local RING        = 8       -- paprsků po obvodu kuželu (+1 ve středu)
local AXIS_STEP   = 10      -- m mezi světly podél osy, když je tunel dlouhý
local DARK        = 11      -- přirozené světlo pod tímhle = je tma, svítíme

minetest.register_node(":" .. HEADLIGHT, {
    description          = "Headlight beam",
    drawtype             = "airlike",
    paramtype            = "light",
    light_source         = minetest.LIGHT_MAX,
    sunlight_propagates  = true,
    walkable             = false,
    pointable            = false,
    diggable             = false,
    buildable_to         = true,
    floodable            = true,
    drop                 = "",
    groups               = {not_in_creative_inventory = 1},
})

doggiowars.HEADLIGHT_NODE = HEADLIGHT

-- Stav na hráče: { on = bool, nodes = { [hash] = pos } }
local state = {}
-- Všechny živé nody světlometu napříč hráči — pro úklid zbloudilých
local owned = {}

local function st(name)
    local s = state[name]
    if not s then
        s = {on = true, nodes = {}}
        state[name] = s
    end
    return s
end

local function remove_at(pos)
    if minetest.get_node(pos).name == HEADLIGHT then
        minetest.remove_node(pos)
    end
end

local function clear(name)
    local s = state[name]
    if not s then return end
    for h, pos in pairs(s.nodes) do
        owned[h] = nil
        remove_at(pos)
    end
    s.nodes = {}
end

-- Ortonormální báze kolem směru pohledu
local function basis(dir)
    local up = {x = 0, y = 1, z = 0}
    if math.abs(dir.y) > 0.95 then up = {x = 1, y = 0, z = 0} end
    local right = vector.normalize(vector.cross(dir, up))
    local up2 = vector.cross(right, dir)
    return right, up2
end

local function cone_dirs(dir)
    local dirs = {dir}
    local right, up2 = basis(dir)
    local c, s = math.cos(CONE_HALF), math.sin(CONE_HALF)
    for i = 0, RING - 1 do
        local a = i / RING * 2 * math.pi
        local side = vector.add(vector.multiply(right, math.cos(a)),
            vector.multiply(up2, math.sin(a)))
        dirs[#dirs + 1] = vector.add(vector.multiply(dir, c),
            vector.multiply(side, s))
    end
    return dirs
end

local function is_dark(pos)
    local l = minetest.get_natural_light(pos)
    return l ~= nil and l < DARK
end

-- Kam posadit světla pro jeden snímek: buňky vzduchu těsně před stěnou,
-- kde paprsek narazil, a pár bodů podél osy pro delší tunel.
local function targets(eye, dir)
    local out, seen = {}, {}
    local function add(p)
        p = vector.round(p)
        local h = minetest.hash_node_position(p)
        if seen[h] then return end
        seen[h] = true
        out[#out + 1] = {h = h, p = p}
    end

    for i, d in ipairs(cone_dirs(dir)) do
        local from = vector.add(eye, vector.multiply(d, START))
        local to = vector.add(eye, vector.multiply(d, RANGE))
        local hit
        for pointed in minetest.raycast(from, to, false, false) do
            if pointed.type == "node" then
                hit = pointed
                break
            end
        end
        if hit then
            add(hit.above)
        end
        -- osa kuželu: světla i ve volném prostoru, ať není prázdno uprostřed
        if i == 1 then
            local len = hit and vector.distance(eye, hit.above) or RANGE
            for t = START + 2, len - 2, AXIS_STEP do
                add(vector.add(eye, vector.multiply(d, t)))
            end
        end
    end
    return out
end

local function update(player)
    local name = player:get_player_name()
    local s = st(name)
    if not s.on or player:get_hp() <= 0 then
        clear(name)
        return
    end

    local eye = player:get_pos()
    if not eye then return end
    eye = vector.add(eye, {x = 0, y = player:get_properties().eye_height or 1.5, z = 0})
    local dir = player:get_look_dir()

    local want = {}
    if is_dark(vector.round(eye)) or is_dark(vector.round(
            vector.add(eye, vector.multiply(dir, RANGE / 2)))) then
        for _, t in ipairs(targets(eye, dir)) do
            if is_dark(t.p) then want[t.h] = t.p end
        end
    end

    -- pryč se starými, které už nejsou v kuželu
    for h, pos in pairs(s.nodes) do
        if not want[h] then
            s.nodes[h] = nil
            owned[h] = nil
            remove_at(pos)
        end
    end
    -- nové jen do čistého vzduchu; cizí node nikdy nepřepíšeme
    for h, pos in pairs(want) do
        if not s.nodes[h] and not owned[h]
                and minetest.get_node(pos).name == "air" then
            minetest.set_node(pos, {name = HEADLIGHT})
            s.nodes[h] = pos
            owned[h] = true
        end
    end
end

local timer = 0
minetest.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer < INTERVAL then return end
    timer = 0
    for _, player in ipairs(minetest.get_connected_players()) do
        update(player)
    end
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    clear(name)
    state[name] = nil
end)

minetest.register_on_shutdown(function()
    for name in pairs(state) do clear(name) end
end)

-- Úklid po pádu serveru: světla uložená v mapě nikomu nepatří
minetest.register_lbm({
    label             = "Remove stale headlight beams",
    name              = "dw_core:headlight_cleanup",
    nodenames         = {HEADLIGHT},
    run_at_every_load = true,
    action            = function(pos)
        if not owned[minetest.hash_node_position(pos)] then
            minetest.remove_node(pos)
        end
    end,
})

minetest.register_abm({
    label     = "Remove orphan headlight beams",
    nodenames = {HEADLIGHT},
    interval  = 3,
    chance    = 1,
    action    = function(pos)
        if not owned[minetest.hash_node_position(pos)] then
            minetest.remove_node(pos)
        end
    end,
})

minetest.register_chatcommand("headlight", {
    params      = "[on|off]",
    description = S("Toggle the fighter's headlight"),
    func        = function(name, param)
        local s = st(name)
        if param == "on" then s.on = true
        elseif param == "off" then s.on = false
        else s.on = not s.on end
        if not s.on then clear(name) end
        return true, s.on and S("Headlight on.") or S("Headlight off.")
    end,
})
