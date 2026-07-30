# DoggioWars — Fáze 1: Nekonečný létající svět
### Luanti Mod Development Plan · 4 Týdny

---

## Přehled fáze

**Cíl:** Hráč sedí v letadle a prolétá nekonečným světem vzdušných ostrovů.
Ostrovy se generují za letu (chunk streaming), mají různé biomy a tvary.
Svět nemá tvrdé hranice — nahoru i dolů jsou mlžné vrstvy mraků.

```
Vstupní stav:  Prázdný Luanti mod
Výstupní stav: Funkční protoletový sandbox — "wow moment" při prvním průletu
```

---

## Technický stack

| Komponenta | Technologie | Poznámka |
|---|---|---|
| Engine | Luanti (C++ / IrrlichtMT) | bez Unity, bez buildu |
| Scripting | Lua 5.1 / LuaJIT | live reload za běhu |
| Modding API | `minetest.*` namespace | vše co potřebuješ |
| Assety | `.obj` / `.b3d` + `.png` | Kenney.nl CC0 |
| Server | built-in dedikovaný | `--server` flag |
| Platform | macOS (M2 nativní) | `brew install luanti` |

---

## Struktura modu

```
doggiowars/
  mod.conf          ← název, verze, závislosti
  init.lua          ← entry point, načte vše
  mapgen.lua        ← generátor ostrovů
  biomes.lua        ← definice biomů a jejich bloků
  nodes.lua         ← custom bloky (spore, magma, ice-crystal…)
  vehicle.lua       ← letadlo entita
  hud.lua           ← altimeter, speed (přijde ve fázi 2)
  assets/
    models/
      fighter_01.obj
    textures/
      fighter_01.png
      …
    sounds/
      engine_loop.ogg
```

---

## Svět — vertikální struktura

```
Y = +800   ████████████  STROP — věčné mraky (render fog cutoff)
           ░░░░░░░░░░░░  husté mraky, nulová viditelnost

Y = +400   🏔️  🌋  🏔️   Horní vrstva ostrovů (vzácné, velké)
Y = +200   🗻  🍄  🧊   Střední vrstva ostrovů (nejhustší)
Y =   +50  🌊  🏔️  💀   Dolní vrstva ostrovů (malé, roztříštěné)

           ░░░░░░░░░░░░  husté mraky
Y = -200   ████████████  SPODEK — věčné mraky
```

Hráč nikde nenarazí na zeď. Mraky jsou **psychologická bariéra** — vstoupit do nich lze, ale nevidíš nic (fog = 0). X/Z jsou nekonečné přes chunk streaming.

---

## Biomy — 6 typů

### 🌿 Verdant
- **Povrch:** tráva, stromy (oak / pine), keře, vodopády přes okraj
- **Podloží:** hlína → kámen
- **Tvar:** oblé avatar břicho, "Hallelujah Mountains"
- **Velikost:** střední, průměr 50–200 bloků

### 🧊 Glacial
- **Povrch:** packed ice, snow, ledové trhliny
- **Podloží:** blue ice → stone, rampouchy dolů
- **Tvar:** plochý vršek, ostré rampouchy na spodku
- **Velikost:** velký a plochý, 200–500 bloků průměr

### 🌋 Volcanic
- **Povrch:** obsidian, lava pools, damage zone kolem
- **Podloží:** magma-style bloky, tepelné záření (damage aura pro pozdější fáze)
- **Tvar:** převrácený kužel = sopka visící hrotem dolů
- **Velikost:** malý ale vysoký kužel

### 🌊 Atoll
- **Povrch:** písek, koral, mělká voda uprostřed prstence
- **Podloží:** stone + clay
- **Tvar:** tenký létající talíř s dírou uprostřed — průlet středem!
- **Velikost:** velký průměr, tenký (10–20 bloků výška)

### 🍄 Mycelial
- **Povrch:** mycelium, giant mushrooms, bioluminiscence v noci
- **Podloží:** dirt, custom spore bloky, mlha kolem ostrova
- **Tvar:** lehce asymetrický kapkový
- **Velikost:** střední, členitý povrch

