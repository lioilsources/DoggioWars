-- Verze hry a co je v ní nového — hráč ji uvidí po připojení v chatu a
-- kdykoli přes /version, takže ví, co si z ContentDB právě nainstaloval.
--
-- Při vydání: zvednout VERSION, přidat záznam NAVRCH CHANGES (a stejný do
-- CHANGELOG.md), pak tag vX.Y.Z. Release workflow odmítne tag, který
-- nesedí s VERSION.

local S = minetest.get_translator("dw_core")

doggiowars.VERSION = "2.5.1"

-- Nejnovější první. Texty jsou anglicky (zdrojový jazyk), čeština v locale.
local CHANGES = {
    {"2.5.1", {
        S("Fixed a crash on Android right after spawning (Invalid vector coordinate y)."),
    }},
    {"2.5.0", {
        S("Music: every island biome has its own theme, creatures have their own sounds."),
        S("Shot and impact sounds that depend on the material you hit."),
        S("Shots bore tunnels; a headlight lights them (/headlight)."),
        S("Bigger creatures, more of them, no longer flying through islands."),
        S("R1/L1 (RB/LB, mouse wheel) switch fighter and submarine."),
    }},
}

local function headline()
    return "DoggioWars v" .. doggiowars.VERSION
end

local function notes(entry)
    local lines = {}
    for _, line in ipairs(entry[2]) do
        lines[#lines + 1] = "  - " .. line
    end
    return table.concat(lines, "\n")
end

minetest.register_on_joinplayer(function(player)
    local latest = CHANGES[1]
    minetest.chat_send_player(player:get_player_name(),
        minetest.colorize("#FFD75E", headline()) .. "\n" .. notes(latest)
        .. "\n" .. S("All changes: /version"))
end)

minetest.register_chatcommand("version", {
    description = S("Show the game version and what changed"),
    func = function()
        local out = {headline()}
        for _, entry in ipairs(CHANGES) do
            out[#out + 1] = "v" .. entry[1] .. ":"
            out[#out + 1] = notes(entry)
        end
        return true, table.concat(out, "\n")
    end,
})

minetest.log("action", "[doggiowars] " .. headline())
