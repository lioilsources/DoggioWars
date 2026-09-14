-- doggiowars/weapons.lua
-- Projectiles, voxel explosions, and damage system

doggiowars = doggiowars or {}

local BULLET_SPEED        = 120   -- m/s (3× max plane speed)
local BULLET_TTL          = 2.5   -- seconds until auto-remove
local BULLET_DAMAGE       = 25    -- damage per hit (4 shots to kill)
-- Zásah terénu vrtá tunel ve směru letu kulky: kapsle o poloměru
-- TUNNEL_RADIUS (Ø 8 jako závodní tunely v race.lua — stíhačka 3×1×3 proletí)
-- a délce TUNNEL_LENGTH + zaoblený konec. Další rána dopadne na dno a vrtá
-- dál, takže 3 rány ≈ 45 bloků hloubky.
local TUNNEL_RADIUS       = 4
local TUNNEL_LENGTH       = 12
local TUNNEL_BACKSET      = 2     -- začátek kapsle kus před povrchem (plné ústí)
local EXPLODE_RADIUS_HIT  = 1     -- blocks destroyed on entity hit
local ENTITY_HIT_RADIUS   = 1.5   -- proximity check radius for entity hits
local DEBRIS_MAX_ACTIVE   = 140   -- perf guard: cap of live debris chunks

---------------------------------------------------------------------------
-- Falling debris — odlomený kus ostrova s gravitací
---------------------------------------------------------------------------

local debris_active = 0

-- Textura první strany nodu (aby sutina vypadala jako zasažený materiál)
local function node_tile(name)
    local def = minetest.registered_nodes[name]
    local t = def and def.tiles and def.tiles[1]
    if type(t) == "table" then t = t.name end
    if type(t) ~= "string" then return "default_stone.png" end
    return t
end

minetest.register_entity(":doggiowars:debris", {
    initial_properties = {
        visual            = "cube",
        visual_size       = {x = 0.8, y = 0.8, z = 0.8},
        textures          = {"default_stone.png", "default_stone.png",
                             "default_stone.png", "default_stone.png",
                             "default_stone.png", "default_stone.png"},
        physical          = true,
        collide_with_objects = false,
        collisionbox      = {-0.35, -0.35, -0.35, 0.35, 0.35, 0.35},
        static_save       = false,
        pointable         = false,
    },

    _ttl  = 0,
    _spin = nil,

    on_activate = function(self, staticdata)
        debris_active = debris_active + 1
        self._ttl = 2.5 + math.random() * 1.5
        self.object:set_acceleration({x = 0, y = -10, z = 0})
        self._spin = {
            x = (math.random() - 0.5) * 9,
            y = (math.random() - 0.5) * 9,
            z = (math.random() - 0.5) * 9,
        }
        if staticdata and staticdata ~= "" then
            self.object:set_properties({
                textures = {staticdata, staticdata, staticdata,
                            staticdata, staticdata, staticdata},
            })
        end
    end,

    on_step = function(self, dtime, moveresult)
        self._ttl = self._ttl - dtime
        local landed = moveresult and moveresult.collides
        if self._ttl <= 0 or landed then
            local pos = self.object:get_pos()
            if pos then
                minetest.add_particle({
                    pos            = pos,
                    velocity       = {x = 0, y = 0, z = 0},
                    acceleration   = {x = 0, y = -6, z = 0},
                    expirationtime = 0.4,
                    size           = 2.5,
                    texture        = "doggiowars_particle_engine.png",
                    glow           = 3,
                })
            end
            debris_active = math.max(0, debris_active - 1)
            self.object:remove()
            return
        end
        local rot = self.object:get_rotation()
        self.object:set_rotation({
            x = rot.x + self._spin.x * dtime,
            y = rot.y + self._spin.y * dtime,
            z = rot.z + self._spin.z * dtime,
        })
    end,
})

---------------------------------------------------------------------------
-- Voxel explosion — vyhloubí kráter/tunel, odlomí sutinu, částice ohně
---------------------------------------------------------------------------

-- Content ID cache: kapaliny rána nechává být, sypké (písek, popel) se po
-- podkopání sesypou, přichycené (kytky, tráva) nad dírou shoří s ní
local cid_liquid, cid_falling, cid_attached

local function build_cid_cache()
    cid_liquid, cid_falling, cid_attached = {}, {}, {}
    for name, def in pairs(minetest.registered_nodes) do
        local cid = minetest.get_content_id(name)
        local g = def.groups or {}
        if def.liquidtype and def.liquidtype ~= "none" then
            cid_liquid[cid] = true
        end
        if (g.falling_node or 0) > 0 then cid_falling[cid] = true end
        if (g.attached_node or 0) > 0 then cid_attached[cid] = true end
    end
