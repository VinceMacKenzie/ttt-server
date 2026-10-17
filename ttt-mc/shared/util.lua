-- Shared helpers: coordinate conversion and Source-accurate brush/trigger tests.

SCALE = MAP_DATA.scale          -- metres per Source unit
PED_CENTER = 1.0                -- GTA ped position is ~1m above its feet
-- Source player hull (relative to feet). Source does not count a hull that only touches a trigger's face
-- (standing on a roof whose top is the top of a trigger_hurt); the feet are a bit above 0 here for that,
-- and because a GTA ped stands a few cm lower or higher than exactly 1 m below its position.
PLAYER_MINS = { -16, -16, 1 }
PLAYER_MAXS = { 16, 16, 72 }

function vec3(str)
    if type(str) == "table" then return str[1], str[2], str[3] end
    local x, y, z = tostring(str or ""):match("^%s*(%S+)%s+(%S+)%s+(%S+)")
    return tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0
end

function toWorld(x, y, z)
    local o = Config.OFFSET
    return x * SCALE + o[1], y * SCALE + o[2], z * SCALE + o[3]
end

function toSource(x, y, z)
    local o = Config.OFFSET
    return (x - o[1]) / SCALE, (y - o[2]) / SCALE, (z - o[3]) / SCALE
end

-- Source "pitch yaw roll" -> unit forward vector
function anglesToForward(p, y)
    p, y = math.rad(p), math.rad(y)
    return math.cos(p) * math.cos(y), math.cos(p) * math.sin(y), -math.sin(p)
end

-- Is an activator box (origin ax,ay,az + mins/maxs, Source units) touching the trigger brushes of
-- an entity whose origin is ox,oy,oz?  Exact Minkowski test against the brush planes (incl. bevels).
function brushesTouch(def, ox, oy, oz, ax, ay, az, amins, amaxs)
    local mn, mx = def.mins, def.maxs
    -- AABB broad phase
    if ax + amaxs[1] < ox + mn[1] or ax + amins[1] > ox + mx[1] then return false end
    if ay + amaxs[2] < oy + mn[2] or ay + amins[2] > oy + mx[2] then return false end
    if az + amaxs[3] < oz + mn[3] or az + amins[3] > oz + mx[3] then return false end
    local brushes = def.brushes
    if not brushes or #brushes == 0 then return true end
    local px, py, pz = ax - ox, ay - oy, az - oz
    for b = 1, #brushes do
        local planes = brushes[b]
        local inside = true
        for i = 1, #planes do
            local p = planes[i]
            local nx, ny, nz = p[1], p[2], p[3]
            local h = math.max(-nx * amins[1], -nx * amaxs[1]) + math.max(-ny * amins[2], -ny * amaxs[2])
                    + math.max(-nz * amins[3], -nz * amaxs[3])
            if nx * px + ny * py + nz * pz > p[4] + h + 0.01 then
                inside = false
                break
            end
        end
        if inside then return true end
    end
    return false
end

-- Player (GTA ped) position -> Source feet origin
function pedSourceOrigin(ped)
    local x, y, z = getElementPosition(ped)
    return toSource(x, y, z - PED_CENTER)
end

function lower(s) return s and string.lower(s) or nil end

function mcDebug(...)
    if Config.DEBUG then outputDebugString("[mc] " .. table.concat({ ... }, " ")) end
end

-- quick lookup of entity definitions by id (MAP_DATA.entities[i].id == i)
MAP_ENTS = MAP_DATA.entities

-- Map bounds in GTA world coordinates (metres)
do
    local b = MAP_DATA.bounds
    MAP_WMIN = { toWorld(b.mins[1], b.mins[2], b.mins[3]) }
    MAP_WMAX = { toWorld(b.maxs[1], b.maxs[2], b.maxs[3]) }
end

function insideMapXY(x, y, margin)
    margin = margin or 0
    return x >= MAP_WMIN[1] - margin and x <= MAP_WMAX[1] + margin and y >= MAP_WMIN[2] - margin and y <= MAP_WMAX[2] + margin
end

-- is a world position on/at the map (used for the fall kill and the client environment)
function nearMap(x, y, z, margin)
    margin = margin or 0
    return insideMapXY(x, y, margin) and z >= MAP_WMIN[3] - margin and z <= MAP_WMAX[3] + margin
end
