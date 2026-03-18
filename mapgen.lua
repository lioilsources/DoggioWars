-- aerowars/mapgen.lua
-- Generátor vzdušných ostrovů s profily a biomy

aerowars = aerowars or {}

-- Parametry světa
local ISLAND_LAYER_MIN = 50
local ISLAND_LAYER_MAX = 600
local CLOUD_FLOOR      = -200
local CLOUD_CEIL       = 800
local ISLAND_GRID      = 256   -- grid cell size for island placement
local RADIUS_MIN       = 20
local RADIUS_MAX       = 100

-- Content ID cache (populated after all nodes registered)
local c_air
local c_stone

local function init_mapgen_ids()
    c_air   = minetest.get_content_id("air")
    c_stone = minetest.get_content_id("default:stone")
end

minetest.after(0, init_mapgen_ids)

---------------------------------------------------------------------------
-- Island shape profiles
---------------------------------------------------------------------------

local function island_profile(base_r, y_rel, style)
    if style == "avatar" then
        -- Rounded dome on top, exponential tail below
        if y_rel >= 0 then
            local cap_h = base_r * 0.6
            if cap_h <= 0 then return 0 end
            return base_r * math.max(0, 1 - (y_rel / cap_h) ^ 2)
        else
            local tail_len = base_r * 0.5
            if tail_len <= 0 then return 0 end
            return base_r * math.exp(y_rel / tail_len)
        end

    elseif style == "disc" then
        -- Flat disc / atoll shape
        local half_h = math.max(base_r * 0.12, 3)
        return base_r * math.max(0, 1 - math.abs(y_rel) / half_h)

    elseif style == "cone" then
        -- Inverted cone (volcano hanging point-down)
        return base_r * math.max(0, 1 - math.abs(y_rel) / base_r)
    end
    return 0
end

---------------------------------------------------------------------------
-- Deterministic hash for island placement
---------------------------------------------------------------------------

local function hash_2d(cx, cz, seed)
    -- Simple integer hash — deterministic per grid cell
    local h = cx * 73856093 + cz * 19349663 + seed
    -- Lua 5.1 compatible bit mixing via arithmetic
    h = math.abs(h)
    h = (h * 1103515245 + 12345) % 2147483648
    return h
end

---------------------------------------------------------------------------
-- Get all islands whose bounding box overlaps a chunk
---------------------------------------------------------------------------

local function get_islands_for_chunk(minp, maxp, seed)
    local islands = {}
    -- We need to check neighboring grid cells too, because large islands
    -- can extend beyond their own cell
    local margin = RADIUS_MAX * 2
    local cx0 = math.floor((minp.x - margin) / ISLAND_GRID)
    local cx1 = math.floor((maxp.x + margin) / ISLAND_GRID)
    local cz0 = math.floor((minp.z - margin) / ISLAND_GRID)
    local cz1 = math.floor((maxp.z + margin) / ISLAND_GRID)

    for cx = cx0, cx1 do
        for cz = cz0, cz1 do
            local h = hash_2d(cx, cz, seed)

            -- Island center position within its grid cell
            local ox = (h % ISLAND_GRID) + cx * ISLAND_GRID
            h = (h * 1103515245 + 12345) % 2147483648
            local oz = (h % ISLAND_GRID) + cz * ISLAND_GRID
            h = (h * 1103515245 + 12345) % 2147483648
            local oy = ISLAND_LAYER_MIN + (h % (ISLAND_LAYER_MAX - ISLAND_LAYER_MIN))

            -- Radius
            h = (h * 1103515245 + 12345) % 2147483648
            local radius = RADIUS_MIN + (h % (RADIUS_MAX - RADIUS_MIN))

            -- Biome (6 types)
            h = (h * 1103515245 + 12345) % 2147483648
            local biome_idx = h % 6

            -- Y extent for this island shape
            local biome = aerowars.biomes[biome_idx]
            if biome then
                local y_extent_up   = radius * 0.6  -- dome top
                local y_extent_down = radius * 1.5   -- tail / cone extent

                -- Only include if this island overlaps the chunk
                if ox + radius >= minp.x and ox - radius <= maxp.x
                   and oz + radius >= minp.z and oz - radius <= maxp.z
                   and oy + y_extent_up >= minp.y and oy - y_extent_down <= maxp.y then
                    table.insert(islands, {
                        x = ox,
                        y = oy,
                        z = oz,
                        radius = radius,
                        biome_idx = biome_idx,
                        biome = biome,
                    })
                end
            end
        end
    end
    return islands
