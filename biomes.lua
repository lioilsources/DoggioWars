-- aerowars/biomes.lua
-- Definice 6 biomů a jejich materiálů

aerowars = aerowars or {}
aerowars.biome_ids = {}  -- content ID cache

local c = aerowars.biome_ids

local function init_content_ids()
    c.air        = minetest.get_content_id("air")
    c.stone      = minetest.get_content_id("default:stone")
    c.dirt       = minetest.get_content_id("default:dirt")
    c.grass      = minetest.get_content_id("default:dirt_with_grass")
    c.ice        = minetest.get_content_id("default:ice")
    c.snow       = minetest.get_content_id("default:snowblock")
    c.obsidian   = minetest.get_content_id("default:obsidian")
    c.lava       = minetest.get_content_id("default:lava_source")
    c.sand       = minetest.get_content_id("default:sand")
    c.water      = minetest.get_content_id("default:water_source")
    c.coral      = minetest.get_content_id("default:coral_skeleton")
    c.clay       = minetest.get_content_id("default:clay")
    c.mycelium   = minetest.get_content_id("aerowars:spore_block")
    c.magma      = minetest.get_content_id("aerowars:magma_block")
    c.dead_stone = minetest.get_content_id("aerowars:dead_stone")

    -- Fallback: coral_skeleton might not exist in all versions
    if not c.coral or c.coral == c.air then
        c.coral = c.stone
    end
end

minetest.after(0, init_content_ids)

-- Biome definitions
-- Each biome has: name, shape style, surface material fn, core material fn
aerowars.biomes = {
    [0] = { -- VERDANT
        name    = "verdant",
        shape   = "avatar",
        surface = function(depth)
            if depth == 0 then return c.grass end
            if depth <= 3 then return c.dirt end
            return c.stone
        end,
        core = function() return c.stone end,
    },
    [1] = { -- GLACIAL
        name    = "glacial",
        shape   = "disc",
        surface = function(depth)
            if depth == 0 then return c.snow end
            if depth <= 2 then return c.ice end
            return c.stone
        end,
        core = function() return c.ice end,
    },
    [2] = { -- VOLCANIC
        name    = "volcanic",
        shape   = "cone",
        surface = function(depth)
            if depth == 0 then return c.magma end
            return c.obsidian
        end,
        core = function() return c.obsidian end,
    },
    [3] = { -- ATOLL
        name    = "atoll",
        shape   = "disc",
        surface = function(depth)
            if depth == 0 then return c.sand end
            if depth <= 2 then return c.clay end
            return c.stone
        end,
        core = function() return c.stone end,
    },
    [4] = { -- MYCELIAL
        name    = "mycelial",
        shape   = "avatar",
        surface = function(depth)
            if depth == 0 then return c.mycelium end
            return c.dirt
        end,
        core = function() return c.dirt end,
    },
    [5] = { -- BARREN
        name    = "barren",
        shape   = "cone",
        surface = function(depth)
            if depth == 0 then return c.dead_stone end
            return c.stone
        end,
        core = function() return c.stone end,
    },
}