### 💀 Barren
- **Povrch:** cracked stone, dead bushes, dust
- **Podloží:** stone, coal, iron (mineable — základ pro stavění)
- **Tvar:** roztříštěný cluster menších kamenů
- **Velikost:** různé, i velmi malé (5 bloků) — trosky

---

## Tvar ostrovů — matematický profil

```lua
-- island_profile(base_r, y_rel, style) → radius na dané výšce
-- y_rel = 0 je střed ostrova

-- AVATAR: oblé nahoře, ocas dolů
if y_rel >= 0 then
    r = base_r * (1 - (y_rel / cap_h)^2)   -- kupole
else
    r = base_r * math.exp(y_rel / tail_len) -- exponenciální zužení
end

-- DISC: talíř / atoll
r = base_r * (1 - math.abs(y_rel) / half_h)

-- CONE: kužel / sopka
r = base_r * math.max(0, 1 - math.abs(y_rel) / base_r)
```

---

## macOS Setup

### 1. Instalace

```bash
brew install luanti
# nebo stáhnout .dmg z https://www.luanti.org/downloads/
```

### 2. Adresáře

```bash
# Data dir:
~/Library/Application Support/luanti/

# Mod — doporučeno přes symlink:
ln -s ~/Projects/doggiowars \
  ~/Library/Application\ Support/luanti/mods/doggiowars
```

### 3. Dev server config

```bash
# ~/luanti-dev.conf
creative_mode = true
enable_damage = true
default_privs = interact, shout, fly, fast
# fly + fast = testování mapgenu bez létadla
```

```bash
# Spuštění serveru:
/Applications/Luanti.app/Contents/MacOS/luanti \
  --server \
  --world ~/luanti-worlds/doggiowars-dev \
  --config ~/luanti-dev.conf
```

### 4. Live reload

```
# V Luanti chatu během hry:
/reload doggiowars

# Lua kód se reloadne okamžitě.
# Mapgen změny = přeleť do nenavštíveného chunku.
```

---

## Závislosti

| Co | Potřeba? | Poznámka |
|---|---|---|
| Unity | ❌ NE | vůbec |
| Blender | ⚡ volitelné | jen pokud budeš modelovat vlastní assety |
| Xcode | ❌ NE | |
| Node / npm | ❌ NE | |
| Homebrew | ✅ doporučeno | jen pro `brew install luanti` |

---

## Assety — minimální sada pro Fázi 1

### Kde stáhnout (CC0 / zdarma)

```
Kenney.nl:
  https://kenney.nl/assets/space-kit        ← letadla .obj
  https://kenney.nl/assets/nature-kit       ← stromy, kameny

Luanti ContentDB (hotové mody k rozebrat):
  https://content.luanti.org/
  → "aircraft"    : letadlo .b3d modely + základní fyzika
  → "ethereal"    : krásné stromy a biomy
  → "skywars"     : sky-island inspirace
```

### Soubory pro Fázi 1

```
doggiowars/assets/models/
  fighter_01.obj          ← z Kenney Space Kit

doggiowars/assets/textures/
  fighter_01.png          ← 128×128
  particle_engine.png     ← výfukové částice
  node_grass.png          ← vlastní tráva (nebo default Luanti)
  node_ice.png
  node_obsidian.png
  node_mycelium.png
  node_sand.png
  node_dead_stone.png

doggiowars/assets/sounds/
  engine_loop.ogg         ← motor (smyčka)
  whoosh.ogg              ← průlet vzduchomm
```

---

---

# Týden 1 — Mod Skeleton + Základní Mapgen

**Cíl:** Ostrovy se generují (jen z kamene), chunky streamují za letu.

## Úkoly

### 1.1 — mod.conf a init.lua

```lua
-- mod.conf
name = doggiowars
description = Voxel dogfight na vzdušných ostrovech
depends = default
min_minetest_version = 5.8
```

