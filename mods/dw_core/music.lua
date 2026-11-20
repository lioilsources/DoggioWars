-- doggiowars/music.lua
-- Hudba ostrovů: každý biom má svoje téma, a když hráč přilétá k jinému
-- ostrovu, předchozí téma pomalu odezní a nové se roztočí. Mezi ostrovy
-- hraje téma oblohy.
--
-- Bytosti mají vlastní smyčky (monsters.lua je pouští přes
-- doggiowars.creature_sound) — poziční zvuk připnutý k hlavě, takže se
-- do tématu ostrova domíchají samy, jak se k nim hráč blíží.
--
-- Soubory leží v mods/dw_core/sounds/ (viz README tam). Chybějící soubor
-- znamená ticho, ne chybu — kód jde do hry dřív, než hudba existuje.

local S = minetest.get_translator("dw_core")
local MP = minetest.get_modpath("dw_core")

local CHECK_INTERVAL = 1     -- s mezi kontrolami, u kterého ostrova hráč je
local ENTER_MARGIN   = 120   -- m za okrajem ostrova už hraje jeho téma
local LEAVE_MARGIN   = 220   -- m za okrajem se vrací obloha (hystereze)
local FADE_TIME      = 6     -- s crossfade mezi tématy

local function setting(name, default)
    return tonumber(minetest.settings:get(name)) or default
end
local MUSIC_GAIN    = setting("dw_music_volume", 0.6)
local CREATURE_GAIN = setting("dw_creature_volume", 0.8)

---------------------------------------------------------------------------
-- Které zvuky opravdu existují (Luanti bere i varianty name.1.ogg, ...)
---------------------------------------------------------------------------

local available = {}
for _, f in ipairs(minetest.get_dir_list(MP .. "/sounds", false) or {}) do
    local base = f:match("^(.-)%.%d+%.ogg$") or f:match("^(.-)%.ogg$")
    if base then available[base] = true end
end

function doggiowars.has_sound(name)
    return available[name] == true
end

---------------------------------------------------------------------------
-- Bytosti: smyčka připnutá k entitě
---------------------------------------------------------------------------

-- Vrací handle (pro sound_stop) nebo nil, když zvuk neexistuje.
-- hear = do jaké vzdálenosti server zvuk hráčům vůbec pošle; útlum se
-- vzdáleností řeší klient, takže zblízka je bytost slyšet víc.
function doggiowars.creature_sound(obj, species, hear)
    local name = "dw_creature_" .. species
    if not available[name] then return nil end
    return minetest.sound_play(name, {
        object            = obj,
        loop              = true,
        gain              = CREATURE_GAIN,
        max_hear_distance = hear or 250,
    })
end

---------------------------------------------------------------------------
-- Témata ostrovů
---------------------------------------------------------------------------

local SKY = "sky"
local players = {}   -- name -> {theme = "verdant", handle = h, island = key, on = bool}

local function theme_sound(theme)
    local name = "dw_music_" .. theme
    return available[name] and name or nil
end

local function fade_out(handle)
    if handle then
        -- fade na 0 zvuk po doznění sám zastaví
        minetest.sound_fade(handle, MUSIC_GAIN / FADE_TIME, 0)
    end
end

local function switch_theme(name, st, theme)
    if st.theme == theme then return end
    fade_out(st.handle)
    st.handle, st.theme = nil, theme
    local snd = st.on and theme_sound(theme)
    if snd then
        st.handle = minetest.sound_play(snd, {
            to_player = name,
            loop      = true,
            gain      = MUSIC_GAIN,
            fade      = MUSIC_GAIN / FADE_TIME,   -- nájezd z ticha
        })
    end
end

local world_seed
local function seed()
    world_seed = world_seed or doggiowars.get_world_seed()
    return world_seed
end

-- Které téma má teď hrát: biom blízkého ostrova, nebo obloha
local function wanted_theme(st, pos)
    local isl, dist = doggiowars.nearest_island(pos.x, pos.z, seed())
    if not isl then return SKY end
    local edge = dist - isl.radius
    local biome = isl.biome and isl.biome.name
    if edge <= ENTER_MARGIN and biome then return biome end
    -- v pásmu mezi ENTER a LEAVE držet, co hraje (ať téma neblikne)
    if edge <= LEAVE_MARGIN and st.theme == biome then return biome end
    return SKY
end

local timer = 0
minetest.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer < CHECK_INTERVAL then return end
    timer = 0
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local st = players[name]
        local pos = player:get_pos()
        if st and pos then
            switch_theme(name, st, wanted_theme(st, pos))
        end
    end
end)

minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    local on = player:get_meta():get_string("dw_music") ~= "off"
    players[name] = {on = on}
end)

minetest.register_on_leaveplayer(function(player)
    players[player:get_player_name()] = nil
end)

minetest.register_chatcommand("music", {
    params      = "[on|off]",
    description = S("Toggle island music"),
    func        = function(name, param)
        local st = players[name]
        local player = minetest.get_player_by_name(name)
        if not st or not player then return false end
        if param == "on" then st.on = true
        elseif param == "off" then st.on = false
        else st.on = not st.on end
        player:get_meta():set_string("dw_music", st.on and "on" or "off")
        -- přehrát znovu: vypnutí ztlumí, zapnutí roztočí aktuální téma
        local theme = st.theme
        st.theme = nil
        if st.on then
            switch_theme(name, st, theme or SKY)
        else
            fade_out(st.handle)
            st.handle = nil
            st.theme = theme
        end
        return true, st.on and S("Music on.") or S("Music off.")
    end,
})

local n_music, n_creature = 0, 0
for k in pairs(available) do
    if k:find("^dw_music_") then n_music = n_music + 1 end
    if k:find("^dw_creature_") then n_creature = n_creature + 1 end
end
minetest.log("action", string.format(
    "[doggiowars] music: %d themes, %d creature loops", n_music, n_creature))
