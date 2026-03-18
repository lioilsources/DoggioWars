-- aerowars/init.lua
-- AeroWars — Voxel dogfight on aerial islands
-- Luanti mod entry point

aerowars = {}

local MP = minetest.get_modpath("aerowars")

-- Load modules in dependency order
dofile(MP .. "/nodes.lua")      -- Custom blocks (must be first for content IDs)
dofile(MP .. "/biomes.lua")     -- Biome definitions
dofile(MP .. "/mapgen.lua")     -- Island generator
dofile(MP .. "/decorate.lua")   -- Post-gen decoration (trees, mushrooms, etc.)
dofile(MP .. "/vehicle.lua")    -- Fighter plane entity
dofile(MP .. "/sky.lua")        -- Sky, clouds, fog

minetest.log("action", "[aerowars] Mod loaded successfully")