```lua
-- init.lua
local MP = minetest.get_modpath("doggiowars")
dofile(MP .. "/nodes.lua")
dofile(MP .. "/biomes.lua")
dofile(MP .. "/mapgen.lua")
-- dofile(MP .. "/vehicle.lua")  ← přijde v týdnu 3
```

### 1.2 — nodes.lua (custom bloky)

```lua
-- Registrace custom bloků pro biomy
minetest.register_node("doggiowars:spore_block", {
    description = "Spore Block",
    tiles = {"doggiowars_spore.png"},
    groups = {crumbly = 2, soil = 1},
})

minetest.register_node("doggiowars:magma_block", {
    description = "Magma Block",
    tiles = {"doggiowars_magma.png"},
    light_source = 8,
    damage_per_second = 2,  -- damage aura
    groups = {cracky = 2},
})

minetest.register_node("doggiowars:ice_crystal", {
    description = "Ice Crystal",
    tiles = {"doggiowars_ice_crystal.png"},
    use_texture_alpha = "blend",
    groups = {cracky = 3},
    sunlight_propagates = true,
})
```

### 1.3 — mapgen.lua (základní kostra)

```lua
-- mapgen.lua
local c_air   = minetest.get_content_id("air")
local c_stone = minetest.get_content_id("default:stone")

-- Parametry světa
local ISLAND_LAYER_MIN = 50
local ISLAND_LAYER_MAX = 600
local CLOUD_FLOOR      = -200
local CLOUD_CEIL       = 800

-- Noise parametry pro rozmístění ostrovů
local np_islands = {
    offset   = 0,
    scale    = 1,
    spread   = {x = 300, y = 80, z = 300},
    seed     = 42,
    octaves  = 3,
    persist  = 0.5,
    lacunarity = 2.0,
}

minetest.register_on_generated(function(minp, maxp, seed)
    -- Generuj jen relevantní výškové pásmo
    if maxp.y < CLOUD_FLOOR or minp.y > CLOUD_CEIL then return end

    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local data = vm:get_data()
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})

    local nobj = minetest.get_perlin_map(np_islands, {
        x = maxp.x - minp.x + 1,
        y = maxp.y - minp.y + 1,
        z = maxp.z - minp.z + 1,
    })
    local nvals = nobj:get_3d_map_flat(minp)

    local idx3d = 1
    for z = minp.z, maxp.z do
    for y = minp.y, maxp.y do
    for x = minp.x, maxp.x do
        local n = nvals[idx3d]
        local vi = area:index(x, y, z)

        -- Vzdušná vrstva: generuj ostrovy
        if y >= ISLAND_LAYER_MIN and y <= ISLAND_LAYER_MAX then
            if n > 0.55 then
                data[vi] = c_stone  -- pevná hmota ostrova
            end
        end

        idx3d = idx3d + 1
    end end end

    vm:set_data(data)
    vm:calc_lighting()
    vm:write_to_map()
    vm:update_liquids()
end)
```

### 1.4 — Ověření v praxi

```
1. Spusť server (viz macOS Setup)
2. Připoj se klientem
3. /grant <jméno> fly fast
4. Přelez hráče do výšky ~200-400
5. Ostrovy z kamene by se měly generovat
6. Přelez dál — ověř chunk streaming
```

## Výstup týdne 1
- ✅ Mod se načte bez chyb
- ✅ Kamenné ostrovy se generují v pásmu Y=50–600
- ✅ Chunky streamují za pohybu

---

---

# Týden 2 — Island Profiler + Biomy

**Cíl:** Každý ostrov má správný 3D tvar (avatar / disc / cone) a biom s povrchovými bloky.

## Úkoly

### 2.1 — Island profiler

