-- aerowars/decorate.lua
-- Post-mapgen decoration: trees, mushrooms, icicles, lava pools

aerowars = aerowars or {}

---------------------------------------------------------------------------
-- Tree placement (Verdant biome)
---------------------------------------------------------------------------

function aerowars.place_tree(x, surface_y, z)
    local trunk_h = math.random(4, 7)
    -- Trunk
    for dy = 1, trunk_h do
        local pos = {x = x, y = surface_y + dy, z = z}
        if minetest.get_node(pos).name == "air" then
            minetest.set_node(pos, {name = "default:tree"})
        end
    end
    -- Leaves (simple sphere)
    local top = surface_y + trunk_h
    for dx = -2, 2 do
        for dy = -1, 2 do
            for dz = -2, 2 do
                if dx * dx + dy * dy + dz * dz <= 6 then
                    local pos = {x = x + dx, y = top + dy, z = z + dz}
                    if minetest.get_node(pos).name == "air" then
                        minetest.set_node(pos, {name = "default:leaves"})
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Giant mushroom (Mycelial biome)
---------------------------------------------------------------------------

function aerowars.place_giant_mushroom(island)
    local angle = math.random() * math.pi * 2
    local r = math.random(0, math.floor(island.radius * 0.6))
    local mx = math.floor(island.x + math.cos(angle) * r)
    local mz = math.floor(island.z + math.sin(angle) * r)

    -- Find surface
    local surface_y = nil
    for y = island.y + math.floor(island.radius * 0.6), island.y - island.radius, -1 do
        local node = minetest.get_node({x = mx, y = y, z = mz})
        if node.name ~= "air" and node.name ~= "ignore" then
            surface_y = y
            break
        end
    end
    if not surface_y then return end

    -- Stem
    local stem_h = math.random(4, 9)
    for dy = 1, stem_h do
        local pos = {x = mx, y = surface_y + dy, z = mz}
        if minetest.get_node(pos).name == "air" then
            minetest.set_node(pos, {name = "default:tree"})
        end
    end

    -- Cap (flat disc of spore blocks)
    local cap_r = math.random(2, 4)
    local top = surface_y + stem_h + 1
    for dx = -cap_r, cap_r do
        for dz = -cap_r, cap_r do
            if dx * dx + dz * dz <= cap_r * cap_r then
                local pos = {x = mx + dx, y = top, z = mz + dz}
                if minetest.get_node(pos).name == "air" then
                    minetest.set_node(pos, {name = "aerowars:spore_block"})
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Icicles (Glacial biome) — hanging from island edges
---------------------------------------------------------------------------

function aerowars.place_icicles(island)
    local count = math.random(5, 15)
    for i = 1, count do
        local angle = math.random() * math.pi * 2
        -- Place near the edge
        local r = island.radius * (0.7 + math.random() * 0.3)
        local ix = math.floor(island.x + math.cos(angle) * r)
        local iz = math.floor(island.z + math.sin(angle) * r)

        -- Find bottom of island at this column
        local bottom_y = nil
        for y = island.y, island.y - math.floor(island.radius * 1.5), -1 do
            local node = minetest.get_node({x = ix, y = y, z = iz})
            if node.name ~= "air" and node.name ~= "ignore" then
                bottom_y = y
            elseif bottom_y then
                break
            end
        end
        if not bottom_y then
            bottom_y = island.y
        end

        -- Hang icicles down
        local icicle_len = math.random(3, 8)
        for dy = 1, icicle_len do
            local pos = {x = ix, y = bottom_y - dy, z = iz}
            if minetest.get_node(pos).name == "air" then
                minetest.set_node(pos, {name = "aerowars:ice_crystal"})
            end
        end
    end
end

---------------------------------------------------------------------------
-- Lava pool on top (Volcanic biome)
---------------------------------------------------------------------------

function aerowars.place_lava_pool(island)
    local pool_r = math.random(2, math.max(3, math.floor(island.radius * 0.2)))

    -- Find the top of the island center
    local top_y = nil
    for y = island.y + math.floor(island.radius * 0.6), island.y, -1 do
        local node = minetest.get_node({x = island.x, y = y, z = island.z})
        if node.name ~= "air" and node.name ~= "ignore" then
            top_y = y
            break
        end
    end
    if not top_y then return end

    -- Place lava in a disc on top
    for dx = -pool_r, pool_r do
        for dz = -pool_r, pool_r do
            if dx * dx + dz * dz <= pool_r * pool_r then
                local pos = {x = island.x + dx, y = top_y + 1, z = island.z + dz}
                if minetest.get_node(pos).name == "air" then
                    minetest.set_node(pos, {name = "default:lava_source"})
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Atoll center water fill
---------------------------------------------------------------------------

