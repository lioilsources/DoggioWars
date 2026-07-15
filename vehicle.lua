-- aerowars/vehicle.lua
-- Entita stíhačky. Hráč JE loď — mount při joinu, žádné nasedání/vysedání.

local C = aerowars.const

-- Kamera "na nose": mesh (visual_size 2, collisionbox ±1.5) končí ~3 jednotky
-- od středu entity, offset 4 dopředu drží celý mesh za near plane kamery
local EYE_OFFSET = {x = 0, y = 0.5, z = 4}

-- Hráči čekající na naplánovaný respawn — watchdog je nesmí remountovat dřív
local respawn_pending = {}

---------------------------------------------------------------------------
-- Exhaust particle spawner
---------------------------------------------------------------------------

local function spawn_exhaust(pos, dir, speed)
    local intensity = math.min(speed / C.SPEED_MAX, 1)
    minetest.add_particlespawner({
        amount   = math.floor(3 + 7 * intensity),
        time     = 0.1,
        minpos   = {x = pos.x - 0.1, y = pos.y - 0.3, z = pos.z - 0.1},
        maxpos   = {x = pos.x + 0.1, y = pos.y + 0.3, z = pos.z + 0.1},
        minvel   = {x = -dir.x * 5, y = -0.5, z = -dir.z * 5},
        maxvel   = {x = -dir.x * 8, y =  0.5, z = -dir.z * 8},
        minacc   = {x = 0, y = -1, z = 0},
        maxacc   = {x = 0, y = -2, z = 0},
        minexptime = 0.3,
        maxexptime = 0.8,
        minsize  = 0.5,
        maxsize  = 1.5,
        texture  = "aerowars_particle_engine.png",
        glow     = math.floor(8 * intensity),
    })
end

---------------------------------------------------------------------------
-- Mount / dismount — hráč je vždy pilotem své stíhačky
---------------------------------------------------------------------------

function aerowars.get_player_fighter(player)
    local parent = player and player:get_attach()
    local ent = parent and parent:get_luaentity()
    if ent and ent.name == "aerowars:fighter" and not ent.is_dead then
        return ent
    end
    return nil
end