```lua
-- mapgen.lua rozšíření
local function island_profile(base_r, y_rel, style)
    if style == "avatar" then
        if y_rel >= 0 then
            -- Horní kupole
            local cap_h = base_r * 0.6
            return base_r * math.max(0, 1 - (y_rel / cap_h)^2)
        else
            -- Dolní ocas (exponenciální)
            return base_r * math.exp(y_rel / (base_r * 0.5))
        end

    elseif style == "disc" then
        local half_h = base_r * 0.12
        return base_r * math.max(0, 1 - math.abs(y_rel) / half_h)

    elseif style == "cone" then
        return base_r * math.max(0, 1 - math.abs(y_rel) / base_r)
    end
    return 0
end
```

### 2.2 — Placement noise (středy ostrovů)

```lua
-- Ostrovy nejsou kontinuální noise blob, ale diskrétní objekty
-- Použijeme Poisson-disk-like přístup přes noise seed:

local function get_islands_in_chunk(minp, maxp, seed)
    local islands = {}
    -- Grid 256×256 bloků = jedna buňka
    local cell = 256
    local cx0 = math.floor(minp.x / cell)
    local cx1 = math.floor(maxp.x / cell)
    local cz0 = math.floor(minp.z / cell)
    local cz1 = math.floor(maxp.z / cell)

    for cx = cx0, cx1 do
    for cz = cz0, cz1 do
        -- Deterministický RNG z gridu + seed
        local h = cx * 73856093 + cz * 19349663 + seed
        h = (h ~ (h >> 16)) * 0x45d9f3b
        h = (h ~ (h >> 16)) & 0x7fffffff

        local ox = (h % cell) + cx * cell
        local oz = ((h // cell) % cell) + cz * cell
        local oy = ISLAND_LAYER_MIN + (h % (ISLAND_LAYER_MAX - ISLAND_LAYER_MIN))

        -- Biom z druhého hash
        local biome_idx = h % 6  -- 6 biomů

        table.insert(islands, {
            x = ox, y = oy, z = oz,
            radius = 20 + (h % 80),   -- 20–100 bloků
            biome = biome_idx,
        })
    end end
    return islands
end
```

### 2.3 — biomes.lua — definice biomů

```lua
-- biomes.lua
local c = {}  -- content IDs cache

local function init_content_ids()
    c.air          = minetest.get_content_id("air")
    c.stone        = minetest.get_content_id("default:stone")
    c.dirt         = minetest.get_content_id("default:dirt")
    c.grass        = minetest.get_content_id("default:dirt_with_grass")
    c.ice          = minetest.get_content_id("default:ice")
    c.snow         = minetest.get_content_id("default:snow")
    c.obsidian     = minetest.get_content_id("default:obsidian")
    c.lava         = minetest.get_content_id("default:lava_source")
    c.sand         = minetest.get_content_id("default:sand")
    c.mycelium     = minetest.get_content_id("doggiowars:spore_block")
    c.magma        = minetest.get_content_id("doggiowars:magma_block")
    c.dead_stone   = minetest.get_content_id("default:stone")  -- later custom
end

minetest.after(0, init_content_ids)

doggiowars = doggiowars or {}
doggiowars.biomes = {
    [0] = { -- VERDANT
        name    = "verdant",
        shape   = "avatar",
        surface = function(y_rel) return y_rel == 0 and c.grass or c.dirt end,
        core    = function() return c.stone end,
    },
    [1] = { -- GLACIAL
        name    = "glacial",
        shape   = "disc",
        surface = function(y_rel) return y_rel == 0 and c.snow or c.ice end,
        core    = function() return c.ice end,
    },
    [2] = { -- VOLCANIC
        name    = "volcanic",
        shape   = "cone",
        surface = function(y_rel) return y_rel == 0 and c.magma or c.obsidian end,
        core    = function() return c.obsidian end,
    },
    [3] = { -- ATOLL
        name    = "atoll",
        shape   = "disc",
        surface = function(y_rel) return c.sand end,
        core    = function() return c.stone end,
    },
    [4] = { -- MYCELIAL
        name    = "mycelial",
        shape   = "avatar",
        surface = function(y_rel) return c.mycelium end,
        core    = function() return c.dirt end,
    },
    [5] = { -- BARREN
        name    = "barren",
        shape   = "cone",
        surface = function(y_rel) return c.dead_stone end,
        core    = function() return c.stone end,
    },
}
```