end

-- Vyhloubí kapsli = úsečku a→b nafouknutou o radius (a == b → koule).
-- Jeden VoxelManip na ránu; kapaliny a nenačtené oblasti přeskočí.
-- Vrací pozice a jména vykopaných nodů (pro sutinu).
local function carve_capsule(a, b, radius)
    if not cid_liquid then build_cid_cache() end

    local minp = {
        x = math.floor(math.min(a.x, b.x) - radius),
        y = math.floor(math.min(a.y, b.y) - radius),
        z = math.floor(math.min(a.z, b.z) - radius),
    }
    local maxp = {
        x = math.ceil(math.max(a.x, b.x) + radius),
        y = math.ceil(math.max(a.y, b.y) + radius),
        z = math.ceil(math.max(a.z, b.z) + radius),
    }

    -- +1 okraj, ať sousedé krajních nodů leží uvnitř načtené oblasti
    local vm = minetest.get_voxel_manip()
    local emin, emax = vm:read_from_map(vector.subtract(minp, 1), vector.add(maxp, 1))
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()
    local ys, zs = area.ystride, area.zstride

    local c_air, c_ignore = minetest.CONTENT_AIR, minetest.CONTENT_IGNORE
    local abx, aby, abz = b.x - a.x, b.y - a.y, b.z - a.z
    local ab2 = abx * abx + aby * aby + abz * abz
    local r2 = radius * radius

    local carved, carved_cid = {}, {}
    local near_liquid = {}   -- sousedí s kapalinou → remove_node, ať začne téct

    for z = minp.z, maxp.z do
        for y = minp.y, maxp.y do
            local vi = area:index(minp.x, y, z)
            for x = minp.x, maxp.x do
                local px, py, pz = x - a.x, y - a.y, z - a.z
                local t = 0
                if ab2 > 0 then
                    t = (px * abx + py * aby + pz * abz) / ab2
                    if t < 0 then t = 0 elseif t > 1 then t = 1 end
                end
                local ex, ey, ez = px - t * abx, py - t * aby, pz - t * abz
                if ex * ex + ey * ey + ez * ez <= r2 then
                    local cid = data[vi]
                    if cid ~= c_air and cid ~= c_ignore and not cid_liquid[cid] then
                        if cid_liquid[data[vi - 1]] or cid_liquid[data[vi + 1]]
                                or cid_liquid[data[vi - ys]] or cid_liquid[data[vi + ys]]
                                or cid_liquid[data[vi - zs]] or cid_liquid[data[vi + zs]] then
                            near_liquid[#near_liquid + 1] = area:position(vi)
                        else
                            data[vi] = c_air
                        end
                        carved[#carved + 1] = vi
                        carved_cid[#carved_cid + 1] = cid
                    end
                end
                vi = vi + 1
            end
        end
    end

    local removed = {}
    if #carved == 0 then return removed end

    -- Co leželo na vykopaných nodech: kytky shoří, písek se sesype
    local to_fall = {}
    for _, vi in ipairs(carved) do
        local above = vi + ys
        if above <= #data then
            local cid = data[above]
            if cid_attached[cid] then
                data[above] = c_air
            elseif cid_falling[cid] then
                to_fall[#to_fall + 1] = area:position(above)
            end
        end
    end

    vm:set_data(data)
    vm:write_to_map(true)

    -- Přes set_node API, ne VoxelManip: jen tak se sousední voda/láva
    -- dostane do fronty proudění a vteče do díry
    for _, p in ipairs(near_liquid) do
        minetest.remove_node(p)
    end
    for i = 1, math.min(#to_fall, 64) do
        minetest.check_for_falling(to_fall[i])
    end

    for i, vi in ipairs(carved) do
        removed[i] = {p = area:position(vi), n = minetest.get_name_from_content_id(carved_cid[i])}
    end
    return removed
end

-- Odlomit část zasažených bloků jako padající sutinu. S eject_dir se kusy
-- vymrští z ústí díry proti směru střely (uvnitř tunelu by hned narazily).
local function spawn_debris(removed, origin, count, eject_dir)
    if #removed == 0 then return end
    for _ = 1, math.min(#removed, count) do
        if debris_active >= DEBRIS_MAX_ACTIVE then break end
        local pick = removed[math.random(1, #removed)]
        local spawn, vel
        local sp = 3 + math.random() * 5
        if eject_dir then
            spawn = vector.subtract(origin, eject_dir)
            vel = {
                x = -eject_dir.x * sp + (math.random() - 0.5) * 6,
                y = -eject_dir.y * sp + 2 + math.random() * 4,
                z = -eject_dir.z * sp + (math.random() - 0.5) * 6,
            }
        else
            spawn = pick.p
            local dx = pick.p.x - origin.x
            local dy = pick.p.y - origin.y
            local dz = pick.p.z - origin.z
            local len = math.sqrt(dx*dx + dy*dy + dz*dz)
            if len < 0.1 then dx, dy, dz, len = 0, 1, 0, 1 end
            vel = {
                x = dx / len * sp + (math.random() - 0.5) * 3,
                y = math.abs(dy / len) * sp * 0.5 + 2 + math.random() * 3,
                z = dz / len * sp + (math.random() - 0.5) * 3,
            }
        end
        local obj = minetest.add_entity(spawn, "doggiowars:debris", node_tile(pick.n))
        if obj then obj:set_velocity(vel) end
    end
end

local function fire_burst(pos)
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
        texture    = "doggiowars_particle_engine.png",
        glow       = 14,
    })
end

-- Kulový kráter (zničená stíhačka, zásah letadla)
function doggiowars.explode_voxels(pos, radius)
    local removed = carve_capsule(pos, pos, radius)
    spawn_debris(removed, pos, 3 + math.floor(radius * 2))
    fire_burst(pos)
end

-- Průstřel terénem ve směru dir (jednotkový vektor)
function doggiowars.bore_tunnel(pos, dir, radius, length)
    local a = vector.subtract(pos, vector.multiply(dir, TUNNEL_BACKSET))
    local b = vector.add(pos, vector.multiply(dir, length))
    local removed = carve_capsule(a, b, radius)
    spawn_debris(removed, pos, 3 + math.floor(radius * 2), dir)
    fire_burst(pos)
end

---------------------------------------------------------------------------
-- Bullet entity
---------------------------------------------------------------------------

minetest.register_entity(":doggiowars:bullet", {
    initial_properties = {
        visual            = "sprite",
        textures          = {"doggiowars_particle_engine.png"},
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
                    -- směr z výstřelu: rychlost po kolizi už je vynulovaná
                    local dir = self._dir
                    if dir then
                        doggiowars.bore_tunnel(pos, dir, TUNNEL_RADIUS, TUNNEL_LENGTH)
                    else
                        doggiowars.explode_voxels(pos, TUNNEL_RADIUS)
                    end
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
                if ent and ent.name == "doggiowars:fighter"
                        and ent.hp and ent.hp > 0 and not ent.is_dead then
                    -- Don't hit the shooter's own plane
                    local is_own = self._shooter_name ~= nil
                        and ent.pilot_name == self._shooter_name
                    if not is_own then
                        ent:damage_fighter(BULLET_DAMAGE)
                        doggiowars.explode_voxels(pos, EXPLODE_RADIUS_HIT)
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
            texture        = "doggiowars_particle_engine.png",
            glow           = 12,
        })
    end,
})

---------------------------------------------------------------------------
-- Shoot function — called from vehicle.lua on_step
---------------------------------------------------------------------------

function doggiowars.shoot_bullet(fighter_self)
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

    -- Muzzle: 6 blocks in front of center — first-person kamera pilota sedí
    -- ~4 jednotky před středem, muzzle musí být až před ní
    local muzzle = {
        x = pos.x + dir.x * 6,
        y = pos.y + dir.y * 6,
        z = pos.z + dir.z * 6,
    }

    local bullet = minetest.add_entity(muzzle, "doggiowars:bullet")
    if not bullet then return end

    -- Add plane velocity so bullet doesn't arc backward when diving
    local plane_vel = fighter_self.object:get_velocity() or {x = 0, y = 0, z = 0}
    local vel = {
        x = dir.x * BULLET_SPEED + plane_vel.x,
        y = dir.y * BULLET_SPEED + plane_vel.y,
        z = dir.z * BULLET_SPEED + plane_vel.z,
    }
    bullet:set_velocity(vel)

    local ent = bullet:get_luaentity()
    if ent then
        ent._shooter_name = fighter_self.pilot_name
        ent._dir = vector.normalize(vel)
    end

    -- Muzzle flash (malý — je přímo před first-person kamerou)
    minetest.add_particle({
        pos            = muzzle,
        velocity       = {x = 0, y = 0, z = 0},
        acceleration   = {x = 0, y = 0, z = 0},
        expirationtime = 0.08,
        size           = 2.0,
        texture        = "doggiowars_particle_engine.png",
        glow           = 15,
    })
end