end

---------------------------------------------------------------------------
-- Surface depth calculation — how many solid blocks above this one
---------------------------------------------------------------------------

local function calc_surface_depth(x, y, z, island, area, data)
    -- Check upward from current position to find how deep we are from surface
    local depth = 0
    for check_y = y + 1, y + 5 do
        local dx = x - island.x
        local dz = z - island.z
        local dist = math.sqrt(dx * dx + dz * dz)
        local y_rel = check_y - island.y
        local limit = island_profile(island.radius, y_rel, island.biome.shape)
        if dist <= limit then
            depth = depth + 1
        else
            break
        end
    end
    return depth
end

---------------------------------------------------------------------------
-- Main mapgen callback
---------------------------------------------------------------------------

local mapgen_seed = nil

minetest.register_on_generated(function(minp, maxp, blockseed)
    -- Only generate in the relevant altitude band
    if maxp.y < CLOUD_FLOOR or minp.y > CLOUD_CEIL then return end

    -- Get the world seed once
    if not mapgen_seed then
        mapgen_seed = minetest.get_mapgen_setting("seed") or 42
        mapgen_seed = tonumber(mapgen_seed) or 42
    end

    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local data = vm:get_data()
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})

    local islands = get_islands_for_chunk(minp, maxp, mapgen_seed)

    if #islands == 0 then return end

    local modified = false

    for _, island in ipairs(islands) do
        local biome = island.biome
        local shape = biome.shape

        -- Vertical bounds for this island within the chunk
        local y_extent_up   = island.radius * 0.6
        local y_extent_down = island.radius * 1.5
        local y_min = math.max(minp.y, math.floor(island.y - y_extent_down))
        local y_max = math.min(maxp.y, math.ceil(island.y + y_extent_up))

        -- Horizontal bounds
        local x_min = math.max(minp.x, math.floor(island.x - island.radius))
        local x_max = math.min(maxp.x, math.ceil(island.x + island.radius))
        local z_min = math.max(minp.z, math.floor(island.z - island.radius))
        local z_max = math.min(maxp.z, math.ceil(island.z + island.radius))

        for z = z_min, z_max do
            local dz = z - island.z
            for x = x_min, x_max do
                local dx = x - island.x
                local dist_xz = math.sqrt(dx * dx + dz * dz)

                for y = y_max, y_min, -1 do
                    local y_rel = y - island.y
                    local limit = island_profile(island.radius, y_rel, shape)

                    if dist_xz <= limit then
                        local vi = area:index(x, y, z)
                        -- Only place if currently air (don't overwrite other islands)
                        if data[vi] == c_air then
                            -- Determine surface depth
                            local depth = calc_surface_depth(x, y, z, island, area, data)
                            data[vi] = biome.surface(depth)
                            modified = true
                        end
                    end
                end
            end
        end
    end

    if modified then
        vm:set_data(data)
        vm:calc_lighting()
        vm:write_to_map()
        vm:update_liquids()
    end
end)

---------------------------------------------------------------------------
-- Disable default mapgen (no caves, no ores, no decorations underground)
---------------------------------------------------------------------------

minetest.register_on_mapgen_init(function(mgparams)
    minetest.set_mapgen_params({
        mgname = "singlenode",
        flags  = "nolight",
    })
end)

---------------------------------------------------------------------------
-- Export for decoration system
---------------------------------------------------------------------------

aerowars.get_islands_for_chunk = get_islands_for_chunk
aerowars.island_profile = island_profile
aerowars.ISLAND_GRID = ISLAND_GRID
