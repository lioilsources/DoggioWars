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