### 2.4 — Propojení profilu s mapgenem

```lua
-- V minetest.register_on_generated:
local islands = get_islands_in_chunk(minp, maxp, seed)

for _, isl in ipairs(islands) do
    local biome = doggiowars.biomes[isl.biome]
    local y_top = isl.y + isl.radius * 0.6
    local y_bot = isl.y - isl.radius * 1.2

    for z = minp.z, maxp.z do
    for y = math.max(minp.y, y_bot), math.min(maxp.y, y_top) do
    for x = minp.x, maxp.x do
        local dx = x - isl.x
        local dz = z - isl.z
        local y_rel = y - isl.y
        local dist = math.sqrt(dx*dx + dz*dz)
        local limit = island_profile(isl.radius, y_rel, biome.shape)

        if dist <= limit then
            local vi = area:index(x, y, z)
            -- Povrch = top vrstva, zbytek = core
            local above_vi = area:index(x, y+1, z)
            if data[above_vi] == c.air then
                data[vi] = biome.surface(0)  -- y_rel=0 = povrch
            else
                data[vi] = biome.core()
            end
        end
    end end end
end
```

## Výstup týdne 2
- ✅ Ostrovy mají správný tvar (avatar ocas, disc talíř, cone sopka)
- ✅ Každý ostrov má biom s odpovídajícími bloky
- ✅ Povrch vs. podloží se správně rozlišuje

---

---

# Týden 3 — Letadlo + Základní Let

**Cíl:** Hráč se spawne v letadle, může létat, vstoupit a vystoupit.

## Úkoly

### 3.1 — vehicle.lua — entita letadla

```lua
-- vehicle.lua
local SPEED_MAX    = 40   -- m/s
local SPEED_MIN    = 5    -- stall speed
local LIFT_FACTOR  = 0.8
local DRAG         = 0.05
local TURN_SPEED   = 1.5  -- rad/s

minetest.register_entity("doggiowars:fighter", {
    initial_properties = {
        visual          = "mesh",
        mesh            = "fighter_01.obj",
        textures        = {"doggiowars_fighter_01.png"},
        physical        = true,
        collide_with_objects = false,
        weight          = 50,
        visual_size     = {x = 2, y = 2, z = 2},
        selectionbox    = {-1.5, -0.5, -1.5, 1.5, 0.5, 1.5},
    },

    pilot       = nil,
    speed       = 15,
    pitch       = 0,
    yaw_angle   = 0,

    on_activate = function(self, staticdata)
        self.object:set_armor_groups({immortal = 1})
    end,

    on_step = function(self, dtime)
        if not self.pilot then return end

        local ctrl = self.pilot:get_player_control()
        local rot  = self.object:get_rotation()

        -- Ovládání
        if ctrl.up    then self.speed = math.min(self.speed + 8*dtime, SPEED_MAX) end
        if ctrl.down  then self.speed = math.max(self.speed - 5*dtime, SPEED_MIN) end
        if ctrl.left  then rot.y = rot.y + TURN_SPEED * dtime end
        if ctrl.right then rot.y = rot.y - TURN_SPEED * dtime end
        if ctrl.jump  then self.pitch = math.min(self.pitch + 1.2*dtime, 0.6) end
        if ctrl.sneak then self.pitch = math.max(self.pitch - 1.2*dtime, -0.6) end

        -- Decay pitch
        self.pitch = self.pitch * (1 - 0.8*dtime)
        rot.x = -self.pitch
        self.object:set_rotation(rot)

        -- Pohybový vektor
        local dir = minetest.yaw_to_dir(rot.y)
        dir.y = math.sin(self.pitch) * self.speed

        local vel = {
            x = dir.x * self.speed,
            y = dir.y,
            z = dir.z * self.speed,
        }
        self.object:set_velocity(vel)

        -- Pilot sleduje letadlo
        self.pilot:set_pos(self.object:get_pos())
    end,

    on_rightclick = function(self, clicker)
        if not self.pilot then
            -- Nastoupení
            self.pilot = clicker
            clicker:set_attach(self.object, "", {x=0,y=5,z=0}, {x=0,y=0,z=0})
            clicker:set_properties({visual_size = {x=0,y=0}})  -- skrýt hráče
            minetest.chat_send_player(clicker:get_player_name(),
                "✈  Nastoupil jsi do stíhačky. [sneak] = vystoupit")
        end
    end,

    on_punch = function(self, puncher)
        -- Vystoupení přes punch (nebo sneak v on_step)
        if self.pilot == puncher then
            self:eject_pilot()
        end
    end,

    eject_pilot = function(self)
        if not self.pilot then return end
        self.pilot:set_detach()
        self.pilot:set_properties({visual_size = {x=1,y=1}})
        local pos = self.object:get_pos()
        pos.y = pos.y + 2
        self.pilot:set_pos(pos)
        self.pilot = nil
    end,
})
```

