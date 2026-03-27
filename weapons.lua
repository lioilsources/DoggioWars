-- aerowars/weapons.lua
-- Projectiles, voxel explosions, and damage system

aerowars = aerowars or {}

local BULLET_SPEED        = 120   -- m/s (3× max plane speed)
local BULLET_TTL          = 2.5   -- seconds until auto-remove
local BULLET_DAMAGE       = 25    -- damage per hit (4 shots to kill)
local EXPLODE_RADIUS      = 3     -- blocks destroyed on node hit
local EXPLODE_RADIUS_HIT  = 1     -- blocks destroyed on entity hit
local ENTITY_HIT_RADIUS   = 1.5   -- proximity check radius for entity hits

---------------------------------------------------------------------------
-- Voxel explosion — destroys blocks in sphere, spawns fire particles
---------------------------------------------------------------------------

function aerowars.explode_voxels(pos, radius)
    local ir = math.ceil(radius)
    local r2 = radius * radius

    for dx = -ir, ir do
        for dy = -ir, ir do
            for dz = -ir, ir do
                if dx*dx + dy*dy + dz*dz <= r2 then
                    local npos = {x = pos.x + dx, y = pos.y + dy, z = pos.z + dz}
                    local node = minetest.get_node(npos)
                    if node.name ~= "air" and node.name ~= "ignore" then
                        minetest.remove_node(npos)
                    end
                end
            end
        end
    end

    -- Fire + debris particles
    minetest.add_particlespawner({
        amount     = 60,
        time       = 0.5,
        minpos     = {x = pos.x - 0.5, y = pos.y - 0.5, z = pos.z - 0.5},
        maxpos     = {x = pos.x + 0.5, y = pos.y + 0.5, z = pos.z + 0.5},
        minvel     = {x = -15, y = -10, z = -15},
        maxvel     = {x =  15, y =  22, z =  15},
        minacc     = {x = 0,  y = -8,  z = 0},
        maxacc     = {x = 0,  y = -14, z = 0},
        minexptime = 0.3,
        maxexptime = 1.5,
        minsize    = 1.5,
        maxsize    = 5.0,
        texture    = "aerowars_particle_engine.png",
        glow       = 14,
    })
end

---------------------------------------------------------------------------
-- Bullet entity
---------------------------------------------------------------------------

minetest.register_entity("aerowars:bullet", {
    initial_properties = {
        visual            = "sprite",
        textures          = {"aerowars_particle_engine.png"},
        visual_size       = {x = 0.3, y = 0.3},
        physical          = true,
        collide_with_objects = false,
        collisionbox      = {-0.15, -0.15, -0.15, 0.15, 0.15, 0.15},
        glow              = 14,
        static_save       = false,
        pointable         = false,
    },

    _ttl          = BULLET_TTL,
    _shooter_name = nil,   -- pilot's player name (string, avoids stale refs)

    on_activate = function(self, staticdata)
        self.object:set_armor_groups({immortal = 1})
    end,

    on_step = function(self, dtime, moveresult)
        self._ttl = (self._ttl or BULLET_TTL) - dtime
        if self._ttl <= 0 then
            self.object:remove()
            return
        end

        local pos = self.object:get_pos()
        if not pos then return end

        -- Node collision via moveresult (physical = true gives this for free)
        if moveresult and moveresult.collides then
            for _, col in ipairs(moveresult.collisions or {}) do
                if col.type == "node" then
                    aerowars.explode_voxels(pos, EXPLODE_RADIUS)
                    self.object:remove()
                    return
                end
            end
        end

        -- Entity collision via proximity (fighter has collide_with_objects=false)
        local objects = minetest.get_objects_inside_radius(pos, ENTITY_HIT_RADIUS)
        for _, obj in ipairs(objects) do
            if obj ~= self.object then
                local ent = obj:get_luaentity()
                if ent and ent.name == "aerowars:fighter"
                        and ent.hp and ent.hp > 0 and not ent.is_dead then
                    -- Don't hit the shooter's own plane
                    local pilot = ent.pilot
                    local is_own = pilot and pilot:is_player()
                        and pilot:get_player_name() == self._shooter_name
                    if not is_own then
                        ent:damage_fighter(BULLET_DAMAGE)
                        aerowars.explode_voxels(pos, EXPLODE_RADIUS_HIT)
                        self.object:remove()
                        return
                    end
                end
            end
        end

        -- Tracer trail
        minetest.add_particle({
            pos            = pos,
            velocity       = {x = 0, y = 0, z = 0},
            acceleration   = {x = 0, y = 0, z = 0},
            expirationtime = 0.1,
            size           = 0.8,
            texture        = "aerowars_particle_engine.png",
            glow           = 12,
        })
    end,
})

---------------------------------------------------------------------------
-- Shoot function — called from vehicle.lua on_step
---------------------------------------------------------------------------

function aerowars.shoot_bullet(fighter_self)
    local pos = fighter_self.object:get_pos()
    if not pos then return end

    local rot = fighter_self.object:get_rotation()
    local dir = minetest.yaw_to_dir(rot.y + math.pi)
    local pitch_angle = -(rot.x or 0)   -- rot.x is -pitch
    dir.y = math.sin(pitch_angle)
    -- Re-normalize horizontal component
    local hlen = math.sqrt(dir.x * dir.x + dir.z * dir.z)
    local cos_p = math.cos(pitch_angle)
    if hlen > 0 then
        dir.x = dir.x / hlen * cos_p
        dir.z = dir.z / hlen * cos_p
    end

    -- Muzzle: 3 blocks in front of nose
    local muzzle = {
        x = pos.x + dir.x * 3,
        y = pos.y + dir.y * 3,
        z = pos.z + dir.z * 3,
    }

    local bullet = minetest.add_entity(muzzle, "aerowars:bullet")
    if not bullet then return end

    -- Add plane velocity so bullet doesn't arc backward when diving
    local plane_vel = fighter_self.object:get_velocity() or {x = 0, y = 0, z = 0}
    bullet:set_velocity({
        x = dir.x * BULLET_SPEED + plane_vel.x,
        y = dir.y * BULLET_SPEED + plane_vel.y,
        z = dir.z * BULLET_SPEED + plane_vel.z,
    })

    local ent = bullet:get_luaentity()
    if ent then
        ent._shooter_name = fighter_self.pilot
            and fighter_self.pilot:is_player()
            and fighter_self.pilot:get_player_name()
            or nil
    end

    -- Muzzle flash
    minetest.add_particle({
        pos            = muzzle,
        velocity       = {x = 0, y = 0, z = 0},
        acceleration   = {x = 0, y = 0, z = 0},
        expirationtime = 0.08,
        size           = 3.5,
        texture        = "aerowars_particle_engine.png",
        glow           = 15,
    })
end
