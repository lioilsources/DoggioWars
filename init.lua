-- doggiowars/init.lua
-- DoggioWars — Voxel dogfight on aerial islands
-- Luanti mod entry point

doggiowars = {}

-- Sdílené letové konstanty (čtou je vehicle.lua, tricks.lua, rabbit.lua, race.lua)
doggiowars.const = {
    SPEED_MAX    = 40,      -- m/s
    SPEED_MIN    = 5,       -- stall speed
    TURN_SPEED   = 1.5,     -- rad/s
    PITCH_RATE   = 1.2,     -- rad/s
    PITCH_MAX    = 0.6,     -- max pitch angle
    PITCH_DECAY  = 0.8,     -- pitch return-to-center rate
    ROLL_SPEED   = 1.8,     -- rad/s
    ROLL_MAX     = math.pi,
    ROLL_DECAY   = 1.5,     -- roll auto-level rate
    SPAWN_HEIGHT = 300,     -- výška spawnu / respawnu
}

local MP = minetest.get_modpath("doggiowars")

-- Load modules in dependency order
dofile(MP .. "/nodes.lua")      -- Custom blocks (must be first for content IDs)
dofile(MP .. "/biomes.lua")     -- Biome definitions
dofile(MP .. "/mapgen.lua")     -- Island generator
dofile(MP .. "/decorate.lua")   -- Post-gen decoration (trees, mushrooms, etc.)
dofile(MP .. "/hud.lua")        -- HUD (statbary, flash, race widgety)
dofile(MP .. "/tricks.lua")     -- Vstupní komba a skriptované triky
dofile(MP .. "/vehicle.lua")    -- Fighter plane entity
dofile(MP .. "/weapons.lua")    -- Projectiles, explosions, damage
dofile(MP .. "/rabbit.lua")     -- Zajíc — AI loď pro chrtí závod
dofile(MP .. "/race.lua")       -- Chrtí závod: trať, tunely, checkpointy
dofile(MP .. "/sky.lua")        -- Sky, clouds, fog

minetest.log("action", "[doggiowars] Mod loaded successfully")
