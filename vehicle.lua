-- aerowars/vehicle.lua
-- Entita letadla — stíhačka

local SPEED_MAX    = 40   -- m/s
local SPEED_MIN    = 5    -- stall speed
local TURN_SPEED   = 1.5  -- rad/s
local PITCH_RATE   = 1.2  -- rad/s
local PITCH_MAX    = 0.6  -- max pitch angle
local PITCH_DECAY  = 0.8  -- pitch return-to-center rate

---------------------------------------------------------------------------
-- Exhaust particle spawner
---------------------------------------------------------------------------

local function spawn_exhaust(pos, dir, speed)
    local intensity = math.min(speed / SPEED_MAX, 1)
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
        static_save       = true,
        stepheight        = 0,
    },

    pilot         = nil,
    speed         = 15,
    pitch         = 0,
    yaw_angle     = 0,
    exhaust_timer = 0,
    hp            = 100,
    shoot_cooldown = 0,
    smoke_timer   = 0,
    is_dead       = false,
    roll          = 0,

    on_activate = function(self, staticdata)
        self.object:set_armor_groups({immortal = 1})
        -- Disable gravity — plane handles its own physics
        self.object:set_acceleration({x = 0, y = 0, z = 0})
        -- Restore persistent state
        if staticdata and staticdata ~= "" then
            local data = minetest.deserialize(staticdata)
            if data then
                self.speed = data.speed or self.speed
                self.pitch = data.pitch or self.pitch
                self.roll  = data.roll  or 0
                self.hp    = data.hp    or 100
            end
        else
            self.hp = 100
        end
    end,

    on_step = function(self, dtime, moveresult)
        if self.is_dead then return end
        if not self.pilot then
            -- No pilot — slow drift down
            local vel = self.object:get_velocity()
            if vel and (math.abs(vel.x) > 0.1 or math.abs(vel.y) > 0.1 or math.abs(vel.z) > 0.1) then
                self.object:set_velocity({
                    x = vel.x * 0.95,
                    y = vel.y * 0.95 - 0.5 * dtime,
                    z = vel.z * 0.95,
                })
            else
                self.object:set_velocity({x = 0, y = 0, z = 0})
            end
            return
        end

        -- Check if pilot is still valid
        if not self.pilot:is_player() then
            self:eject_pilot()
            return
        end

        local ctrl = self.pilot:get_player_control()
        local rot  = self.object:get_rotation()

        -- Throttle
        if ctrl.up then
            self.speed = math.min(self.speed + 8 * dtime, SPEED_MAX)
        end
        if ctrl.down then
            self.speed = math.max(self.speed - 5 * dtime, SPEED_MIN)
        end

        -- Yaw (left/right)
        if ctrl.left then
            rot.y = rot.y + TURN_SPEED * dtime
        end
        if ctrl.right then
            rot.y = rot.y - TURN_SPEED * dtime
        end

        -- Pitch (jump = nose up, sneak = nose down)
        if ctrl.jump then
            self.pitch = math.min(self.pitch + PITCH_RATE * dtime, PITCH_MAX)
        elseif ctrl.sneak then
            self.pitch = math.max(self.pitch - PITCH_RATE * dtime, -PITCH_MAX)
        end

        -- Pitch decay toward neutral
        self.pitch = self.pitch * (1 - PITCH_DECAY * dtime)

        -- Roll (LMB = left, RMB = right, auto-levels when released)
        local ROLL_SPEED = 1.8
        local ROLL_MAX   = math.pi
        local ROLL_DECAY = 1.5
        if ctrl.dig   then
            self.roll = math.max((self.roll or 0) - ROLL_SPEED * dtime, -ROLL_MAX)
        elseif ctrl.place then
            self.roll = math.min((self.roll or 0) + ROLL_SPEED * dtime,  ROLL_MAX)
        else
            self.roll = (self.roll or 0) * (1 - ROLL_DECAY * dtime)
        end

        rot.x = -self.pitch
        rot.z = self.roll
        self.object:set_rotation(rot)

        -- Velocity from direction + speed
        local dir = minetest.yaw_to_dir(rot.y + math.pi)
        local vel = {
            x = dir.x * self.speed,
            y = math.sin(self.pitch) * self.speed,
            z = dir.z * self.speed,
        }
        self.object:set_velocity(vel)

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
        if self.exhaust_timer >= 0.1 then
            self.exhaust_timer = 0
            local pos = self.object:get_pos()
            spawn_exhaust(pos, dir, self.speed)
        end

        -- Eject on sneak hold (long press > 0.5s)
        if ctrl.sneak and ctrl.down then
            self:eject_pilot()
        end
    end,

    on_rightclick = function(self, clicker)
        if not clicker or not clicker:is_player() then return end

        if not self.pilot then
            -- Board the plane
            self.pilot = clicker
            clicker:set_attach(self.object, "", {x = 0, y = 5, z = 0}, {x = 0, y = 0, z = 0})
            clicker:set_properties({visual_size = {x = 0, y = 0}})
            minetest.chat_send_player(clicker:get_player_name(),
                "You boarded the fighter. [sneak+down] = eject")
        elseif self.pilot == clicker then
            -- Already piloting — eject
            self:eject_pilot()
        end
    end,

    on_punch = function(self, puncher)
        if self.pilot and self.pilot == puncher then
            self:eject_pilot()
        end
    end,

    eject_pilot = function(self)
        if not self.pilot then return end
        local pilot = self.pilot
        self.pilot = nil
        pilot:set_detach()
        pilot:set_properties({visual_size = {x = 1, y = 1}})
        local pos = self.object:get_pos()
        if pos then
            pos.y = pos.y + 2
            pilot:set_pos(pos)
        end
        self.object:set_velocity({x = 0, y = 0, z = 0})
        minetest.chat_send_player(pilot:get_player_name(), "You ejected from the fighter.")
    end,

    damage_fighter = function(self, amount)
        if self.is_dead then return end
        self.hp = math.max(0, (self.hp or 100) - amount)
        if self.pilot and self.pilot:is_player() then
            minetest.chat_send_player(self.pilot:get_player_name(),
                "Hull: " .. self.hp .. "%")
        end
        if self.hp <= 0 then
            self:die()
        end
    end,

    die = function(self)
        if self.is_dead then return end
        self.is_dead = true
        local pos = self.object:get_pos()
        -- Capture pilot name before ejecting (string survives entity removal)
        local pilot_name = self.pilot and self.pilot:is_player()
            and self.pilot:get_player_name() or nil
        if self.pilot then
            self:eject_pilot()
        end
        -- Big explosion at crash site
        if pos then
            aerowars.explode_voxels(pos, 5)
        end
        -- Schedule respawn
        if pilot_name then
            minetest.chat_send_player(pilot_name,
                "Fighter destroyed! New fighter in 5 seconds...")
            minetest.after(5, function()
                local player = minetest.get_player_by_name(pilot_name)
                if not player then return end
                local ppos = player:get_pos()
                local spawn_pos = ppos
                    and {x = ppos.x, y = ppos.y + 5, z = ppos.z}
                    or  {x = 0, y = 305, z = 0}
                local obj = minetest.add_entity(spawn_pos, "aerowars:fighter")
                if obj then
                    minetest.chat_send_player(pilot_name,
                        "New fighter ready — right-click to board.")
                end
            end)
        end
        self.object:remove()
    end,

    get_staticdata = function(self)
        return minetest.serialize({
            speed = self.speed,
            pitch = self.pitch,
            roll  = self.roll,
            hp    = self.hp,
        })
    end,

    on_deactivate = function(self)
        if self.pilot then
            self:eject_pilot()
        end
    end,
})

---------------------------------------------------------------------------
-- Chat command to spawn a fighter
---------------------------------------------------------------------------

minetest.register_chatcommand("spawn_fighter", {
    description = "Spawn a fighter plane at your position",
    privs = {interact = true},
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end
        local pos = player:get_pos()
        pos.y = pos.y + 2
        local obj = minetest.add_entity(pos, "aerowars:fighter")
        if obj then
            return true, "Fighter spawned!"
        else
            return false, "Failed to spawn fighter"
        end
    end,
})

---------------------------------------------------------------------------
-- Give fighter item on join (convenience for testing)
---------------------------------------------------------------------------

minetest.register_craftitem("aerowars:fighter_spawner", {
    description = "Fighter Spawner",
    inventory_image = "aerowars_fighter_01.png",
    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type == "node" then
            local pos = pointed_thing.above
            pos.y = pos.y + 2
            minetest.add_entity(pos, "aerowars:fighter")
        end
        return itemstack
    end,
})
