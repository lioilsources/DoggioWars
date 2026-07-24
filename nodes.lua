-- aerowars/nodes.lua
-- Custom bloky pro biomy

minetest.register_node("aerowars:spore_block", {
    description = "Spore Block",
    tiles = {"aerowars_spore.png"},
    groups = {crumbly = 2, soil = 1},
    sounds = default.node_sound_dirt_defaults(),
})

minetest.register_node("aerowars:magma_block", {
    description = "Magma Block",
    tiles = {"aerowars_magma.png"},
    light_source = 8,
    damage_per_second = 2,
    groups = {cracky = 2},
    sounds = default.node_sound_stone_defaults(),
})

minetest.register_node("aerowars:ice_crystal", {
    description = "Ice Crystal",
    tiles = {"aerowars_ice_crystal.png"},
    use_texture_alpha = "blend",
    drawtype = "glasslike",
    paramtype = "light",
    sunlight_propagates = true,
    groups = {cracky = 3},
    sounds = default.node_sound_glass_defaults(),
})

minetest.register_node("aerowars:dead_stone", {
    description = "Dead Stone",
    tiles = {"aerowars_dead_stone.png"},
    groups = {cracky = 2},
    sounds = default.node_sound_stone_defaults(),
})

-- Žhavé uhlíky — svítí, lehce pálí (spálené / ohnivé ostrovy)
minetest.register_node("aerowars:embers", {
    description = "Embers",
    tiles = {"aerowars_embers.png"},
    light_source = 10,
    damage_per_second = 1,
    groups = {crumbly = 2, cracky = 3},
    sounds = default.node_sound_stone_defaults(),
})

-- Popel — sypká vrstva po požáru
minetest.register_node("aerowars:ash", {
    description = "Ash",
    tiles = {"aerowars_ash.png"},
    groups = {crumbly = 3, falling_node = 1},
    sounds = default.node_sound_sand_defaults(),
})

-- Bahno — bažinné ostrovy
minetest.register_node("aerowars:mud", {
    description = "Mud",
    tiles = {"aerowars_mud.png"},
    groups = {crumbly = 3, soil = 1},
    sounds = default.node_sound_dirt_defaults(),
})

-- Svítící krystal — krystalové ostrovy
minetest.register_node("aerowars:crystal", {
    description = "Glowing Crystal",
    tiles = {"aerowars_crystal.png"},
    light_source = 12,
    use_texture_alpha = "opaque",
    paramtype = "light",
    groups = {cracky = 2},
    sounds = default.node_sound_glass_defaults(),
})

-- Čedič — sopečné / spálené jádro
minetest.register_node("aerowars:basalt", {
    description = "Basalt",
    tiles = {"aerowars_basalt.png"},
    groups = {cracky = 2},
    sounds = default.node_sound_stone_defaults(),
})

-- Mechový kámen — bažiny, vlhké oblasti
minetest.register_node("aerowars:mossy_stone", {
    description = "Mossy Stone",
    tiles = {"aerowars_mossy_stone.png"},
    groups = {cracky = 2},
    sounds = default.node_sound_stone_defaults(),
})
