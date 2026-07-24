-- aerowars/sky.lua
-- Sky, clouds, and fog setup for the aerial world

local SKY_COLOR     = "#2e3155"
-- Mraky jen jako řídká, vysoká clona NAD hracím pásmem (ostrovy jsou
-- ve výšce ~ -400..1400). Hustá deka uprostřed vypadala jako hladina moře.
local CLOUD_HEIGHT  = 1500
local CLOUD_DENSITY = 0.2
local CLOUD_SPEED   = {x = 2, z = 0}

-- Spawn point in the sky
local SPAWN_HEIGHT  = aerowars.const.SPAWN_HEIGHT

-- Check if set_fog is available (Luanti 5.16+)
local has_set_fog = minetest.features and minetest.features.object_step_has_moveresult ~= nil

---------------------------------------------------------------------------
-- Zafixované poledne — ostrovy jsou vždy plně nasvícené, hvězdy nad nimi
-- (neměníme time_speed v globálním configu, jen periodicky vracíme čas)
---------------------------------------------------------------------------

minetest.after(0, function()
    minetest.set_timeofday(0.5)
end)

local noon_timer = 0
minetest.register_globalstep(function(dtime)
    noon_timer = noon_timer + dtime
    if noon_timer < 5 then return end
    noon_timer = 0
    minetest.set_timeofday(0.5)
end)

minetest.register_on_joinplayer(function(player)
    -- Dark blue skybox
    player:set_sky({
        type       = "plain",
        base_color = SKY_COLOR,
        clouds     = true,
    })

    -- Upper cloud layer
    player:set_clouds({
        density   = CLOUD_DENSITY,
        height    = CLOUD_HEIGHT,
        thickness = 12,
        speed     = CLOUD_SPEED,
        color     = "#e8e8f0a0",
    })

    -- Set sun/moon for atmosphere
    player:set_sun({
        visible = true,
        scale   = 1.5,
    })
    player:set_moon({
        visible = true,
        scale   = 1.2,
    })
    player:set_stars({
        visible    = true,
        count      = 2000,
        star_color = "#ffffffa0",
    })

    -- Teleport to sky spawn on first join
    local name = player:get_player_name()
    local meta = player:get_meta()
    if meta:get_int("aerowars_spawned") == 0 then
        meta:set_int("aerowars_spawned", 1)
        local sp = aerowars.spawn_pos and aerowars.spawn_pos()
            or {x = 0, y = SPAWN_HEIGHT, z = 0}
        player:set_pos(sp)
        minetest.chat_send_player(name,
            "Welcome to AeroWars! You ARE the fighter — fly!")
    end

    -- Každý join: hráč rovnou letí (malé zpoždění, ať klient doinicializuje;
    -- selhání pokryje watchdog ve vehicle.lua)
    minetest.after(0.2, function()
        local p = minetest.get_player_by_name(name)
        if not p or aerowars.get_player_fighter(p) then return end
        local pos = p:get_pos()
        aerowars.mount_player(p, {
            x = pos.x,
            y = math.max(pos.y + 2, 100),
            z = pos.z,
        })
    end)
end)