### 3.2 — Spawn příkaz

```lua
-- init.lua přidání:
minetest.register_chatcommand("spawn_fighter", {
    description = "Spawni stíhačku na aktuální pozici",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Hráč nenalezen" end
        local pos = player:get_pos()
        pos.y = pos.y + 2
        minetest.add_entity(pos, "doggiowars:fighter")
        return true, "Stíhačka spawnuta!"
    end,
})
```

### 3.3 — Částice motoru

```lua
-- Výfukové částice při letu
local function spawn_exhaust(pos, dir)
    minetest.add_particlespawner({
        amount   = 5,
        time     = 0.1,
        minpos   = {x=pos.x-0.1, y=pos.y, z=pos.z-0.1},
        maxpos   = {x=pos.x+0.1, y=pos.y, z=pos.z+0.1},
        minvel   = {x=-dir.x*5, y=-0.5, z=-dir.z*5},
        maxvel   = {x=-dir.x*8, y=0.5,  z=-dir.z*8},
        minacc   = {x=0, y=-1, z=0},
        maxacc   = {x=0, y=-2, z=0},
        minexptime = 0.3,
        maxexptime = 0.8,
        minsize  = 0.5,
        maxsize  = 1.5,
        texture  = "doggiowars_particle_engine.png",
        glow     = 8,
    })
end
```

### 3.4 — Mraky (strop + spodek)

```lua
-- Fog vrstvy — řešeny jako husto-hustý particle spawner
-- nebo jednoduše přes Luanti sky API:

minetest.register_on_joinplayer(function(player)
    player:set_sky({
        type = "skybox",
        base_color = "#1a1a2e",
        clouds = false,
    })
    player:set_clouds({
        density = 0.9,
        height  = 750,   -- strop
        speed   = {x=2, y=0},
    })
    -- Spodní "mlha" přes fog:
    player:set_fog({
        fog_distance = 200,
        fog_start    = 0.4,
        fog_color    = "#c8d8e8",
    })
end)
```

## Výstup týdne 3
- ✅ `/spawn_fighter` spawne funkční letadlo
- ✅ Hráč nastoupí pravým klikem, vystoupí sneak/punch
- ✅ Letadlo reaguje na WASD + jump/sneak (pitch)
- ✅ Výfukové částice
- ✅ Sky + fog nastavení

---

---

# Týden 4 — Dekorace, Ladění, "Wow Moment"

**Cíl:** Stromy, detaily biomů, ladění hustoty ostrovů, finální průletový zážitek.

## Úkoly

### 4.1 — Stromy a dekorace