function aerowars.fill_atoll_center(island)
    -- Fill the center hole of the disc with water
    local hole_r = math.floor(island.radius * 0.4)

    -- Find approximate surface height
    local surface_y = nil
    for y = island.y + 10, island.y - 10, -1 do
        local edge_node = minetest.get_node({x = island.x + hole_r + 2, y = y, z = island.z})
        if edge_node.name ~= "air" and edge_node.name ~= "ignore" then
            surface_y = y
            break
        end
    end
    if not surface_y then return end

    for dx = -hole_r, hole_r do
        for dz = -hole_r, hole_r do
            if dx * dx + dz * dz <= hole_r * hole_r then
                local pos = {x = island.x + dx, y = surface_y + 1, z = island.z + dz}
                if minetest.get_node(pos).name == "air" then
                    minetest.set_node(pos, {name = "default:water_source"})
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Waterfall from verdant island edge
---------------------------------------------------------------------------

function aerowars.place_waterfall(island)
    -- Pick a random edge point
    local angle = math.random() * math.pi * 2
    local edge_x = math.floor(island.x + math.cos(angle) * (island.radius - 2))
    local edge_z = math.floor(island.z + math.sin(angle) * (island.radius - 2))

    -- Find top
    local top_y = nil
    for y = island.y + math.floor(island.radius * 0.6), island.y, -1 do
        local node = minetest.get_node({x = edge_x, y = y, z = edge_z})
        if node.name ~= "air" and node.name ~= "ignore" then
            top_y = y
            break
        end
    end
    if not top_y then return end

    -- Cascade water down
    for y = top_y + 1, top_y - 30, -1 do
        local pos = {x = edge_x, y = y, z = edge_z}
        local node = minetest.get_node(pos)
        if node.name == "air" then
            minetest.set_node(pos, {name = "default:water_flowing"})
        elseif y < top_y then
            break
        end
    end
end

---------------------------------------------------------------------------
-- Main decoration dispatch — called after mapgen
---------------------------------------------------------------------------

function aerowars.decorate_island(island)
    local biome = island.biome
    if not biome then return end

    if biome.name == "verdant" then
        -- Trees
        local tree_count = math.random(3, math.max(4, math.floor(island.radius * 0.1)))
        for i = 1, tree_count do
            local angle = math.random() * math.pi * 2
            local r = math.random(0, math.floor(island.radius * 0.7))
            local tx = math.floor(island.x + math.cos(angle) * r)
            local tz = math.floor(island.z + math.sin(angle) * r)
            -- Find surface
            for y = island.y + math.floor(island.radius * 0.6), island.y - 5, -1 do
                local node = minetest.get_node({x = tx, y = y, z = tz})
                if node.name ~= "air" and node.name ~= "ignore" then
                    aerowars.place_tree(tx, y, tz)
                    break
                end
            end
        end
        -- Occasional waterfall
        if math.random() < 0.4 then
            aerowars.place_waterfall(island)
        end

    elseif biome.name == "glacial" then
        aerowars.place_icicles(island)

    elseif biome.name == "volcanic" then
        aerowars.place_lava_pool(island)

    elseif biome.name == "atoll" then
        aerowars.fill_atoll_center(island)

    elseif biome.name == "mycelial" then
        local mush_count = math.random(2, 6)
        for i = 1, mush_count do
            aerowars.place_giant_mushroom(island)
        end
    end
    -- Barren: no decoration (intentional)
end

---------------------------------------------------------------------------
-- Hook into mapgen to decorate after generation
-- Uses minetest.after to ensure nodes are placed before decorating
---------------------------------------------------------------------------

local decorated_cells = {}

minetest.register_on_generated(function(minp, maxp, blockseed)
    if maxp.y < -200 or minp.y > 800 then return end

    local seed = tonumber(minetest.get_mapgen_setting("seed") or 42) or 42
    local islands = aerowars.get_islands_for_chunk(minp, maxp, seed)

    for _, island in ipairs(islands) do
        -- Use grid cell as unique key to avoid double-decorating
        local key = math.floor(island.x / aerowars.ISLAND_GRID) .. ":"
                 .. math.floor(island.z / aerowars.ISLAND_GRID)

        if not decorated_cells[key] then
            decorated_cells[key] = true
            -- Delay decoration so that mapgen voxelmanip has written the base terrain
            minetest.after(1, function()
                aerowars.decorate_island(island)
            end)
        end
    end
end)