function aerowars.mount_player(player, pos)
    if not player or not player:is_player() then return end
    local name = player:get_player_name()
    if not pos then
        local ppos = player:get_pos()
        pos = {x = ppos.x, y = ppos.y + 2, z = ppos.z}
    end
    local obj = minetest.add_entity(pos, "aerowars:fighter")
    if not obj then return end
    local self = obj:get_luaentity()
    self.pilot = player
    self.pilot_name = name
    self.score = aerowars.tricks.scores[name] or 0

    player:set_attach(obj, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
    player:set_eye_offset(EYE_OFFSET, EYE_OFFSET)
    player:set_properties({visual_size = {x = 0, y = 0}})
    if player.set_camera then
        player:set_camera({mode = "first"})
    end
    player:set_physics_override({speed = 0, jump = 0, gravity = 0})
    player:set_fov(0)
    player:hud_set_flags({
        hotbar = false, wielditem = false, healthbar = false,
        breathbar = false, crosshair = true,
    })
    aerowars.hud.init(player)
    respawn_pending[name] = nil
    return obj
end

-- Interní úklid (odchod ze hry) — není to herní akce, vysedání neexistuje
function aerowars.dismount_player(player)
    if not player or not player:is_player() then return end
    player:set_detach()
    player:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
    player:set_properties({visual_size = {x = 1, y = 1}})
    if player.set_camera then
        player:set_camera({mode = "any"})
    end
    player:set_physics_override({speed = 1, jump = 1, gravity = 1})
    player:hud_set_flags({
        hotbar = true, wielditem = true, healthbar = true,
        breathbar = true, crosshair = true,
    })
end

---------------------------------------------------------------------------
-- Fighter entity definition
---------------------------------------------------------------------------

minetest.register_entity("aerowars:fighter", {
    initial_properties = {
        visual            = "mesh",
        mesh              = "aerowars_fighter_01.obj",
        textures          = {"aerowars_fighter_01.png"},
        physical          = true,
        collide_with_objects = false,
        collisionbox      = {-1.5, -0.5, -1.5, 1.5, 0.5, 1.5},
        selectionbox      = {-1.5, -0.5, -1.5, 1.5, 0.5, 1.5},
        visual_size       = {x = 2, y = 2, z = 2},
        static_save       = false,
        stepheight        = 0,
    },

    pilot          = nil,
    pilot_name     = nil,
    speed          = 15,
    pitch          = 0,
    roll           = 0,
    exhaust_timer  = 0,
    hp             = 100,
    shoot_cooldown = 0,
    smoke_timer    = 0,
    is_dead        = false,

    on_activate = function(self)
        self.object:set_armor_groups({immortal = 1})
        -- Disable gravity — plane handles its own physics
        self.object:set_acceleration({x = 0, y = 0, z = 0})
        self.hp = 100
        aerowars.tricks.init(self)
    end,

    on_step = function(self, dtime, moveresult)
        if self.is_dead then return end

        -- Fighter existuje jen s živým pilotem na palubě
        local pilot = self.pilot
        if not pilot or not pilot:is_player()
                or pilot:get_attach() ~= self.object then
            self.object:remove()
            return
        end

        local ctrl = pilot:get_player_control()
        local events = aerowars.tricks.update_input(self, ctrl)
        self.iframes = math.max(0, (self.iframes or 0) - dtime)

        -- Kolizní poškození: náraz do terénu v rychlosti bolí (pomalé
        -- škrtnutí pod ~15 m/s je zdarma — učí opatrné létání)
        self.crash_cooldown = math.max(0, (self.crash_cooldown or 0) - dtime)
        if moveresult and moveresult.collides and self.crash_cooldown <= 0
                and (self.speed or 0) > 15 then
            self.crash_cooldown = 0.5
            local dmg = math.floor((self.speed - 10) * 2.5)
            self.speed = C.SPEED_MIN
            self:damage_fighter(dmg, true)
            if self.is_dead then return end
        end

        local rot, vel

        if self.trick then
            -- Skriptovaný trik přebírá řízení (looping potřebuje pitch
            -- za clampem ±PITCH_MAX)
            rot, vel = aerowars.tricks.step_active(self, dtime)
            self.object:set_rotation(rot)
            self.object:set_velocity(vel)
        else
            rot = self.object:get_rotation()

            -- Throttle (jen do SPEED_MAX — overspeed řeší dive/boost níže)
            if ctrl.up and self.speed < C.SPEED_MAX then
                self.speed = math.min(self.speed + 8 * dtime, C.SPEED_MAX)
            end
            if ctrl.down then
                self.speed = math.max(self.speed - 5 * dtime, C.SPEED_MIN)
            end

            -- Airbrake drift: S + A/D = ostrá zatáčka za cenu rychlosti
            local turn = C.TURN_SPEED
            local drifting = ctrl.down and (ctrl.left or ctrl.right)
            if drifting then
                turn = C.TURN_SPEED * 2.2
                self.speed = math.max(self.speed - 12 * dtime, C.SPEED_MIN)
                aerowars.tricks.add_raw_score(self, 50 * dtime)
            end

            -- Yaw (left/right)
            if ctrl.left then
                rot.y = rot.y + turn * dtime
            end
            if ctrl.right then
                rot.y = rot.y - turn * dtime
            end

            -- Pitch (jump = nose up, sneak = nose down)
            if ctrl.jump then
                self.pitch = math.min(self.pitch + C.PITCH_RATE * dtime, C.PITCH_MAX)
            elseif ctrl.sneak then
                self.pitch = math.max(self.pitch - C.PITCH_RATE * dtime, -C.PITCH_MAX)
            end

            -- Pitch decay toward neutral
            self.pitch = self.pitch * (1 - C.PITCH_DECAY * dtime)

            -- Roll (LMB = left, RMB = right, auto-levels when released)
            if ctrl.dig then
                self.roll = math.max((self.roll or 0) - C.ROLL_SPEED * dtime, -C.ROLL_MAX)
            elseif ctrl.place then
                self.roll = math.min((self.roll or 0) + C.ROLL_SPEED * dtime,  C.ROLL_MAX)
            else
                self.roll = (self.roll or 0) * (1 - C.ROLL_DECAY * dtime)
            end

            -- Boost (double-tap W) a dive overspeed (střemhlavý let zrychluje)
            if (self.boost_time or 0) > 0 then
                self.boost_time = self.boost_time - dtime
                self.speed = 60
                if self.boost_time <= 0 then
                    pilot:set_fov(0)
                end
            elseif self.pitch < -0.4 then
                self.speed = math.min(self.speed + 15 * dtime, C.SPEED_MAX * 1.5)
            elseif self.speed > C.SPEED_MAX then
                self.speed = math.max(C.SPEED_MAX, self.speed - 7 * dtime)
            end

            rot.x = -self.pitch
            rot.z = self.roll
            self.object:set_rotation(rot)

            -- Velocity from direction + speed
            local dir = minetest.yaw_to_dir(rot.y + math.pi)
            vel = {
                x = dir.x * self.speed,
                y = math.sin(self.pitch) * self.speed,
                z = dir.z * self.speed,
            }
            self.object:set_velocity(vel)

            aerowars.tricks.check_triggers(self, events, pilot)
        end

        -- Kamera: pohled pilota sleduje vektor letu — funguje i vzhůru
        -- nohama v loopingu (v apexu se pohled překlopí přes yaw)
        local hlen = math.sqrt(vel.x * vel.x + vel.z * vel.z)
        if hlen > 0.05 then
            pilot:set_look_horizontal(
                minetest.dir_to_yaw({x = vel.x, y = 0, z = vel.z}))
            pilot:set_look_vertical(-math.atan2(vel.y, hlen))
        end

        -- Proximity charge: let těsně kolem terénu nabíjí boost
        aerowars.tricks.update_passive(self, dtime)

        -- Shooting (E / aux1 key) with 0.15s cooldown (~6 rounds/s)
        self.shoot_cooldown = math.max(0, (self.shoot_cooldown or 0) - dtime)
        if ctrl.aux1 and self.shoot_cooldown <= 0 then
            self.shoot_cooldown = 0.15
            aerowars.shoot_bullet(self)
        end

        -- Damage smoke: light at HP < 70, heavy fire at HP < 30
        if (self.hp or 100) < 70 then
            self.smoke_timer = (self.smoke_timer or 0) + dtime
            local interval = (self.hp or 100) < 30 and 0.1 or 0.25
            if self.smoke_timer >= interval then
                self.smoke_timer = 0
                local spos = self.object:get_pos()
                minetest.add_particlespawner({
                    amount     = (self.hp or 100) < 30 and 8 or 3,
                    time       = interval,
                    minpos     = {x = spos.x - 0.3, y = spos.y - 0.2, z = spos.z - 0.3},
                    maxpos     = {x = spos.x + 0.3, y = spos.y + 0.5, z = spos.z + 0.3},
                    minvel     = {x = -1, y = 1, z = -1},
                    maxvel     = {x =  1, y = 4, z =  1},
                    minacc     = {x = 0,  y = 0.5, z = 0},
                    maxacc     = {x = 0,  y = 1,   z = 0},
                    minexptime = 0.5,
                    maxexptime = 2.0,
                    minsize    = 2,
                    maxsize    = 6,
                    texture    = "aerowars_particle_engine.png",
                    glow       = (self.hp or 100) < 30 and 5 or 0,
                })
            end
        end

        -- Exhaust particles (throttled to every 0.1s)
        self.exhaust_timer = (self.exhaust_timer or 0) + dtime
        if self.exhaust_timer >= 0.1 and hlen > 0.05 then
            self.exhaust_timer = 0
            local pos = self.object:get_pos()
            spawn_exhaust(pos, {x = vel.x / hlen, z = vel.z / hlen}, self.speed)
        end

        -- HUD update (throttled to every 0.15s)
        self.hud_timer = (self.hud_timer or 0) + dtime
        if self.hud_timer >= 0.15 then
            self.hud_timer = 0
            aerowars.hud.update_flight(pilot, self)
        end
    end,

    damage_fighter = function(self, amount, bypass_iframes)
        if self.is_dead then return end
        -- Barrel roll dává krátkou nesmrtelnost vůči střelám (náraz
        -- do terénu ale bolí vždy)
        if not bypass_iframes and (self.iframes or 0) > 0 then return end
        self.hp = math.max(0, (self.hp or 100) - amount)
        if self.hp <= 0 then
            self:die()
        end
    end,

    die = function(self)
        if self.is_dead then return end
        self.is_dead = true
        local pos = self.object:get_pos()
        local pilot_name = self.pilot_name
        local player = pilot_name and minetest.get_player_by_name(pilot_name)

        -- Session skóre přežívá zničení stíhačky
        if pilot_name then
            aerowars.tricks.scores[pilot_name] = self.score or 0
        end

        -- Odpojit pilota — zůstává neviditelný na místě havárie (death cam),
        -- gravity 0 z physics_override ho drží na místě
        if player and player:get_attach() == self.object then
            player:set_detach()
        end

        -- Big explosion at crash site
        if pos then
            aerowars.explode_voxels(pos, 5)
        end

        if pilot_name then
            -- Hook pro race.lua — smrt během závodu = RACE FAILED
            if aerowars.race_on_pilot_died then
                aerowars.race_on_pilot_died(pilot_name)
            end
            respawn_pending[pilot_name] = true
            minetest.chat_send_player(pilot_name,
                "Fighter destroyed! Respawning...")
            minetest.after(3, function()
                respawn_pending[pilot_name] = nil
                local p = minetest.get_player_by_name(pilot_name)
                if not p then return end
                local ppos = p:get_pos()
                aerowars.mount_player(p, {
                    x = ppos.x,
                    y = C.SPAWN_HEIGHT,
                    z = ppos.z,
                })
            end)
        end

        self.object:remove()
    end,

    on_deactivate = function(self)
        -- Unload entity → odpojit pilota, watchdog ho remountuje
        local player = self.pilot_name
            and minetest.get_player_by_name(self.pilot_name)
        if player and player:get_attach() == self.object then
            player:set_detach()
        end
    end,
})

---------------------------------------------------------------------------
-- Watchdog — každý připojený hráč musí sedět v živé stíhačce
---------------------------------------------------------------------------

local watchdog_timer = 0
minetest.register_globalstep(function(dtime)
    watchdog_timer = watchdog_timer + dtime
    if watchdog_timer < 2 then return end
    watchdog_timer = 0
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        if not respawn_pending[name]
                and not aerowars.get_player_fighter(player) then
            local pos = player:get_pos()
            aerowars.mount_player(player, {
                x = pos.x,
                y = math.max(pos.y + 2, 100),
                z = pos.z,
            })
        end
    end
end)

minetest.register_on_respawnplayer(function(player)
    local name = player:get_player_name()
    respawn_pending[name] = nil
    minetest.after(0.1, function()
        local p = minetest.get_player_by_name(name)
        if p and not aerowars.get_player_fighter(p) then
            aerowars.mount_player(p, {x = 0, y = C.SPAWN_HEIGHT, z = 0})
        end
    end)
    return true
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    local fighter = aerowars.get_player_fighter(player)
    aerowars.dismount_player(player)
    if fighter then
        aerowars.tricks.scores[name] = fighter.score or 0
        fighter.object:remove()
    end
    respawn_pending[name] = nil
    if aerowars.race_on_player_left then
        aerowars.race_on_player_left(name)
    end
end)

---------------------------------------------------------------------------
-- Debug: zahodit a znovu nasadit stíhačku
---------------------------------------------------------------------------

minetest.register_chatcommand("respawn_fighter", {
    description = "Debug: respawn your fighter at your position",
    privs = {interact = true},
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end
        local fighter = aerowars.get_player_fighter(player)
        if fighter then
            player:set_detach()
            fighter.object:remove()
        end
        local pos = player:get_pos()
        aerowars.mount_player(player, {x = pos.x, y = pos.y + 2, z = pos.z})
        return true, "Fighter respawned!"
    end,
})