```lua
-- Po mapgenu: dekorace na ostrovech
-- Použijeme minetest.register_decoration nebo ruční placement

local function decorate_island(island, biome_name, seed)
    if biome_name == "verdant" then
        -- Stromy: default:tree + default:leaves
        -- Náhodné rozmístění na povrchu
        for i = 1, math.random(3, 12) do
            local angle = math.random() * math.pi * 2
            local r     = math.random(0, island.radius * 0.7)
            local tx    = island.x + math.cos(angle) * r
            local tz    = island.z + math.sin(angle) * r
            -- Najdi povrch a zasaď strom
            doggiowars.place_tree(tx, island.y, tz)
        end

    elseif biome_name == "glacial" then
        -- Rampouchy dolů z okraje
        doggiowars.place_icicles(island)

    elseif biome_name == "volcanic" then
        -- Lava pool na vrcholu
        doggiowars.place_lava_pool(island)

    elseif biome_name == "atoll" then
        -- Voda uprostřed prstence
        doggiowars.fill_atoll_center(island)

    elseif biome_name == "mycelial" then
        -- Giant mushrooms
        for i = 1, math.random(2, 6) do
            doggiowars.place_giant_mushroom(island)
        end
    end
end
```

### 4.2 — Vodopády (Verdant)

```lua
-- Vodopád přes okraj ostrova dolů do mlhy
local function place_waterfall(island)
    local edge_x = island.x + island.radius - 2
    local edge_z = island.z
    local top_y  = island.y + 5

    for y = top_y, top_y - 30, -1 do
        local pos = {x = edge_x, y = y, z = edge_z}
        -- Jen pokud je vzduch:
        if minetest.get_node(pos).name == "air" then
            minetest.set_node(pos, {name = "default:water_flowing"})
        else
            break
        end
    end
end
```

### 4.3 — Ladění parametrů

```lua
-- Tyto hodnoty ladit iterativně za letu:
local TUNING = {
    island_density      = 0.55,   -- noise threshold (nižší = hustější)
    island_grid_size    = 256,    -- bloků mezi středy ostrovů
    island_radius_min   = 20,
    island_radius_max   = 100,
    layer_bottom        = 50,
    layer_top           = 600,
    fog_distance        = 200,    -- viditelnost
    speed_default       = 15,     -- počáteční rychlost letadla
}
```

**Cílové nastavení pro "wow moment":**
```
- Za 10 sekund letu = vždy alespoň 1–2 ostrovy na obzoru
- Hustota: ne příliš (prázdný prostor = svoboda), ne příliš řídká (nuda)
- Fog vzdálenost: ostrovy se magicky vynořují z mlhy
```

### 4.4 — Finální checklist průletu

```
□ Spusť server: --server --config luanti-dev.conf
□ /grant <jméno> fly fast (pro pohyb bez letadla při testech)
□ /spawn_fighter na výšce ~300
□ Nastoupit, rozletět se
□ Ověřit biomy: jsou vidět různé typy?
□ Ověřit tvar: mají ostrovy ocas dolů?
□ Ověřit streaming: generují se nové chunky za letu?
□ Ověřit fog: mraky vytvářejí iluzi nekonečna?
□ Ověřit dekorace: stromy, lava, led?
□ "Wow moment" test: první průlet — funguje to?
```

## Výstup týdne 4
- ✅ Všechny biomy mají dekorace
- ✅ Vodopády padají do mlhy
- ✅ Ladění hustoty — správný "vzdušný" pocit
- ✅ **Kompletní průletový sandbox — Fáze 1 hotova**

---

---

## Co přijde ve Fázi 2

```
Fáze 2 — Weapons + Damage systém
  → Kanóny, střely, exploze voxelů
  → Damage systém letadel
  → Respawn mechanika

Fáze 3 — Základny + Stavění
  → Placeable bloky z lodi
  → Věže, hangáry, základny na ostrovech
  → Tunelování do ostrovů (hornictví za letu)

Fáze 4 — Multiplayer balancing
  → HUD: radar, health bar, ammo
  → Týmy, score, capture points
  → Server persistence mezi sezeními
```

---

*DoggioWars · Luanti Mod · Fáze 1 Development Plan*
*Generováno: 2026-03-18*
