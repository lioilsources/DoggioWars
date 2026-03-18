-- aerowars/sky.lua
-- Sky, clouds, and fog setup for the aerial world

local SKY_COLOR     = "#1a1a2e"
local CLOUD_HEIGHT  = 750
local CLOUD_DENSITY = 0.9
local CLOUD_SPEED   = {x = 2, z = 0}

-- Spawn point in the sky
local SPAWN_HEIGHT  = 300

-- Check if set_fog is available (Luanti 5.16+)
local has_set_fog = minetest.features and minetest.features.object_step_has_moveresult ~= nil

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
        thickness = 30,
        speed     = CLOUD_SPEED,
        color     = "#e8e8f0e0",
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
    local meta = player:get_meta()
    if meta:get_int("aerowars_spawned") == 0 then
        meta:set_int("aerowars_spawned", 1)
        local spawn_pos = {x = 0, y = SPAWN_HEIGHT, z = 0}
        player:set_pos(spawn_pos)
        -- Grant fly + fast for testing
        local privs = minetest.get_player_privs(player:get_player_name())
        privs.fly = true
        privs.fast = true
        minetest.set_player_privs(player:get_player_name(), privs)
        minetest.chat_send_player(player:get_player_name(),
            "Welcome to AeroWars! Use /spawn_fighter to get a plane.")
    end
end)
