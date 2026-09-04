-- TTS-SELFUPDATE:aos-coherency-tool
--
-- ── AOS COHERENCY TOOL by Antares77 ───────────────────────────
-- A tool for checking AoS coherency and arranging units in legal formations.

-- TTS-SELFUPDATE - Update this script automatically by writing '!update' in chat.

-- The running version, handed over by the updater block below and put on the
-- UI during onLoad. Nothing sets it by hand: it is whatever TOOL_VERSION says,
-- so it stays right through every update on its own. The "?" only shows if the
-- block is not there at all.
local VERSION                = "?"

local MM_TO_INCH             = 0.0393701
local RING_CLEARANCE         = 0.10  -- world units the aura ring floats above the table
local AURA_THICK             = 0.05  -- aura ring line width
local BASE_THICK             = 0.04  -- base outline line width
-- Breach lines (models out of coherenc) only read from above with this width seemingly
local BREACH_THICK           = 0.05  -- coherency breach line width
local SEL_WATCH              = 0.3   -- s, Tag/Untag button poll (no selection event exists)
local SEL_SCAN               = 60    -- objects examined per player per poll
local MAX_UNIT               = 40    -- models per unit for coherency / shapes
local MAX_BREACH_LINES       = 24    -- breach lines drawn at once
local MOTION_TICK            = 0.1   -- s, motion loop period
local MONITOR_TIMEOUT        = 60    -- s, monitor auto-stop
-- Unit ids are uuid:77<20 digits>77. Reading accepts any uuid:<digits> tag;
-- removing accepts only the 77-bookended ones, so another script's id is never
-- stripped (e.g. yellow tags).
local TAG_PREFIX             = "uuid:"
local TAG_MARK               = "77"
local SMART_GAP              = 0.525 -- edge gap that still counts as one unit
local SMART_MAX              = 300   -- models Smart tag will look at in one go
local SMART_HILITE           = 7.5   -- s, Smart tag shows its groups in colour
local UPRIGHT_EPS            = 0.5   -- degrees of lean a shape button will ignore
-- Highlight loop: the costly rescan runs every HL_RESCAN ticks and is cached, the
-- cheap distance pass runs every tick against that cache.
local HL_TICK                = 0.3   -- s, highlight refresh
local HL_RESCAN              = 7     -- ticks between full table rescans (~2s)
local HL_MAX_SCAN            = 400   -- models the highlighter will consider
-- What counts as a model; a tagged unit counts whatever its type.
local MODEL_TYPES = { Figurine = true, Generic = true, Custom_Model = true }
-- Every copy wears this, so the copies can find each other for the overlap rule.
local TOOL_TAG               = "AoS_Coherency_Tool77"

-- Smart tag flash colours, cycled when a selection holds more units than colours.
local UNIT_COLORS = {
    {1.00, 0.25, 0.25}, {0.25, 0.60, 1.00}, {0.30, 0.90, 0.35}, {1.00, 0.85, 0.20},
    {0.85, 0.35, 1.00}, {0.20, 0.90, 0.85}, {1.00, 0.55, 0.15}, {0.65, 1.00, 0.30},
    {1.00, 0.45, 0.75}, {0.55, 0.45, 1.00}, {0.95, 0.95, 0.95}, {0.45, 0.70, 0.55},
}

-- Rounds, then ovals in both orientations.
local VALID_BASE_SIZES_IN_MM = {
    {x=25,z=25},{x=28,z=28},{x=30,z=30},{x=32,z=32},{x=40,z=40},{x=50,z=50},
    {x=55,z=55},{x=60,z=60},{x=65,z=65},{x=80,z=80},{x=90,z=90},{x=100,z=100},
    {x=130,z=130},{x=160,z=160},{x=25,z=75},{x=75,z=25},{x=35.5,z=60},
    {x=60,z=35.5},{x=40,z=95},{x=95,z=40},{x=52,z=90},{x=90,z=52},{x=70,z=105},
    {x=105,z=70},{x=92,z=120},{x=120,z=92},{x=95,z=150},{x=150,z=95},
    {x=109,z=170},{x=170,z=109},
}

-- Coherency distance modes, in UI order. Base contact = edge gap <= 0.01".
local MODES = {
    { id = "mode1", label = '0.5"',        dist = 0.5  },
    { id = "mode2", label = '2"',          dist = 2.0  },
    { id = "mode3", label = "Base contact", dist = 0.01 },
}
-- Buddy models that need to be in range for coherency
local BUDDY_IDS = { "buddyAuto", "buddy1", "buddy2" } -- 0 = auto, 1 = force 1, 2 = force 2

-- Resting is a white wash over the parchment, lit inverts it. Background and text
-- colour always move together, or a lit button ends up anthracite on anthracite.
local ANTHRACITE          = "#293133"
local ANTHRACITE_RGB      = {0.161, 0.192, 0.200}  -- the same, to mix with
-- A lit button wears the seat colour pulled toward anthracite. findSeat writes
-- ON_COLOR and FRAME_ON once the seat is known; these are the fallbacks until then.
local ACTIVE_MIX          = 0.45   -- how far toward anthracite (Teal sets the floor:
                                   -- any less and its label drops under 4.5:1)
local ACTIVE_ALPHA        = 0.85   -- and how solid, so the picture still shows
local ON_COLOR,  ON_TEXT  = "#293133d9", "#f2f1ec"
local OFF_COLOR, OFF_TEXT = "#ffffff40", ANTHRACITE
local DISABLED_TEXT       = "#a3a8aa"   -- Untag, greyed for a foreign unit id
local FRAME_ON,  FRAME_OFF = "#293133", "#00000000"

-- Aura colours run along a ramp with one stop per button: a pale tint of the seat
-- colour at 3", sweeping through neighbouring hues, back to the seat colour at
-- depth. Consecutive stops differ by at least 0.25 in some channel, which
-- tests/highlight_test.lua enforces. White is for a two-aura overlap, so
-- no ramp starts near it.
local AURA_STOPS      = { 3, 6, 9, 12, 18 }  -- the radii the five stops sit on
local AURA_BTN_ALPHA  = 0.38  -- how solid a button wears its own ring colour; any
                              -- more drops the anthracite label under 4.5:1 on the
                              -- dark stops
local OVERLAP_COLOR   = {1, 1, 1}
-- Seats a tool can belong to. White, Grey and Black are the spectator, the GM and
-- the table owner, not a side with an army.
local SEAT_COLORS = { "Red", "Orange", "Yellow", "Green", "Teal",
                      "Blue", "Purple", "Pink", "Brown" }
-- Five stops each, for 3" 6" 9" 12" 18".
local SEAT_RAMPS = {
    -- light red, amber, orange, red, deep crimson
    Red    = { {0.92,0.51,0.50}, {1.00,0.60,0.00}, {0.95,0.25,0.00},
               {0.65,0.03,0.12}, {0.38,0.00,0.20} },
    -- apricot, yellow, orange, rust, dark rust
    Orange = { {0.98,0.67,0.51}, {1.00,0.78,0.10}, {0.98,0.48,0.00},
               {0.72,0.26,0.00}, {0.42,0.14,0.00} },
    -- pale yellow, yellow, gold, bronze, dark olive
    Yellow = { {0.95,0.94,0.54}, {1.00,0.82,0.02}, {0.78,0.54,0.00},
               {0.50,0.32,0.00}, {0.22,0.13,0.02} },
    -- pale green, lime, green, emerald, deep forest
    Green  = { {0.56,0.84,0.54}, {0.50,0.90,0.10}, {0.10,0.72,0.28},
               {0.02,0.45,0.32}, {0.00,0.20,0.16} },
    -- pale teal, mint, cyan, sea, deep teal
    Teal   = { {0.67,0.88,0.85}, {0.40,0.95,0.55}, {0.00,0.82,0.78},
               {0.00,0.50,0.62}, {0.00,0.24,0.34} },
    -- light blue, green, cyan, azure, deep blue
    Blue   = { {0.51,0.74,1.00}, {0.20,0.88,0.35}, {0.00,0.72,0.80},
               {0.03,0.35,0.92}, {0.06,0.08,0.60} },
    -- lilac, magenta, violet, indigo, deep purple
    Purple = { {0.79,0.52,0.97}, {1.00,0.25,0.85}, {0.72,0.05,0.88},
               {0.42,0.02,0.72}, {0.20,0.00,0.40} },
    -- pale pink, coral, hot pink, rose, deep rose
    Pink   = { {0.98,0.69,0.89}, {1.00,0.52,0.35}, {1.00,0.18,0.55},
               {0.72,0.00,0.40}, {0.42,0.00,0.24} },
    -- light brown, tan, ochre, russet, bark
    Brown  = { {0.61,0.46,0.36}, {0.88,0.66,0.28}, {0.68,0.40,0.06},
               {0.42,0.20,0.02}, {0.16,0.07,0.02} },
}
-- Fallback when no hand zone is near the tool.
local NEUTRAL_RAMP = { {0.68,0.72,0.75}, {0.53,0.56,0.55}, {0.39,0.41,0.40},
                       {0.25,0.27,0.28}, {0.11,0.13,0.16} }

-- The XML names the picture (image="aosPanelBg") and that name resolves against the
-- object's Custom UI Assets list, filled in on load.
local UI_ASSETS = {
    { name = "aosPanelBg",
      url  = "https://steamusercontent-a.akamaihd.net/ugc/12352082712112839381/58ABA6CE8570F5CB9E72C7E53BE4BE3A2CD8C9F7/" },
} -- Must be hosted, e.g. directly on the Steam Cloud

-- ---------------------------------------------------------------- state -----
local uiMode        = 1              -- index into MODES
local buddyOverride = 0              -- 0 auto | 1 force 1 | 2 force 2
local lastCustom    = "4"
local seatColor     = nil            -- name of the seat this tool serves
local seatRamp      = NEUTRAL_RAMP   -- and the five stops its auras run through
local actingColor   = nil            -- whoever pressed the last button, for broadcasts
local selTagState   = nil            -- last known "selection contains a tagged unit"

local monActive, monTimer, monTimeout = false, nil, nil
local monGuids, monIdx, monDesc, monBase, monDrop = {}, {}, {}, {}, {}
local monGap, monCp, monPrevMoving = {}, {}, {}
local monTag, monGlowed, monGlowState = nil, {}, {}

local undoStack = {}
local selWatchTimer = nil

-- Highlighter. hlApplied is what THIS tool is currently lighting and in what
-- colour, so each tick only touches models whose colour actually changed.
local hlActive, hlTimer, hlSince = false, nil, 0
local hlModels, hlSources = {}, {}   -- caches, rebuilt every HL_RESCAN ticks
local hlClaims, hlApplied = {}, {}

-- ======================================================= GEOMETRY CORE ======
-- No TTS API calls anywhere below until the "base + descriptors" header.
local sqrt, cos, sin, rad, deg = math.sqrt, math.cos, math.sin, math.rad, math.deg
local floor, ceil, abs, max, min = math.floor, math.ceil, math.abs, math.max, math.min
local atan2 = math.atan2 or math.atan   -- 5.2 has atan2; 5.3+ folds it into atan
local SQRT3_2 = sqrt(3) / 2             -- also cos(30 deg): the triangle cap offset
local EPS = 1e-6

-- A descriptor is { pos, a, b, right, forward }: a and b are the base's
-- semi-radii along the model's local x/z, right and forward its local axes as
-- world unit vectors. Rotation-correct for ovals, with no handedness guess.
local function makeDesc(x, z, a, b, yawDeg)
    local t = rad(yawDeg or 0)
    return {
        pos     = { x = x, y = 0, z = z },
        a       = max(a, 0.01), b = max(b, 0.01),
        right   = { x = cos(t), y = 0, z = -sin(t) },
        forward = { x = sin(t), y = 0, z =  cos(t) },
    }
end

-- Ellipse polar equation: the base's radius along world unit direction (dx,dz).
local function baseRadiusInDir(d, dx, dz)
    local lx = dx * d.right.x   + dz * d.right.z
    local lz = dx * d.forward.x + dz * d.forward.z
    return 1 / sqrt((lx * lx) / (d.a * d.a) + (lz * lz) / (d.b * d.b))
end

-- Horizontal edge-to-edge gap, plus the base-edge point on each (for drawing).
local function baseGap(d1, d2)
    local dx, dz = d2.pos.x - d1.pos.x, d2.pos.z - d1.pos.z
    local centre = sqrt(dx * dx + dz * dz)
    if centre < EPS then return 0, d1.pos, d2.pos end
    local ux, uz = dx / centre, dz / centre
    local r1 = baseRadiusInDir(d1,  ux,  uz)
    local r2 = baseRadiusInDir(d2, -ux, -uz)
    local gap = centre - r1 - r2
    if gap < 0 then gap = 0 end
    return gap,
        { x = d1.pos.x + ux * r1, z = d1.pos.z + uz * r1 },
        { x = d2.pos.x - ux * r2, z = d2.pos.z - uz * r2 }
end

-- AoS Ruling: 1 buddy, 2 once the unit is 7+. Capped at n-1, so a lone model is legal.
local function requiredBuddies(n, override)
    local req
    if override == 1 or override == 2 then req = override
    elseif n >= 7 then req = 2
    else req = 1 end
    if req > n - 1 then req = n - 1 end
    if req < 0 then req = 0 end
    return req
end

-- Read a filled gap matrix: buddy counts, pass/fail, each model's nearest
-- neighbour (for breach lines) and the connected-group count (informational --
-- a split unit is just a warning, but not a failure). Split out from evaluate() so the
-- live monitor can re-read its cached matrix without redoing the distance work.
local function summarize(gap, n, dist, req)
    local adj, buddies, near = {}, {}, {}
    for i = 1, n do adj[i], buddies[i], near[i] = {}, 0, 0 end
    local thr = dist + EPS
    for i = 1, n - 1 do
        for j = i + 1, n do
            local g = gap[i][j]
            if g ~= nil then
                if g <= thr then
                    buddies[i] = buddies[i] + 1; buddies[j] = buddies[j] + 1
                    adj[i][#adj[i] + 1] = j;     adj[j][#adj[j] + 1] = i
                end
                if near[i] == 0 or g < gap[i][near[i]] then near[i] = j end
                if near[j] == 0 or g < gap[j][near[j]] then near[j] = i end
            end
        end
    end
    local ok, fails = {}, 0
    for i = 1, n do
        ok[i] = buddies[i] >= req
        if not ok[i] then fails = fails + 1 end
    end
    local seen, groups = {}, 0                      -- flood fill for the groups
    for i = 1, n do
        if not seen[i] then
            groups, seen[i] = groups + 1, true
            local stack = { i }
            while #stack > 0 do
                local v = stack[#stack]; stack[#stack] = nil
                for _, w in ipairs(adj[v]) do
                    if not seen[w] then seen[w] = true; stack[#stack + 1] = w end
                end
            end
        end
    end
    return { n = n, req = req, gap = gap, buddies = buddies, near = near,
             ok = ok, fails = fails, groups = groups }
end

-- Full O(n^2) evaluation from scratch: measure every pair, then summarize.
local function evaluate(descs, dist, req)
    local n = #descs
    local gap, cp = {}, {}
    for i = 1, n do gap[i], cp[i] = {}, {} end
    for i = 1, n - 1 do
        for j = i + 1, n do
            local g, p1, p2 = baseGap(descs[i], descs[j])
            gap[i][j], gap[j][i] = g, g
            cp[i][j],  cp[j][i]  = p1, p2
        end
    end
    local r = summarize(gap, n, dist, req)
    r.cp = cp
    return r
end

-- Single-linkage clustering by base-edge gap: two models belong to the same unit
-- when their bases are within maxGap, theand that relation is transitive, so a rank
-- of models each half an inch from the next is one unit while an inch of empty
-- table between two blocks splits them. Returns comp[i] = unit index (numbered in
-- input order) and the number of units found. Results in grouping up units from
-- all selected models (typically an army).
local function clusterByGap(descs, maxGap)
    local n, thr = #descs, maxGap + EPS
    local adj = {}
    for i = 1, n do adj[i] = {} end
    for i = 1, n - 1 do
        for j = i + 1, n do
            local g = baseGap(descs[i], descs[j])
            if g <= thr then
                adj[i][#adj[i] + 1] = j; adj[j][#adj[j] + 1] = i
            end
        end
    end
    local comp, k = {}, 0
    for i = 1, n do
        if comp[i] == nil then
            k = k + 1
            comp[i] = k
            local stack = { i }
            while #stack > 0 do
                local v = stack[#stack]; stack[#stack] = nil
                for _, w in ipairs(adj[v]) do
                    if comp[w] == nil then comp[w] = k; stack[#stack + 1] = w end
                end
            end
        end
    end
    return comp, k
end

-- Long axis of the formation: principal eigenvector of the 2D covariance of the
-- models' x/z positions. n <= 3 uses the most-separated pair; a degenerate
-- spread falls back to world +x.
local function principalAxis(descs)
    local n, X = #descs, { x = 1, z = 0 }
    if n < 2 then return X end
    if n <= 3 then
        local best, bx, bz = -1, 1, 0
        for i = 1, n - 1 do for j = i + 1, n do
            local dx = descs[j].pos.x - descs[i].pos.x
            local dz = descs[j].pos.z - descs[i].pos.z
            local d2 = dx * dx + dz * dz
            if d2 > best then best, bx, bz = d2, dx, dz end
        end end
        if best < EPS then return X end
        return { x = bx / sqrt(best), z = bz / sqrt(best) }
    end
    local mx, mz = 0, 0
    for i = 1, n do mx = mx + descs[i].pos.x; mz = mz + descs[i].pos.z end
    mx, mz = mx / n, mz / n
    local sxx, szz, sxz = 0, 0, 0
    for i = 1, n do
        local dx, dz = descs[i].pos.x - mx, descs[i].pos.z - mz
        sxx = sxx + dx * dx; szz = szz + dz * dz; sxz = sxz + dx * dz
    end
    if sxx + szz < EPS then return X end
    local tr  = sxx + szz
    local lam = tr / 2 + sqrt(max(0, tr * tr / 4 - (sxx * szz - sxz * sxz)))
    local vx, vz = sxz, lam - sxx
    if abs(vx) + abs(vz) < EPS then vx, vz = lam - szz, sxz end
    if abs(vx) + abs(vz) < EPS then return X end
    local m = sqrt(vx * vx + vz * vz)
    return { x = vx / m, z = vz / m }
end

-- The circles of radius dP about P and dQ about Q meet in two points, mirrored
-- across the P->Q line; both are returned and the caller picks a side. A solution
-- always exists: the two target distances always sum to more than |PQ|.
local function triangulate(Px, Pz, dP, Qx, Qz, dQ)
    local dx, dz = Qx - Px, Qz - Pz
    local D = sqrt(dx * dx + dz * dz)
    if D < EPS then dx, dz, D = 1, 0, EPS end
    local t  = (D * D + dP * dP - dQ * dQ) / (2 * D)
    local h2 = dP * dP - t * t
    local h  = h2 > 0 and sqrt(h2) or 0
    local ex, ez = dx / D, dz / D
    local ax, az = Px + ex * t, Pz + ez * t          -- foot on the P->Q line
    local nx, nz = -ez * h, ex * h                   -- perpendicular offset
    return ax + nx, az + nz, ax - nx, az - nz
end

local function dist2(ax, az, bx, bz)
    local dx, dz = bx - ax, bz - az
    return dx * dx + dz * dz
end

-- ---- slot generators -------------------------------------------------------
-- Each returns { {along, perp}, ... } in sorted-model order about an arbitrary
-- origin; buildLayout re-anchors on the centroid. rin(k, dx, dz) is model k's
-- semi-radius along layout-frame direction (dx,dz): an oval presents a different
-- radius to every neighbour, so spacing is asked for per direction.

-- Centre-to-centre distance putting i and j at edge gap g, given where they sit.
-- The direction depends on the answer, so callers iterate; the half-step damping
-- (prev) is what stops a 3:1 oval oscillating.
local function pairDist(rin, i, j, xi, zi, xj, zj, g, prev)
    local dx, dz = xj - xi, zj - zi
    local m = sqrt(dx * dx + dz * dz)
    if m < EPS then dx, dz, m = 1, 0, 1 end
    dx, dz = dx / m, dz / m
    local d = rin(i, dx, dz) + g + rin(j, -dx, -dz)
    if prev == nil then return d end
    return 0.5 * (prev + d)
end

-- Per-pair steps: every consecutive edge gap is exactly g. Neighbours lie along
-- the axis, so no iteration is needed.
local function slotsSingleLine(n, rin, g)
    local out = { {0, 0} }
    for k = 2, n do
        out[k] = { out[k - 1][1] + rin(k - 1, 1, 0) + g + rin(k, -1, 0), 0 }
    end
    return out
end

-- Settle model k at edge gap g from two already-placed anchors, i at (Px,Pz) and
-- j at (Qx,Qz). Both target distances depend on where k ends up, so this
-- iterates: `pick` chooses between the two mirrored solutions on the first pass,
-- and every later pass stays on whichever side that first choice landed.
local function settle(rin, g, i, Px, Pz, j, Qx, Qz, k, pick)
    local dP = rin(i, 1, 0) + g + rin(k, -1, 0)
    local dQ = rin(j, 1, 0) + g + rin(k, -1, 0)
    local x, z = pick(triangulate(Px, Pz, dP, Qx, Qz, dQ))
    for _ = 1, 12 do
        dP = pairDist(rin, i, k, Px, Pz, x, z, g, dP)
        dQ = pairDist(rin, j, k, Qx, Qz, x, z, g, dQ)
        local a, b, c, d = triangulate(Px, Pz, dP, Qx, Qz, dQ)
        if dist2(x, z, a, b) <= dist2(x, z, c, d) then x, z = a, b else x, z = c, d end
    end
    return x, z
end

-- Hex-staggered two-rank block, built as a chain of triangles: model k sits at
-- edge gap exactly g from BOTH k-1 and k-2, which is what makes it legal for any
-- n >= 3 (model 1 has 2 and 3, model 2 has 1 and 3).
local function slotsChain(n, rin, g)
    local out = { {0, 0} }
    if n >= 2 then
        local d = rin(1, 1, 0) + g + rin(2, -1, 0)
        for _ = 1, 6 do
            out[2] = { d * 0.5, d * SQRT3_2 }             -- 60 deg off the axis
            d = pairDist(rin, 1, 2, 0, 0, out[2][1], out[2][2], g, d)
        end
    end
    -- Pick the solution farther from k-3, the model the chain would otherwise
    -- fold back onto. "Farther along the axis" looks equivalent but degenerates
    -- when k-2 and k-1 line up with the axis, and a fold stacks two bases.
    for k = 3, n do
        local rx, rz = -1e6, 0                            -- k=3: just go forward
        if k >= 4 then rx, rz = out[k - 3][1], out[k - 3][2] end
        out[k] = { settle(rin, g, k - 2, out[k - 2][1], out[k - 2][2],
                                 k - 1, out[k - 1][1], out[k - 1][2], k,
            function(x1, z1, x2, z2)
                if dist2(rx, rz, x1, z1) >= dist2(rx, rz, x2, z2) then return x1, z1 end
                return x2, z2
            end) }
    end
    return out
end

-- The Dogbone: a straight line of n-4 with a 2-model cap at each end. Each cap
-- model sits at edge gap g from the end model and from its partner, so it has 2
-- buddies and the apex gains 2. This is usually for maximum spread while still
-- respecting coherency.
local function slotsTriangles(n, rin, g)
    local out, prev = {}, 0
    for k = 1, n - 4 do
        if k > 1 then prev = prev + rin(k + 1, 1, 0) + g + rin(k + 2, -1, 0) end
        out[k + 2] = { prev, 0 }
    end
    local function cap(iA, i1, i2, sign)          -- sign: -1 front cap, +1 rear
        local ax, az = out[iA][1], out[iA][2]
        local dx, dz = sign * SQRT3_2, 0.5        -- 30 deg off the axis
        local d1 = rin(iA, dx, dz) + g + rin(i1, -dx, -dz)
        out[i1] = { ax + dx * d1, az + dz * d1 }
        -- The partner mirrors i1 across the axis: take the negative-perp side.
        out[i2] = { settle(rin, g, iA, ax, az, i1, out[i1][1], out[i1][2], i2,
            function(x1, z1, x2, z2)
                if z1 <= z2 then return x1, z1 end
                return x2, z2
            end) }
    end
    cap(3, 1, 2, -1)
    cap(n - 2, n - 1, n, 1)
    return out
end

-- Hex grid: column step s, row step s*sqrt(3)/2, odd rows offset by s/2. cols is
-- picked so the footprint comes out roughly square, and a short final row is
-- centred on whole columns so its models keep landing in the previous row's
-- valleys -- without that, a lone trailing model (n=13) would have only 1 buddy.
-- A lattice must use ONE step for every pair, so s is clamped between "wide enough
-- not to overlap the widest base" and "narrow enough to keep the narrowest pair
-- coherent". When a unit's bases differ by more than the coherency distance that
-- band is empty; fall back to the tightest step the widest base allows and flag it
-- in the second return value so the caller can say so.
local function slotsHoneycomb(n, rmaxK, rminK, g, dist)
    local rmin, rmax = rminK[1], rmaxK[1]
    for k = 2, n do
        if rminK[k] < rmin then rmin = rminK[k] end
        if rmaxK[k] > rmax then rmax = rmaxK[k] end
    end
    local floorS, ceilS = 2 * rmax + 0.01, 2 * rmin + dist
    local tight = floorS > ceilS
    local s = floorS                                     -- minimum spacing
    if not tight then
        s = min(2 * rmax + g, ceilS - 0.02 * dist)
        if s < floorS then s = floorS end
    end
    local cols = max(2, floor(sqrt(0.866 * n) + 0.5))
    local rows = ceil(n / cols)
    local c0   = floor((cols - (n - (rows - 1) * cols)) / 2)
    local h, out = s * SQRT3_2, {}
    for k = 1, n do
        local idx = k - 1
        local r   = floor(idx / cols)
        local c   = idx - r * cols
        if r == rows - 1 then c = c + c0 end
        local along = c * s
        if r % 2 == 1 then along = along + s * 0.5 end
        out[k] = { along, r * h }
    end
    return out, tight
end

-- The mode distance minus a 20% safety margin, so physics settle and float error
-- cannot push a legal layout over the line. Base contact takes the same margin:
-- 0.008" rather than 0.01", which is still base contact on any table.
local function shapeGap(modeIdx)
    return 0.8 * MODES[modeIdx].dist
end

-- Build a formation. shape is "line" | "double" | "triangles" (Dogbone) | "honey".
-- Returns newPos[i] = {x,z} aligned with the INPUT order, plus a note when the
-- shape had to be substituted. Callers keep each model's current y and rotation.
-- `axis` pins the direction the formation runs in; omit it and the unit is laid
-- out along principalAxis instead, which is what the geometry tests exercise.
local function buildLayout(shape, descs, g, dist, axis)
    local n = #descs
    if n < 1 then return {}, "no models" end
    local note = nil
    local u = axis or principalAxis(descs)
    local p = { x = -u.z, z = u.x }
    local pa, pb, order = {}, {}, {}
    for i = 1, n do
        pa[i] = descs[i].pos.x * u.x + descs[i].pos.z * u.z
        pb[i] = descs[i].pos.x * p.x + descs[i].pos.z * p.z
        order[i] = i
    end
    table.sort(order, function(i, j)
        if pa[i] ~= pa[j] then return pa[i] < pa[j] end
        return pb[i] < pb[j]
    end)

    -- Layout frame -> world. u and p are orthonormal, so unit stays unit.
    local function rin(k, dx, dz)
        return baseRadiusInDir(descs[order[k]], u.x * dx + p.x * dz,
                                                u.z * dx + p.z * dz)
    end
    if shape == "triangles" and n < 6 then
        shape, note = "line", "n<6, used Single Line"
    end
    local slots
    if shape == "line" then
        slots = slotsSingleLine(n, rin, g)
    elseif shape == "double" then
        slots = slotsChain(n, rin, g)
    elseif shape == "triangles" then
        slots = slotsTriangles(n, rin, g)
    else
        local rmaxK, rminK = {}, {}
        for k = 1, n do
            local d = descs[order[k]]
            rmaxK[k] = max(d.a, d.b); rminK[k] = min(d.a, d.b)
        end
        local tight
        slots, tight = slotsHoneycomb(n, rmaxK, rminK, g, dist)
        if tight then note = "bases too mixed for an exact grid, packed as tight as they fit" end
    end
    local sa, sb, cx, cz = 0, 0, 0, 0
    for k = 1, n do sa = sa + slots[k][1]; sb = sb + slots[k][2] end
    for i = 1, n do cx = cx + descs[i].pos.x; cz = cz + descs[i].pos.z end
    sa, sb, cx, cz = sa / n, sb / n, cx / n, cz / n
    local out = {}
    for k = 1, n do
        local a, b = slots[k][1] - sa, slots[k][2] - sb
        out[order[k]] = { x = cx + u.x * a + p.x * b, z = cz + u.z * a + p.z * b }
    end
    return out, note
end

-- Circular mean of yaw angles (degrees): the "face same way" consensus heading,
-- which turns every model the least on average.
local function meanYaw(yaws)
    local sx, sc = 0, 0
    for _, y in ipairs(yaws) do
        local t = rad(y); sx = sx + sin(t); sc = sc + cos(t)
    end
    if abs(sx) + abs(sc) < EPS then return yaws[1] or 0 end
    local d = deg(atan2(sx, sc))
    if d < 0 then d = d + 360 end
    return d
end

-- Exported for tests/geometry_test.lua only; nothing in TTS reads this.
AOS_GEO = {
    makeDesc = makeDesc, baseRadiusInDir = baseRadiusInDir, baseGap = baseGap,
    requiredBuddies = requiredBuddies, evaluate = evaluate, summarize = summarize,
    clusterByGap = clusterByGap,
    principalAxis = principalAxis, buildLayout = buildLayout,
    shapeGap = shapeGap, meanYaw = meanYaw, MODES = MODES,
}

-- ================================================== BASE + DESCRIPTORS ======
-- Everything below talks to TTS. Nothing above this line does.

local GLOW_OK     = {0.15, 0.90, 0.25}
local GLOW_BAD    = {0.95, 0.15, 0.15}
local BREACH_COL  = {1.00, 0.55, 0.10, 0.9}

local function alive(o) return o ~= nil and not o.isDestroyed() end

-- Smallest catalogued base the model's footprint still covers, cached on the
-- model itself so it is measured once per model per table, not once per tick.
local function determineBaseInInches(model)
    local saved = model.getTable("aos_base")
    if saved ~= nil and saved.base ~= nil then return saved.base end
    local size, chosen, best = model.getBoundsNormalized().size, nil, 1e10
    for _, b in ipairs(VALID_BASE_SIZES_IN_MM) do
        local bx, bz = (MM_TO_INCH - 0.001) * b.x, (MM_TO_INCH - 0.001) * b.z
        if size.x > bx and size.z > bz then
            local d = (size.x - bx) + (size.z - bz)
            if d < best then best, chosen = d, b end
        end
    end
    local out
    if chosen == nil then out = { x = size.x / 2, z = size.z / 2 }
    else out = { x = chosen.x * MM_TO_INCH / 2, z = chosen.z * MM_TO_INCH / 2 } end
    if out.x < 0.01 then out.x = 0.01 end
    if out.z < 0.01 then out.z = 0.01 end
    model.setTable("aos_base", { base = out })
    return out
end

-- yaw (degrees) overrides the model's real heading, so a layout can be computed
-- against the rotation the models are turning to: setRotationSmooth is animated,
-- so reading the rotation back would give the old pose and size ovals wrongly.
local function descOf(o, base, yaw)
    local d = { pos = o.getPosition(), a = base.x, b = base.z }
    if yaw == nil then
        d.right, d.forward = o.getTransformRight(), o.getTransformForward()
    else
        local t = rad(yaw)
        d.right   = { x = cos(t), y = 0, z = -sin(t) }
        d.forward = { x = sin(t), y = 0, z =  cos(t) }
    end
    return d
end

local function buildDesc(o, yaw) return descOf(o, determineBaseInInches(o), yaw) end

-- ================================================================ STATUS ====
-- No status panel: messages go to whoever pressed the button, as a TTS broadcast.
-- Only buttons speak; the live monitor is silent.
local function setStatus(msg)
    if actingColor ~= nil then broadcastToColor(msg, actingColor, {0.85, 0.9, 1})
    else broadcastToAll(msg, {0.85, 0.9, 1}) end
end

-- ================================================================= AURAS ====
-- Ring points are object-local (they scale with the object, hence the 1/scale) and
-- shared between identical models, so 20 Liberators generate one table, not twenty.
local ringCache = {}
-- `inset` pulls the centreline in by half the line width, so the OUTER edge of the
-- drawn ring lands on the measured range instead of overshooting it. Points and
-- inset are scaled together, so it holds on a scaled model too.
local function ringPoints(radius, a, b, sf, h, inset)
    local key = string.format("%.3f|%.3f|%.3f|%.3f|%.3f|%.3f", radius, a, b, sf, h, inset)
    local pts = ringCache[key]
    if pts ~= nil then return pts end
    pts = {}
    local ra, rb = radius + a - inset, radius + b - inset
    if ra < 0.01 then ra = 0.01 end
    if rb < 0.01 then rb = 0.01 end
    local steps = 64
    -- Built straight into the model's horizontal x/z plane at height h: a ring in
    -- the x/y plane stands upright, and a line entry's `rotation` cannot lay it down.
    for i = 0, steps do
        local t = rad(360 / steps * i)
        pts[i + 1] = { x = cos(t) * ra * sf, y = h, z = sin(t) * rb * sf }
    end
    ringCache[key] = pts
    return pts
end

-- Ring height in the model's local space, from the model's own bounds so it clears
-- a tall base instead of sinking into it.
local function ringHeight(o)
    local b, sc = o.getBoundsNormalized(), o.getScale()
    local sy = (sc.y ~= 0) and sc.y or 1
    return (b.center.y - b.size.y * 0.5 - o.getPosition().y + RING_CLEARANCE) / sy
end

-- The same height in world space, as an offset from the model's own position so it
-- holds as the model is lifted and dropped. Used by the breach lines, which are
-- drawn on the tool object and cannot borrow the model's local frame.
local function floorOffset(o)
    local b = o.getBoundsNormalized()
    return (b.center.y - b.size.y * 0.5) - o.getPosition().y + RING_CLEARANCE
end

local function mixRGB(a, b, t)
    return { a[1] + (b[1] - a[1]) * t,
             a[2] + (b[2] - a[2]) * t,
             a[3] + (b[3] - a[3]) * t }
end

-- Where a radius sits on the seat ramp: each preset gets its own stop, a custom
-- radius interpolates between the two it falls between, and anything past 18"
-- keeps the last stop.
local function auraColor(r)
    local n = #AURA_STOPS
    if r <= AURA_STOPS[1] then return seatRamp[1] end
    for i = 1, n - 1 do
        local a, b = AURA_STOPS[i], AURA_STOPS[i + 1]
        if r <= b then return mixRGB(seatRamp[i], seatRamp[i + 1], (r - a) / (b - a)) end
    end
    return seatRamp[n]
end

local function hexRGB(c, alpha)
    local function ch(v)
        v = floor(v * 255 + 0.5)
        if v < 0 then v = 0 elseif v > 255 then v = 255 end
        return v
    end
    if alpha == nil then
        return string.format("#%02x%02x%02x", ch(c[1]), ch(c[2]), ch(c[3]))
    end
    return string.format("#%02x%02x%02x%02x", ch(c[1]), ch(c[2]), ch(c[3]), ch(alpha))
end

-- Every ring this model carries, plus a thin outline of the base itself, in ONE
-- setVectorLines call.
local function drawAuras(o)
    local list, lines = o.getTable("aos_auras"), {}
    if list ~= nil and #list > 0 then
        local b, sf, h = determineBaseInInches(o), 1 / o.getScale().x, ringHeight(o)
        lines[1] = { points = ringPoints(0, b.x, b.z, sf, h, BASE_THICK * 0.5),
                     color = {1, 1, 1, 0.85}, thickness = BASE_THICK }
        for _, r in ipairs(list) do
            lines[#lines + 1] = { points = ringPoints(r, b.x, b.z, sf, h, AURA_THICK * 0.5),
                                  color = auraColor(r), thickness = AURA_THICK }
        end
    end
    o.setVectorLines(lines)
end

-- One ring at a time: a new radius replaces whatever the model was carrying, and
-- pressing the radius it already has clears it. Returns true when a ring is now
-- showing. Stored on the model, so it survives save/load.
local function setAura(o, r)
    local list = o.getTable("aos_auras")
    local same = list ~= nil and list[1] ~= nil and abs(list[1] - r) < 0.001
    o.setTable("aos_auras", same and {} or { r })
    drawAuras(o)
    return not same
end

-- Sets rather than toggles, because onEndEdit also fires on clicking away: firing
-- twice on the same radius has to leave the ring up. The presets keep the toggle.
local function forceAura(o, r)
    o.setTable("aos_auras", { r })
    drawAuras(o)
end

local function clearAuras(o)
    o.setTable("aos_auras", {})
    o.setVectorLines({})
end

-- =============================================================== TAGGING ====
local function objectsWithTag(tag)
    if getObjectsWithTag ~= nil then
        local r = getObjectsWithTag(tag)
        if r ~= nil then return r end
    end
    local out = {}                                  -- fallback: one full pass
    for _, o in ipairs(getAllObjects()) do
        if o.hasTag(tag) then out[#out + 1] = o end
    end
    return out
end

local TAG_ANY = "^" .. TAG_PREFIX .. "%d+$"                            -- anyone's
local TAG_OUR = "^" .. TAG_PREFIX .. TAG_MARK .. "%d+" .. TAG_MARK .. "$"  -- ours
local function isUnitTag(t) return string.match(t, TAG_ANY) ~= nil end
local function isOurTag(t)  return string.match(t, TAG_OUR) ~= nil end

-- The unit a model belongs to. Ours wins when a model carries both, so a model
-- shared with another script still resolves to one unit here.
local function unitTagOf(o)
    local tags = o.getTags()
    if tags == nil then return nil end
    local other = nil
    for _, t in ipairs(tags) do
        if isOurTag(t) then return t end
        if other == nil and isUnitTag(t) then other = t end
    end
    return other
end

-- Only ever strips our own ids; a foreign uuid: tag on the same model survives.
local function stripOurTags(o)
    local tags = o.getTags()
    if tags == nil then return end
    for _, t in ipairs(tags) do
        if isOurTag(t) then o.removeTag(t) end
    end
end

local function selectionOf(playerColor)
    local pl, out = Player[playerColor], {}
    if pl == nil then return out end
    local sel = pl.getSelectedObjects()
    if sel == nil then return out end
    for _, o in ipairs(sel) do if alive(o) then out[#out + 1] = o end end
    return out
end

-- One uuid tag in the selection -> the whole unit, selected or not. None -> the
-- raw selection as an ad-hoc unit. Two or more -> refuse. Returns objs,tag,err.
local function resolveUnit(playerColor)
    local sel = selectionOf(playerColor)
    if #sel == 0 then return nil, nil, "Select models first" end
    local seen, tags = {}, {}
    for _, o in ipairs(sel) do
        local t = unitTagOf(o)
        if t ~= nil and not seen[t] then seen[t] = true; tags[#tags + 1] = t end
    end
    if #tags > 1 then
        return nil, nil, "Selection spans " .. #tags .. " units"
    end
    if #tags == 0 then return sel, nil, nil end
    local objs = {}
    for _, o in ipairs(objectsWithTag(tags[1])) do
        if alive(o) then objs[#objs + 1] = o end
    end
    return objs, tags[1], nil
end

-- ===================================================== COHERENCY MONITOR ====
local refreshUI            -- forward declaration; defined with the UI glue
local hlGlowsLost          -- forward declaration; defined with the highlighter

local function clearMonitorVisuals()
    local released = {}
    for guid in pairs(monGlowed) do                 -- only ever our own glows
        local o = getObjectFromGUID(guid)
        if alive(o) then o.highlightOff() end
        released[#released + 1] = guid
    end
    monGlowed, monGlowState = {}, {}
    self.setVectorLines({})
    -- Those highlightOff calls may have taken an aura glow off with them.
    if hlGlowsLost ~= nil then hlGlowsLost(released) end
end

local function stopMonitor(msg)
    monActive = false
    if monTimer   ~= nil then Wait.stop(monTimer);   monTimer   = nil end
    if monTimeout ~= nil then Wait.stop(monTimeout); monTimeout = nil end
    clearMonitorVisuals()
    monGuids, monIdx, monDesc, monBase, monDrop = {}, {}, {}, {}, {}
    monGap, monCp, monPrevMoving, monTag = {}, {}, {}, nil
    if msg ~= nil then setStatus(msg) end
end

-- One model moved: re-measure only its row/column of the cached matrices. O(n).
local function recomputeRow(i)
    local di = monDesc[i]
    if di == nil then return end
    for j = 1, #monDesc do
        if j ~= i and monDesc[j] ~= nil then
            local g, pi, pj = baseGap(di, monDesc[j])
            monGap[i][j], monGap[j][i] = g, g
            monCp[i][j],  monCp[j][i]  = pi, pj
        end
    end
end

-- Resolve the monitored guids to live objects, dropping any that were deleted so
-- indices stay dense, then measure every pair once. Start and deletions only --
-- never per tick. Returns the live model count.
local function fullRecompute()
    local guids, desc, base, drop = {}, {}, {}, {}
    for _, guid in ipairs(monGuids) do
        local o = getObjectFromGUID(guid)
        if alive(o) then
            guids[#guids + 1] = guid
            base[#base + 1]   = determineBaseInInches(o)
            desc[#desc + 1]   = descOf(o, base[#base])
            drop[#drop + 1]   = floorOffset(o)      -- shape, not pose: cache once
        end
    end
    monGuids, monDesc, monBase, monDrop = guids, desc, base, drop
    monIdx, monGap, monCp = {}, {}, {}
    for i = 1, #guids do
        monIdx[guids[i]] = i
        monGap[i], monCp[i] = {}, {}
    end
    for i = 1, #desc do recomputeRow(i) end
    return #desc
end

-- Glow every model and draw a breach line from each failing model to its nearest
-- neighbour. Silent; returns the summary for the button that started the check.
-- Breach lines live on the tool object, in its own local space.
local function drawMonitor()
    local n = #monDesc
    if n == 0 then return end
    local dist = MODES[uiMode].dist
    local r = summarize(monGap, n, dist, requiredBuddies(n, buddyOverride))
    local want = {}
    for i = 1, n do
        local guid = monGuids[i]
        local o = getObjectFromGUID(guid)
        if alive(o) then
            -- Only re-issue the glow when this model's verdict actually flipped.
            if monGlowState[guid] ~= r.ok[i] then
                o.highlightOn(r.ok[i] and GLOW_OK or GLOW_BAD)
                monGlowState[guid] = r.ok[i]
            end
            want[guid] = true
        end
    end
    local released = nil
    for guid in pairs(monGlowed) do
        if want[guid] == nil then
            local o = getObjectFromGUID(guid)
            if alive(o) then o.highlightOff() end
            monGlowState[guid] = nil
            released = released or {}
            released[#released + 1] = guid
        end
    end
    monGlowed = want
    -- monGlowed is updated FIRST: the highlighter decides what the monitor owns by
    -- reading it, and these models are no longer in it.
    if released ~= nil and hlGlowsLost ~= nil then hlGlowsLost(released) end
    -- A plain segment between the two base edges at one shared height, mapped
    -- through positionToLocal so it lands where the models are whatever the tool
    -- object's transform is.
    local lines, drawn = {}, 0
    for i = 1, n do
        if not r.ok[i] and r.near[i] > 0 then
            if drawn >= MAX_BREACH_LINES then break end
            local j = r.near[i]
            local a, b = monCp[i][j], monCp[j][i]
            -- Just above the tabletop, so it reads as drawn ON it.
            local y = monDesc[i].pos.y + (monDrop[i] or RING_CLEARANCE)
            lines[#lines + 1] = {
                points = { self.positionToLocal({ x = a.x, y = y, z = a.z }),
                           self.positionToLocal({ x = b.x, y = y, z = b.z }) },
                color = BREACH_COL, thickness = BREACH_THICK,
            }
            drawn = drawn + 1
        end
    end
    self.setVectorLines(lines)
    return r
end

local motionTick                -- forward declaration; defined just below
local function startMotionLoop()
    if not monActive or monTimer ~= nil then return end
    monTimer = Wait.time(motionTick, MOTION_TICK, -1)
end

-- Refresh only the models actually in motion, then redraw. The loop stops its own
-- timer the moment nothing is moving; onObjectPickUp / onObjectDrop, or a shape
-- move, start it again.
motionTick = function()
    if not monActive then return end
    local moving, obj, rebuild = {}, {}, false
    for i = 1, #monGuids do
        local o = getObjectFromGUID(monGuids[i])
        if not alive(o) then rebuild = true
        elseif o.held_by_color ~= nil or o.resting == false then
            moving[i], obj[i] = true, o
        end
    end
    if rebuild then
        monPrevMoving = {}
        if fullRecompute() < 2 then
            -- Every path that stops the monitor by itself has to unlight the
            -- button as well, or Check Coherency reads as running when it is not.
            stopMonitor("Coherency stopped: unit too small")
            refreshUI()
        else drawMonitor() end
        return
    end
    -- Union of moving-now and moving-last-tick, so the tick a model comes to
    -- rest its final position is still captured before the loop stops.
    local refresh = {}
    for i in pairs(moving) do refresh[i] = true end
    for i in pairs(monPrevMoving) do
        if moving[i] == nil then
            local o = getObjectFromGUID(monGuids[i])
            if alive(o) then obj[i] = o; refresh[i] = true end
        end
    end
    for i in pairs(refresh) do monDesc[i] = descOf(obj[i], monBase[i]) end
    for i in pairs(refresh) do recomputeRow(i) end
    monPrevMoving = moving
    drawMonitor()
    if next(moving) == nil then
        monPrevMoving = {}
        if monTimer ~= nil then Wait.stop(monTimer); monTimer = nil end
    end
end

-- Object events fire for every object on the table, so bail cheaply first.
function onObjectPickUp(playerColor, obj)
    if not monActive then return end
    if monIdx[obj.getGUID()] == nil then return end
    startMotionLoop()
end

function onObjectDrop(playerColor, obj)
    if not monActive then return end
    local i = monIdx[obj.getGUID()]
    if i == nil then return end
    monDesc[i] = descOf(obj, monBase[i])            -- snap to the new spot at once
    recomputeRow(i)
    drawMonitor()
    startMotionLoop()                               -- then track the physics settle
end

function onObjectDestroy(obj)
    if not monActive then return end
    if monIdx[obj.getGUID()] == nil then return end
    Wait.frames(function()                          -- the object still exists now
        if not monActive then return end
        if fullRecompute() < 2 then
            stopMonitor("Coherency stopped: unit too small")
            refreshUI()
        else drawMonitor() end
    end, 1)
end

local function resyncMonitor()
    if not monActive then return end
    fullRecompute()
    drawMonitor()
    startMotionLoop()
end

-- ============================================================ HIGHLIGHTS ====
-- Enable Highlight glows every model standing inside somebody's aura, in that
-- aura's own colour, and WHITE when two auras reach it at once.
--
-- Three things keep it cheap enough to leave on. The rescan -- getAllObjects plus
-- a getTags and a getTable per object -- runs once every HL_RESCAN ticks and is
-- cached; every tick against that cache is one squared-distance compare per aura
-- per model, with no square roots, for every pair two round bases can settle; and
-- hlApplied remembers what this tool lit, so a still table issues no highlightOn
-- calls at all.
local hlObj = {}                                -- guid -> object, from the rescan

local function hlRescan()
    hlModels, hlSources, hlObj = {}, {}, {}
    local all = getAllObjects()
    for i = 1, #all do
        if #hlModels >= HL_MAX_SCAN then break end
        local o = all[i]
        local tag = alive(o) and o ~= self and unitTagOf(o) or nil
        if o ~= self and alive(o) and (MODEL_TYPES[o.type] or tag ~= nil) then
            local base = determineBaseInInches(o)
            local ba, bb = base.x, base.z
            -- br and sr are the circumscribed and inscribed radii, which fence the
            -- oval work off in hlCompute; equal for a round base.
            local br = (ba > bb) and ba or bb
            local sr = (ba < bb) and ba or bb
            local guid = o.getGUID()
            hlObj[guid] = o
            hlModels[#hlModels + 1] = { o = o, guid = guid, tag = tag,
                                        a = ba, b = bb, br = br, sr = sr }
            local list = o.getTable("aos_auras")
            if list ~= nil and list[1] ~= nil then
                hlSources[#hlSources + 1] = { o = o, guid = guid, tag = tag,
                                              a = ba, b = bb, br = br, sr = sr,
                                              r = list[1], c = auraColor(list[1]) }
            end
        end
    end
end

-- Reach is base edge to base edge -- the oval the ring is drawn around, at the
-- rotation the model is standing at -- and measured FLAT: only x and z are read.
-- The oval case is fenced between the circumscribed and inscribed circles, so only
-- a model in the thin band where those disagree pays for a square root.

-- The base's own radius toward the unit vector (ux, uz). Round bases answer
-- without touching the object; an oval needs its two world axes, read once per
-- pass and thrown away at the start of the next, because models turn.
local function hlReachInDir(m, ux, uz)
    if m.br == m.sr then return m.br end
    local d = m.desc
    if d == nil then
        d = { a = m.a, b = m.b,
              right = m.o.getTransformRight(), forward = m.o.getTransformForward() }
        m.desc = d
    end
    return baseRadiusInDir(d, ux, uz)
end

local function hlCompute()
    local claims = {}
    if #hlSources == 0 then return claims end
    local n, mp = #hlModels, {}
    for i = 1, n do
        local m = hlModels[i]
        m.desc = nil
        if alive(m.o) then mp[i] = m.o.getPosition() end
    end
    for j = 1, #hlSources do
        local s = hlSources[j]
        s.desc = nil
        local p = alive(s.o) and s.o.getPosition() or nil
        if p ~= nil then
            local px, pz, r = p.x, p.z, s.r
            local outer, inner = r + s.br, r + s.sr
            for i = 1, n do
                local q, m = mp[i], hlModels[i]
                -- An aura never lights its own unit.
                if q ~= nil and m.guid ~= s.guid
                   and not (s.tag ~= nil and s.tag == m.tag) then
                    local dx, dz = q.x - px, q.z - pz
                    local d2 = dx * dx + dz * dz
                    local far, near = outer + m.br, inner + m.sr
                    local hit
                    if d2 > far * far then hit = false
                    elseif d2 <= near * near then hit = true
                    else
                        -- The band between the two circles, so measure it properly.
                        -- centre is > 0 here: a zero distance is inside `near`.
                        local centre = sqrt(d2)
                        local ux, uz = dx / centre, dz / centre
                        hit = (centre - hlReachInDir(s, ux, uz)
                                      - hlReachInDir(m, -ux, -uz)) <= r
                    end
                    if hit then
                        local cl = claims[m.guid]
                        if cl == nil then claims[m.guid] = { c = s.c, n = 1 }
                        else cl.n = cl.n + 1 end
                    end
                end
            end
        end
    end
    return claims
end

-- What THIS tool is lighting, for the other copies to read: the last tick's cached
-- answer, so a sibling asking never makes this tool recompute. A tool with its
-- highlight off publishes nothing.
function aosClaims()
    return hlActive and hlClaims or {}
end

-- The overlap rule spans tools: every copy merges the same claims from the same
-- sources and so reaches the same answer without fighting the others.
local function hlMerged()
    local merged = {}
    local function add(src)
        for guid, cl in pairs(src) do
            local m = merged[guid]
            if m == nil then merged[guid] = { c = cl.c, n = cl.n }
            else m.n = m.n + cl.n end
        end
    end
    add(hlClaims)
    for _, o in ipairs(objectsWithTag(TOOL_TAG)) do
        if o ~= self and alive(o) then
            local ok, other = pcall(function() return o.call("aosClaims") end)
            if ok and type(other) == "table" then add(other) end
        end
    end
    return merged
end

-- The monitor owns a model only while it is actually glowing it, not for as long as
-- the model is in the unit being measured, so a model it has stopped glowing is
-- free for an aura again.
local function hlOwnedByMonitor(guid)
    return monActive and monGlowed[guid] ~= nil
end

local function hlApply(merged)
    local want = {}
    for guid, cl in pairs(merged) do
        -- The monitor's green and red outrank an aura colour.
        if not hlOwnedByMonitor(guid) then
            want[guid] = (cl.n > 1) and OVERLAP_COLOR or cl.c
        end
    end
    for guid in pairs(hlApplied) do
        if want[guid] == nil and not hlOwnedByMonitor(guid) then
            local o = hlObj[guid] or getObjectFromGUID(guid)
            if alive(o) then o.highlightOff() end
        end
    end
    for guid, c in pairs(want) do
        local prev = hlApplied[guid]
        if prev == nil or prev[1] ~= c[1] or prev[2] ~= c[2] or prev[3] ~= c[3] then
            local o = hlObj[guid] or getObjectFromGUID(guid)
            if alive(o) then o.highlightOn(c) end
        end
    end
    hlApplied = want
end

local function hlStop()
    hlActive = false
    if hlTimer ~= nil then Wait.stop(hlTimer); hlTimer = nil end
    for guid in pairs(hlApplied) do
        if not hlOwnedByMonitor(guid) then
            local o = hlObj[guid] or getObjectFromGUID(guid)
            if alive(o) then o.highlightOff() end
        end
    end
    hlApplied, hlClaims = {}, {}
end

local function hlPass()
    hlClaims = hlCompute()
    hlApply(hlMerged())
end

-- Something else has taken its glow off these models -- the monitor letting a unit
-- go, or a smart-tag flash expiring. Whatever this tool believed they were wearing
-- went with it, so the record has to go too: hlApply paints by difference, and a
-- model it still thinks is lit in the right colour is one it will never light
-- again. Re-assert at once rather than leaving them dark until the next tick.
hlGlowsLost = function(guids)
    if not hlActive then return end
    for i = 1, #guids do hlApplied[guids[i]] = nil end
    hlPass()
end

local function hlTick()
    if not hlActive then return end
    hlSince = hlSince + 1
    if hlSince >= HL_RESCAN then hlSince = 0; hlRescan() end
    hlPass()
end

local function hlStart()
    hlActive, hlSince = true, 0
    hlRescan()
    hlPass()
    if hlTimer ~= nil then Wait.stop(hlTimer) end
    hlTimer = Wait.time(hlTick, HL_TICK, -1)
end

-- ================================================================ SHAPES ====
local SHAPE_LABEL = { line = "Single Line", double = "Double Line",
                      triangles = "Dogbone", honey = "Honeycomb" }

-- How far off level an angle is, folded to +/-180 so 359 reads as 1, not 359.
local function offLevel(a)
    a = a % 360
    if a > 180 then a = a - 360 end
    return abs(a)
end

-- The frame every formation is built in: the tool's own long edge as the axis the
-- shape runs along, the tool's forward as the heading every model ends on. Both
-- come off one yaw so they cannot drift apart. A y rotation of t puts local +X at
-- (cos t, -sin t) and +Z at (sin t, cos t), the frame descOf builds for that yaw.
local function toolFrame()
    local yaw = self.getRotation().y
    local t = rad(yaw)
    return { x = cos(t), z = -sin(t) }, yaw
end

-- Shapes always stand their models up: a leaning model reports its silhouette from
-- getBoundsNormalized rather than its base, so it would be spaced wrongly. Only
-- leaning models are touched. yaws[i] is the heading each model is to end on, which
-- is also the heading its descriptor is built against.
local function standUp(objs, yaws)
    for i = 1, #objs do
        local o = objs[i]
        if alive(o) then
            local r = o.getRotation()
            if offLevel(r.x) > UPRIGHT_EPS or offLevel(r.z) > UPRIGHT_EPS
               or offLevel(r.y - yaws[i]) > UPRIGHT_EPS then
                o.setRotationSmooth({ 0, yaws[i], 0 }, false, true)
            end
        end
    end
end

local function doShape(shape, playerColor)
    local objs, tag, err = resolveUnit(playerColor)
    if err ~= nil then return setStatus(err) end
    local n = #objs
    if n < 2 then return setStatus("Need 2+ models") end
    if n > MAX_UNIT then
        return setStatus("Unit too big: " .. n .. "/" .. MAX_UNIT)
    end
    -- Settle on the end pose first, so the descriptors below are built against the
    -- pose the models are about to have rather than the one they are leaving.
    local axis, yaw = toolFrame()
    local yaws = {}
    for i = 1, n do yaws[i] = yaw end
    standUp(objs, yaws)

    local descs, snap = {}, {}
    for i = 1, n do
        descs[i] = buildDesc(objs[i], yaws[i])
        snap[i]  = { guid = objs[i].getGUID(), pos = objs[i].getPosition(),
                     rot = objs[i].getRotation() }
    end
    undoStack = snap                                -- one level of undo is enough
    local dist = MODES[uiMode].dist
    local pos, note = buildLayout(shape, descs, shapeGap(uiMode), dist, axis)
    for i = 1, n do
        local p = { x = pos[i].x, y = descs[i].pos.y, z = pos[i].z }
        objs[i].setPositionSmooth(p, false, true)   -- no collision, fast
        descs[i].pos = p
    end

    -- Validate the layout we just committed to, against our own checker.
    local req = requiredBuddies(n, buddyOverride)
    local r = evaluate(descs, dist, req)
    local head = SHAPE_LABEL[shape]
    if note ~= nil then head = head .. " (" .. note .. ")" end
    if r.fails > 0 then head = head .. ": " .. r.fails .. " failing" end
    setStatus(head)
    resyncMonitor()
end

-- ============================================================= UI GLUE ======
-- XML callbacks are globals taking (player, value, id). Never assume a colour --
-- always resolve the acting player from player.color.

-- Always write background AND label colour together, so an active button can
-- never end up with a dark label on a dark background.
local function paint(id, on)
    self.UI.setAttribute(id, "color",     on and ON_COLOR or OFF_COLOR)
    self.UI.setAttribute(id, "textColor", on and ON_TEXT  or OFF_TEXT)
end

-- The seat this tool serves: the nearest player hand when it loads. Hands do not
-- wander mid-game, so once is enough; no hand near enough keeps the neutral ramp.
local function findSeat()
    local p, best, bestD = self.getPosition(), nil, nil
    for _, c in ipairs(SEAT_COLORS) do
        local ok, t = pcall(function() return Player[c].getHandTransform() end)
        if ok and type(t) == "table" and t.position ~= nil then
            local dx, dz = t.position.x - p.x, t.position.z - p.z
            local d = dx * dx + dz * dz
            if bestD == nil or d < bestD then best, bestD = c, d end
        end
    end
    if best ~= nil then
        seatColor = best
        seatRamp  = SEAT_RAMPS[best] or NEUTRAL_RAMP
    end
    -- The lit fill and the Tag ring both come off the far end of the ramp. The aura
    -- swatches do not follow: each of those is its own stop.
    local lit = mixRGB(seatRamp[#seatRamp], ANTHRACITE_RGB, ACTIVE_MIX)
    ON_COLOR = hexRGB(lit, ACTIVE_ALPHA)
    FRAME_ON = hexRGB(lit)
end

local AURA_BTN = { { id = "aura3",  r = 3  }, { id = "aura6",  r = 6 },
                   { id = "aura9",  r = 9  }, { id = "aura12", r = 12 },
                   { id = "aura18", r = 18 } }

-- Each button is filled with its own ring colour, label left anthracite on top.
local function paintAuraButtons()
    for _, b in ipairs(AURA_BTN) do
        self.UI.setAttribute(b.id, "color", hexRGB(auraColor(b.r), AURA_BTN_ALPHA))
    end
end

refreshUI = function()
    for i = 1, #MODES do paint(MODES[i].id, i == uiMode) end
    for i = 1, #BUDDY_IDS do paint(BUDDY_IDS[i], (i - 1) == buddyOverride) end
    paint("checkBtn", monActive)
    paint("hlBtn",    hlActive)
    self.UI.setAttribute("customAura", "text", lastCustom)
end

-- TTS fires no selection-changed event, so the Tag / Untag buttons need one poll.
-- It reads at most SEL_SCAN objects per seated player, stops at the first of our
-- own ids, and touches the UI only when the answer flips. This is the one timer
-- that runs while the tool is idle.
--
-- Returns "ours" | "other" | "none": the frame lights for any recognised unit,
-- Untag only for our own ids, since those are the only ones it will take off.
local function selectionTagState()
    local players = Player.getPlayers()
    if players == nil or #players == 0 then
        if actingColor == nil then return "none" end
        players = { Player[actingColor] }
    end
    local state = "none"
    for _, pl in ipairs(players) do
        if pl ~= nil then
            local sel = pl.getSelectedObjects()
            if sel ~= nil then
                for i = 1, min(#sel, SEL_SCAN) do
                    local t = alive(sel[i]) and unitTagOf(sel[i]) or nil
                    if t ~= nil then
                        if isOurTag(t) then return "ours" end
                        state = "other"
                    end
                end
            end
        end
    end
    return state
end

local function selWatchTick()
    local st = selectionTagState()
    if st == selTagState then return end
    selTagState = st
    local known, ours = (st ~= "none"), (st == "ours")
    -- Ring and inverted fill together, so Tag does not read as another lit toggle.
    self.UI.setAttribute("tagFrame", "color", known and FRAME_ON or FRAME_OFF)
    paint("tagBtn", known)
    self.UI.setAttribute("untagBtn", "interactable", ours and "true" or "false")
    self.UI.setAttribute("untagBtn", "textColor", ours and OFF_TEXT or DISABLED_TEXT)
end

-- Any model here already carrying another script's unit id, or nil. Adding ours on
-- top would put it in two units at once, so tagging leaves such a unit alone.
local function foreignTagIn(objs)
    for _, o in ipairs(objs) do
        local t = unitTagOf(o)
        if t ~= nil and not isOurTag(t) then return t end
    end
    return nil
end

-- A unit id nothing on the table is using yet: the two 77 bookends and 20 random
-- digits, assembled from four 5-digit chunks because math.random cannot produce an
-- integer that wide in one call. Smart tag applies each tag before asking for the
-- next, so the collision check sees the ids it has already handed out.
local function newUnitTag()
    for _ = 1, 20 do                                -- re-roll on collision
        local t = TAG_PREFIX .. TAG_MARK .. string.format("%05d%05d%05d%05d",
            math.random(0, 99999), math.random(0, 99999),
            math.random(0, 99999), math.random(0, 99999)) .. TAG_MARK
        if #objectsWithTag(t) == 0 then return t end
    end
    return nil
end

function aosTag(player)
    actingColor = player.color
    local sel = selectionOf(player.color)
    if #sel == 0 then return setStatus("Select models first") end
    if foreignTagIn(sel) ~= nil then return setStatus("Already tagged elsewhere") end
    local tag = newUnitTag()
    if tag == nil then return setStatus("No free unit id") end
    for _, o in ipairs(sel) do
        stripOurTags(o)                             -- never in two of OUR units
        o.addTag(tag)
    end
    if not sel[1].hasTag(tag) then
        return setStatus("TTS rejected the tag format")
    end
    selTagState = nil                               -- let the watcher re-evaluate
    setStatus("Tagged " .. #sel .. " models")
end

-- Split the selection into units by how the models are actually standing and give
-- each cluster its own fresh id. Clusters another script has tagged are stepped
-- over rather than refused. Same O(n^2) pass as the check, on a button press only.
function aosSmartTag(player)
    actingColor = player.color
    local sel = selectionOf(player.color)
    if #sel == 0 then return setStatus("Select models first") end
    if #sel > SMART_MAX then
        return setStatus("Too many models: " .. #sel .. "/" .. SMART_MAX)
    end
    local descs = {}
    for i = 1, #sel do descs[i] = buildDesc(sel[i]) end
    local comp = clusterByGap(descs, SMART_GAP)
    local keep, kept = {}, 0
    for i = 1, #sel do
        local t = unitTagOf(sel[i])
        if t ~= nil and not isOurTag(t) and not keep[comp[i]] then
            keep[comp[i]], kept = true, kept + 1
        end
    end
    for i = 1, #sel do
        if not keep[comp[i]] then stripOurTags(sel[i]) end  -- not in two of OURS
    end
    local tags, made = {}, 0
    for i = 1, #sel do
        local c = comp[i]
        if not keep[c] then
            if tags[c] == nil then
                tags[c] = newUnitTag()
                if tags[c] == nil then
                    selTagState = nil
                    return setStatus("No free unit id")
                end
                made = made + 1
            end
            sel[i].addTag(tags[c])
        end
    end
    -- Show the grouping, one colour per unit, so a wrong split is obvious.
    local flashed = {}
    for i = 1, #sel do
        sel[i].highlightOn(UNIT_COLORS[((comp[i] - 1) % #UNIT_COLORS) + 1], SMART_HILITE)
        flashed[#flashed + 1] = sel[i].getGUID()
    end
    -- The flash expiring takes any monitor or highlighter glow on the same models
    -- with it. Both paint by difference, so tell them: the monitor first, because
    -- the highlighter steps over whatever the monitor owns.
    Wait.time(function()
        if monActive then monGlowState = {}; drawMonitor() end
        if hlGlowsLost ~= nil then hlGlowsLost(flashed) end
    end, SMART_HILITE + 0.2)
    selTagState = nil
    local msg = "Smart tag: " .. made .. " units"
    if kept > 0 then msg = msg .. ", " .. kept .. " left alone" end
    setStatus(msg)
end

-- Untags the whole unit, not just the models the player happened to click. Only our
-- own ids come off; a unit another script tagged is reported and left alone.
function aosUntag(player)
    actingColor = player.color
    local sel = selectionOf(player.color)
    if #sel == 0 then return setStatus("Select models first") end
    local seen, n, units, foreign = {}, 0, 0, 0
    for _, o in ipairs(sel) do
        local t = unitTagOf(o)
        if t ~= nil and not seen[t] then
            seen[t] = true
            if isOurTag(t) then
                units = units + 1
                for _, m in ipairs(objectsWithTag(t)) do
                    if alive(m) then stripOurTags(m); n = n + 1 end
                end
            else
                foreign = foreign + 1               -- another script's id: leave it
            end
        end
    end
    selTagState = nil
    if n == 0 then
        if foreign > 0 then return setStatus("Not our tag, left alone") end
        return setStatus("Nothing tagged")
    end
    setStatus("Untagged " .. units .. " units")
end

function aosMode(player, value, id)
    actingColor = player.color
    for i = 1, #MODES do if MODES[i].id == id then uiMode = i end end
    refreshUI()
    if monActive then drawMonitor() end             -- same gaps, new threshold
end

function aosBuddy(player, value, id)
    actingColor = player.color
    for i = 1, #BUDDY_IDS do if BUDDY_IDS[i] == id then buddyOverride = i - 1 end end
    refreshUI()
    if monActive then drawMonitor() end
end

function aosCheck(player)
    actingColor = player.color
    if monActive then
        stopMonitor("Coherency off")
        return refreshUI()
    end
    local objs, tag, err = resolveUnit(player.color)
    if err ~= nil then return setStatus(err) end
    if #objs < 2 then return setStatus("Need 2+ models") end
    if #objs > MAX_UNIT then
        return setStatus("Unit too big: " .. #objs .. "/" .. MAX_UNIT)
    end
    stopMonitor()                                   -- only one monitor per tool
    monActive, monTag, monGuids = true, tag, {}
    for _, o in ipairs(objs) do monGuids[#monGuids + 1] = o.getGUID() end
    fullRecompute()
    local r = drawMonitor()
    -- A split unit passes the rule as written but is treated as illegal at most
    -- events, so it is the one thing worth saying. The glows say the rest.
    local msg = "Measuring coherency"
    if r ~= nil and r.groups > 1 then msg = msg .. ": unit is in " .. r.groups .. " groups" end
    setStatus(msg)
    monTimeout = Wait.time(function()
        stopMonitor("Coherency timed out")
        refreshUI()
    end, MONITOR_TIMEOUT)
    -- Only start polling if something is actually in motion right now.
    for _, o in ipairs(objs) do
        if o.held_by_color ~= nil or o.resting == false then startMotionLoop(); break end
    end
    refreshUI()
end

function aosHighlight(player)
    actingColor = player.color
    if hlActive then
        hlStop()
        refreshUI()
        return setStatus("Highlight off")
    end
    hlStart()
    refreshUI()
    setStatus(seatColor ~= nil and ("Highlight on (" .. seatColor .. ")")
                                or "Highlight on")
end

local function auraOnSelection(playerColor, r)
    local sel = selectionOf(playerColor)
    if #sel == 0 then return setStatus("Select models first") end
    local on = 0
    for _, o in ipairs(sel) do
        if setAura(o, r) then on = on + 1 end
    end
    -- setAura toggles, so say which way it went.
    if on > 0 then setStatus("Aura " .. r .. [["]])
    else setStatus("Aura " .. r .. [[" cleared]]) end
end

function aosAura(player, value, id)
    actingColor = player.color
    auraOnSelection(player.color, tonumber(string.sub(id, 5)))
end

-- Fires per keystroke, so it stays silent; applying does the validating.
function aosCustomChanged(player, value)
    lastCustom = value
end

-- The field's Decimal validation accepts a comma as the decimal separator, which
-- half the table types. tonumber only knows the period, so swap before parsing.
local function customRadius()
    if type(lastCustom) ~= "string" then return tonumber(lastCustom) end
    return tonumber((string.gsub(lastCustom, ",", ".")))
end

-- Enter and Apply are one action that can arrive as two events in the same frame:
-- pressing Apply while the field has focus fires onEndEdit as the field lets go,
-- then the button's own click. Doing the work twice is harmless -- this path SETS
-- the ring -- but saying so twice is noise, hence the one-frame guard. An empty
-- selection is silent, so clicking off the field never nags.
local applyBusy = false
local function applyCustom(playerColor)
    if applyBusy then return end
    applyBusy = true
    Wait.frames(function() applyBusy = false end, 1)
    local r = customRadius()
    if r == nil or r < 0.5 or r > 60 then
        return setStatus("Radius must be 0.5-60")
    end
    local sel = selectionOf(playerColor)
    if #sel == 0 then return end
    for _, o in ipairs(sel) do forceAura(o, r) end
    setStatus("Aura " .. r .. [["]])
end

-- Bound to onEndEdit, which fires on Enter AND on clicking away.
function aosApplyCustom(player, value)
    actingColor = player.color
    if value ~= nil and value ~= "" then lastCustom = value end
    applyCustom(player.color)
end

-- A Button's second argument is its own value, never the field's text, so this goes
-- on what the keystrokes left in lastCustom -- the string the field is showing.
function aosApply(player)
    actingColor = player.color
    applyCustom(player.color)
end

function aosClearSel(player)
    actingColor = player.color
    local sel = selectionOf(player.color)
    if #sel == 0 then return setStatus("Select models first") end
    for _, o in ipairs(sel) do clearAuras(o) end
    setStatus("Auras cleared")
end

function aosClearAll(player)
    if player ~= nil then actingColor = player.color end
    local n = 0
    for _, o in ipairs(getAllObjects()) do          -- button press only, never a timer
        local t = o.getTable("aos_auras")
        if t ~= nil and #t > 0 then clearAuras(o); n = n + 1 end
    end
    setStatus(n == 0 and "No auras on the table"
                     or ("Cleared " .. n .. " auras"))
end

function aosShape(player, value, id)
    actingColor = player.color
    local map = { shapeLine = "line", shapeDouble = "double",
                  shapeTri = "triangles", shapeHoney = "honey" }
    doShape(map[id], player.color)
end

function aosUndo(player)
    if player ~= nil then actingColor = player.color end
    if #undoStack == 0 then return setStatus("Nothing to undo") end
    local n = 0
    for _, s in ipairs(undoStack) do
        local o = getObjectFromGUID(s.guid)
        if alive(o) then
            o.setPositionSmooth(s.pos, false, true)
            o.setRotationSmooth(s.rot, false, true)
            n = n + 1
        end
    end
    undoStack = {}
    -- n < #undoStack means models were destroyed between the move and the undo.
    setStatus(n > 0 and "Move undone" or "Nothing left to put back")
    resyncMonitor()
end

-- setCustomAssets replaces the whole list rather than adding to it, so read what is
-- there and put it all back with ours alongside. Writing rebuilds the UI, so the
-- ordinary case -- everything already registered against the right URL -- writes
-- nothing and the panel does not flicker on load.
--   getCustomAssets() hands back TTS's own LIVE list, the same object
--   setCustomAssets() compares against to decide whether anything changed. Editing
--   an entry in place mutates the "before" as well, the compare sees no change and
--   the new URL silently fails to take. So every entry here is built fresh: never
--   write into the table this function was handed.
local function ensureUIAssets()
    local ok, current = pcall(function() return self.UI.getCustomAssets() end)
    if not ok or type(current) ~= "table" then current = {} end
    local assets, dirty = {}, false
    for i = 1, #current do
        local a = current[i]
        if type(a) == "table" and a.name ~= nil and a.url ~= nil then
            assets[#assets + 1] = { name = a.name, url = a.url }
        end
    end
    for _, want in ipairs(UI_ASSETS) do
        local found = false
        for i = 1, #assets do
            if assets[i].name == want.name then
                found = true
                if assets[i].url ~= want.url then
                    assets[i] = { name = want.name, url = want.url }
                    dirty = true
                end
                break
            end
        end
        if not found then
            assets[#assets + 1] = { name = want.name, url = want.url }
            dirty = true
        end
    end
    if dirty then pcall(function() self.UI.setCustomAssets(assets) end) end
end

-- ======================================================= SAVE / LOAD ========
-- uiMode is deliberately NOT saved: the coherency distance always comes back at
-- 0.5", the value nearly every unit uses. Nor is the highlight, which is a live
-- loop. The other two persist -- they are preferences, not readings.
function onSave()
    return JSON.encode({ buddy = buddyOverride, custom = lastCustom })
end

function onLoad(saved)
    local _
    _, VERSION = Updater_stateVersion(saved)   -- the version this copy is on
    ensureUIAssets()
    -- So the copies of this tool can find each other for the overlap rule.
    if not self.hasTag(TOOL_TAG) then self.addTag(TOOL_TAG) end
    findSeat()
    if saved ~= nil and saved ~= "" then
        local ok, d = pcall(JSON.decode, saved)
        if ok and type(d) == "table" then
            -- d.mode, written by versions before this one, is ignored on purpose.
            if type(d.buddy)  == "number" then buddyOverride = d.buddy end
            if type(d.custom) == "string" then lastCustom = d.custom end
        end
    end
    -- Seed from the GUID as well as the clock, so two tools placed in the same
    -- second do not roll the same unit ids.
    local seed, g = 0, self.getGUID()
    for i = 1, #g do seed = seed + string.byte(g, i) * i end
    pcall(function() seed = seed + os.time() end)
    math.randomseed(seed)
    if selWatchTimer ~= nil then Wait.stop(selWatchTimer) end
    selWatchTimer = Wait.time(selWatchTick, SEL_WATCH, -1)
end

-- Everything that paints the panel, run once the panel is actually there. The
-- update block calls this after it applies the layout; setAttribute before
-- that point does nothing and reports nothing.
function onUIReady()
    refreshUI()
    paintAuraButtons()
    self.UI.setAttribute("versionText", "text", "v" .. VERSION)
    selTagState = nil
    selWatchTick()
end

function onDestroy()
    -- Highlighter first: stopMonitor hands released models back to it, and there is
    -- no point re-lighting models a moment before the tool that lit them goes away.
    hlStop()
    stopMonitor()
    if selWatchTimer ~= nil then Wait.stop(selWatchTimer); selWatchTimer = nil end
end

-- ===========================================================================
-- The tool's UI, spliced in from tool.xml. Edit that file, not this copy.
-- ===========================================================================

local TOOL_XML = [[
<!-- TTS-SELFUPDATE:aos-coherency-tool -->
<!-- ── AOS COHERENCY TOOL by Antares77 ───────────────────────────
     AoS Coherency Tool - object UI.

     Laid out WIDE and SHORT, should sit along the edge of a game table:
     four columns - Auras, Coherency, Formation, Tags, narrow credit strip.
     Nothing in the Lua depends on the order - the script addresses the buttons
     by id, so the columns can be shuffled here.

     BORDER. Drawn as geometry, not with an `outline` attribute: root carries the
     border colour and 3 px of padding, and panelField sits inside it with the pale
     stone, so the border is the 3 px of root that panelField does not cover.
     The buttons keep their `outline`, where at their size it reads as a bevel.
     Geometry to reduce flickering.

     BACKGROUND. bgImage is the source picture at the full width of panelField,
     docked to the top edge and running off the bottom; the Mask trims it at the
     field edge.

     ASSETS. `image="aosPanelBg"` is a NAME, and it resolves against the object's
     Custom UI Assets list, which the Lua fills in on load.
     The picture can be changed in UI_ASSETS at the top of the script.

     COLOURS. The values baked into mode1 and buddyAuto are the script's own
     defaults (0.5", Auto), so the panel is right on the first frame, before onLoad
     re-applies them; both carry a textColor of their own, because the anthracite
     one from Defaults would be invisible on a dark fill. No `colors` attribute in
     Defaults for the same reason - it would override the background the script
     sets. The five aura buttons carry no colour here: the script fills each
     with its own ring colour on load, and they wear the ordinary wash until then.

     Both three-way rows (distance, buddy rule) set childForceExpandWidth="false"
     and size their buttons by hand, because an equal three-way split of the 350
     column leaves 112 px per button and "Base Contact" wraps at that width.

     VERSION in the Lua, which onUIReady writes into versionText here once the
     panel is live. Nothing sets a version by hand in either file. -->

<Defaults>
  <Text color="#293133" fontSize="20" alignment="MiddleCenter"/>
  <!-- fontStyle Bold across every button: the stock face is thin enough at this
       size to go soft as soon as the camera leaves the panel. -->
  <Button color="#ffffff40" textColor="#293133" fontSize="20" fontStyle="Bold"
          outline="#29313366" outlineSize="2 2"
          tooltipPosition="Above" tooltipOffset="10"
          tooltipBackgroundColor="#0d1013f2" tooltipTextColor="#e8eaed"/>
  <HorizontalLayout spacing="6" childForceExpandWidth="true" preferredHeight="46"/>
  <VerticalLayout spacing="6" childForceExpandHeight="false"/>
  <!-- Same wash, edge and weight as the buttons, so the field reads as one of
       them. The four colours are normal|highlighted|pressed|disabled. -->
  <InputField fontSize="20" fontStyle="Bold" textColor="#293133"
              textAlignment="MiddleCenter"
              colors="#ffffff40|#ffffff73|#ffffff26|#ffffff26"
              outline="#29313366" outlineSize="2 2"
              tooltipPosition="Above" tooltipOffset="10"
              tooltipBackgroundColor="#0d1013f2" tooltipTextColor="#e8eaed"/>
</Defaults>

<Panel id="root" position="665 -95 -500" rotation="0 0 0"
       scale="1 1 1" width="1330" height="220"
       color="#293133" padding="3 3 3 3">

  <!-- The panel proper. root is the border it sits in; see BORDER above. -->
  <Panel id="panelField" color="#e6e5e1">

    <!-- Background first, so everything below draws on top of it. -->
    <Mask id="bgMask">
      <Image id="bgImage" image="aosPanelBg" raycastTarget="false"
             rectAlignment="UpperCenter" width="1324" height="1829"/>
    </Mask>

    <HorizontalLayout padding="9 9 9 9" spacing="14" childForceExpandWidth="false">

      <VerticalLayout preferredWidth="384">
        <Text preferredHeight="38" fontSize="24" fontStyle="Bold"
              alignment="UpperCenter">AURAS (Selected Models)</Text>
        <HorizontalLayout>
          <Button id="aura3"  onClick="aosAura" text="3&quot;"
                  tooltip="Ring 3&quot; on each selected model. Press it again to clear."/>
          <Button id="aura6"  onClick="aosAura" text="6&quot;"
                  tooltip="Ring 6&quot; on each selected model. Press it again to clear."/>
          <Button id="aura9"  onClick="aosAura" text="9&quot;"
                  tooltip="Ring 9&quot; on each selected model. Press it again to clear."/>
          <Button id="aura12" onClick="aosAura" text="12&quot;"
                  tooltip="Ring 12&quot; on each selected model. Press it again to clear."/>
          <Button id="aura18" onClick="aosAura" text="18&quot;"
                  tooltip="Ring 18&quot; on each selected model. Press it again to clear."/>
        </HorizontalLayout>
        <!-- The field is one aura button wide, so it sits under the 3" button.
             Extra gap is needed to make the row with the custom input work out in width. -->
        <HorizontalLayout childForceExpandWidth="false" spacing="6">
          <InputField id="customAura" preferredWidth="72" text="4"
                      onValueChanged="aosCustomChanged" onEndEdit="aosApplyCustom"
                      placeholder="0.5-60" characterLimit="5"
                      characterValidation="Decimal"
                      tooltip="Custom aura radius in inches, 0.5 to 60."/>
          <Panel id="gapAfterField" preferredWidth="0" color="#00000000"/>
          <Button id="applyBtn" onClick="aosApply" text="Apply" preferredWidth="114"
                  tooltip="Draw the radius in the box on each selected model."/>
          <Button id="hlBtn" onClick="aosHighlight" text="Enable Highlight"
                  preferredWidth="200"
                  tooltip="Toggle: color glow every model in range of an aura. A model two auras reach glows white instead."/>
        </HorizontalLayout>
        <HorizontalLayout>
          <Button id="auraClearSel" onClick="aosClearSel" text="Clear (Selected)"
                  tooltip="Clear auras on the selected models."/>
          <Button id="auraClearAll" onClick="aosClearAll" text="Clear (All)"
                  tooltip="Clear all auras on the table."/>
        </HorizontalLayout>
      </VerticalLayout>

      <VerticalLayout preferredWidth="350">
        <Text preferredHeight="38" fontSize="24" fontStyle="Bold"
              alignment="UpperCenter">COHERENCY (Selected Unit)</Text>
        <!-- 80 + 80 + 178 + two 6 px gaps = 350. -->
        <HorizontalLayout childForceExpandWidth="false" spacing="6">
          <Button id="mode1" onClick="aosMode" text="0.5&quot;" preferredWidth="80"
                  color="#293133cc" textColor="#f2f1ec"
                  tooltip="Set coherency / formation ranges at 0.5&quot; between models."/>
          <Button id="mode2" onClick="aosMode" text="2&quot;" preferredWidth="80"
                  tooltip="Set coherency / formation ranges at 2&quot; between models."/>
          <Button id="mode3" onClick="aosMode" text="Base Contact" preferredWidth="178"
                  tooltip="Set coherency / formation ranges to base contact."/>
        </HorizontalLayout>
        <!-- 80 + 129 + 129 + two 6 px gaps = 350. -->
        <HorizontalLayout childForceExpandWidth="false" spacing="6">
          <Button id="buddyAuto" onClick="aosBuddy" text="Auto" preferredWidth="80"
                  color="#293133cc" textColor="#f2f1ec"
                  tooltip="Follow the rules: 2 buddies in range for a unit of 7+ models, otherwise 1."/>
          <Button id="buddy1"    onClick="aosBuddy" text="1 in Range" preferredWidth="129"
                  tooltip="Demand 1 buddy in range whatever the unit size."/>
          <Button id="buddy2"    onClick="aosBuddy" text="2 in Range" preferredWidth="129"
                  tooltip="Demand 2 buddies in range whatever the unit size."/>
        </HorizontalLayout>
        <HorizontalLayout>
          <Button id="checkBtn" onClick="aosCheck" text="Check Coherency"
                  tooltip="Toggle: green = OK, orange line to the nearest buddy. Stops itself after 60s."/>
        </HorizontalLayout>
      </VerticalLayout>

      <VerticalLayout preferredWidth="350">
        <Text preferredHeight="38" fontSize="24" fontStyle="Bold"
              alignment="UpperCenter">FORMATION (Selected Unit)</Text>
        <HorizontalLayout>
          <Button id="shapeLine"   onClick="aosShape" text="Single Line"
                  tooltip="Rearrange the unit into one rank."/>
          <Button id="shapeDouble" onClick="aosShape" text="Double Line"
                  tooltip="Rearrange the unit into two ranks."/>
        </HorizontalLayout>
        <HorizontalLayout>
          <Button id="shapeTri"   onClick="aosShape" text="Dogbone"
                  tooltip="Rearrange the unit into a line with a 3-model triangle at each end."/>
          <Button id="shapeHoney" onClick="aosShape" text="Honeycomb"
                  tooltip="Rearrange the unit into a honeycomb block."/>
        </HorizontalLayout>
        <HorizontalLayout>
          <Button id="undoBtn" onClick="aosUndo" text="Undo Last Move"
                  tooltip="Put the unit back where it stood before the last move."/>
        </HorizontalLayout>
      </VerticalLayout>

      <VerticalLayout preferredWidth="120">
        <Text preferredHeight="38" fontSize="24" fontStyle="Bold"
              alignment="UpperCenter">Tags</Text>
        <Panel id="tagFrame" color="#00000000" padding="3 3 3 3" preferredHeight="46">
          <Button id="tagBtn" onClick="aosTag" text="Tag"
                  tooltip="Stamp a unit id on the selected models. Refused if they already carry another script's id."/>
        </Panel>
        <Button id="untagBtn" onClick="aosUntag" text="Untag"
                interactable="false" textColor="#a3a8aa" preferredHeight="46"
                tooltip="Take the unit id off the whole unit. Only ever removes ids this tool issued."/>
        <Button id="smartTagBtn" onClick="aosSmartTag" text="Smart Tag"
                fontSize="17" preferredHeight="46"
                tooltip="Split the selection into units with tags by how the models are standing together."/>
      </VerticalLayout>

      <!-- Credit then version, reading bottom-to-top: a HorizontalLayout turned a
           quarter-turn counter-clockwise, so its width becomes its height on
           screen. 150 + 6 + 38 = 194, inside the 196 the strip has to give - the
           panel's 220 less 3 px of border top and bottom and the 9 + 9 padding.
           140 + 6 + 50 = 196 now: 38 px clipped "v1.2.0" a character short,
           and 50 leaves room for the version to grow a digit or two.
           versionText's own text is only what shows until onUIReady writes the
           real version into it, so it is left blank. -->
      <Panel preferredWidth="34" color="#00000000">
        <HorizontalLayout width="196" height="30" rotation="0 0 90" spacing="6"
                          padding="0 0 0 0" childForceExpandWidth="false"
                          childAlignment="MiddleCenter">
          <Text preferredWidth="140" fontSize="15">Made by Antares77</Text>
          <Text id="versionText" preferredWidth="50" fontSize="14" fontStyle="Bold"></Text>
        </HorizontalLayout>
      </Panel>

    </HorizontalLayout>

  </Panel>
</Panel>
]]

-- ===========================================================================
-- Everything below this line is updater/updater.lua, pasted unchanged.
-- ===========================================================================

--[[ =========================================================================
  SELF-UPDATE BLOCK for keeping tools hosted via Github up to date.
  Source: https://github.com/Antaresx101/TTS_tools   (MIT)

  When using any of my tools with this functionality, in TabletopSimulator,
  typing "!update" in the chat as the host will automatically update all such
  tools in the session with the newest version (if it isn´t on it already).

  A tool is one file. Where it has an on-screen UI, that layout travels
  inside the script and goes on when the object loads, so an update is one
  download and one write, and cannot leave half a tool behind.

  Nothing happens until you ask. Loading a mod sends no requests and changes no
  scripts, it is triggered manually always.
========================================================================== ]]

-- CONFIG -- running someone else's tool and want it left exactly where it is:
-- Stop Updates permanently: set SELF_UPDATE to false and nothing below ever runs.
-- Adopting the block: set the three TOOL_ values.
-- Forking the repo: change REPO_BASE, the only string here that names a host.
local SELF_UPDATE    = true                    -- false pins this copy for good
local REPO_BASE      = "https://raw.githubusercontent.com/Antaresx101/TTS_tools/main"
local TOOL_ID        = "aos-coherency-tool"
local TOOL_VERSION   = "1.0.0"                 -- bumped with manifest.json
local TOOL_SIGNATURE = "TTS-SELFUPDATE:aos-coherency-tool"

-- Fixed conventions. MIN_BYTES only has to be large enough to throw out error
-- pages and truncated bodies; any file carrying this block is usually bigger
-- than that. scripts/validate.py enforces it at publish time.
local MIN_BYTES     = 1024
local APPLY_TIMEOUT = 20                       -- seconds to wait for a safe moment
local UI_FRAMES     = 5                        -- frames a layout takes to go live
local SPREAD        = 8                        -- seconds to smear checks across
local CHAT_COMMAND  = "!update"                -- host types it, every copy hears
local LABEL         = "[" .. TOOL_ID .. "] "   -- four tools, four named voices

local function report(msg)   -- host console only; never chat for everyone
  print("[" .. TOOL_ID .. " " .. TOOL_VERSION .. "] " .. msg)
end

local function url(file)     -- ?ts= defeats the ~5 minute raw.github cache
  return REPO_BASE .. "/tools/" .. TOOL_ID .. "/" .. file .. "?ts=" .. os.time()
end

-- Plain X.Y.Z only; a suffix such as "-rc1" is ignored. Each part has to stay
-- under 1000, which holds for every version this repo will ever publish.
local function rank(v)
  local a, b, c = string.match(tostring(v), "^(%d+)%.(%d+)%.(%d+)")
  return (tonumber(a) or 0) * 1000000 + (tonumber(b) or 0) * 1000 + (tonumber(c) or 0)
end

-- Every release newer than this copy, newest first, as the lines that hang
-- under the update message: a copy that sat out three releases sees all
-- three on update, thats why the manifest carries a history. Notes are one string
-- or a list of them; anything else renders as nothing.
local function whatsNew(m)
  local out = ""
  local function add(r)
    if type(r) ~= "table" or rank(r.version) <= rank(TOOL_VERSION) then return end
    local notes = type(r.notes) == "string" and { r.notes } or r.notes
    if type(notes) ~= "table" then return end
    for _, n in ipairs(notes) do out = out .. "\n  - " .. tostring(n) end
  end
  add(m.stable)
  for _, r in ipairs(type(m.history) == "table" and m.history or {}) do add(r) end
  return out
end

-- One message per tool: three dice rollers on a table are three scripts that
-- cannot see each other, so the first to speak leaves what it said here and
-- the rest read it and keep quiet. Two strings named after this tool are all
-- the block does with Global: one for an install, one for whichever answer.
local GLOBAL_KEY = "SELFUPDATE_" .. string.gsub(TOOL_ID, "%W", "_")
local function once(suffix, value, msg)
  local key = GLOBAL_KEY .. suffix
  local ok, said = pcall(function() return Global.getVar(key) end)
  if ok and said == value then return end
  pcall(function() Global.setVar(key, value) end)
  broadcastToAll(msg, {0.6, 0.9, 0.6})
end

-- Writes the new script and reloads only while the object is idle. If it never
-- goes idle we still write, and the new script starts on the next load. The
-- tool's UI rides inside the script, so there is nothing else here to write.
local function apply(code, version, notes)
  local function idle()
    return self.held_by_color == nil and not self.isSmoothMoving()
       and not self.spawning
  end
  local function commit(withReload)
    -- Carry the tool's own saved state across the reload, if it keeps any.
    pcall(function()
      if type(onSave) == "function" then self.script_state = onSave() end
    end)
    self.setLuaScript(code)              -- WRITE: the only script write, on self
    once("", version, LABEL .. "updated to v" .. version .. notes)
    if withReload then
      self.reload()                  -- self is invalid after this line
    else
      report("v" .. version .. " written; it starts on the next load")
    end
  end
  Wait.condition(function() commit(true) end, idle, APPLY_TIMEOUT,
                 function() commit(false) end)
end

-- The loop guard: writing back what is already running would reload forever.
-- One file is the whole tool now, so one comparison covers it.
local function install(code, version, notes)
  if code == self.getLuaScript() then
    return report("already running this code")
  end
  apply(code, version, notes)
end

local function onPayload(req, version, notes)
  if req.is_error or req.response_code ~= 200 then return end   -- silently
  local code = req.text or ""
  -- Three of the four gates: long enough, signed for this tool, and whole.
  -- The loop guard is the fourth. Any failure leaves the object as it is.
  if #code < MIN_BYTES then return report("rejected: shorter than MIN_BYTES") end
  if not string.find(code, TOOL_SIGNATURE, 1, true) then
    return report("rejected: TOOL_SIGNATURE missing")
  end
  -- The block's last function, named in halves so this line cannot match
  -- itself: the payload carries this file too, and a search for the whole
  -- literal would find the search. Finding the real one proves the body
  -- arrived to its last line rather than stopping somewhere in the middle.
  if not string.find(code, "function Updater_" .. "stateVersion", 1, true) then
    return report("rejected: cut short before the end of the block")
  end
  install(code, version, notes)
end

-- Answers: the repository is not there (offline, blocked, moved, private, 404),
-- or nothing needs fetching because this copy is the published one.
-- Once per tool per asking, either way. A manifest that arrives but will not
-- parse goes to the host console instead: the repository is alive so it´s on that author.
local function onManifest(req)
  if req.is_error or req.response_code ~= 200 then
    return once("_ANSWER", "offline", LABEL .. "could not reach its repository ("
                .. tostring(req.error or req.response_code) .. ")")
  end
  local ok, m = pcall(JSON.decode, req.text)
  if not ok or type(m) ~= "table" or type(m.stable) ~= "table" then
    return report("manifest unreadable")
  end
  local version = tostring(m.stable.version)
  if rank(version) <= rank(TOOL_VERSION) then            -- nothing to fetch
    return once("_ANSWER", "current", LABEL .. "up to date at v" .. TOOL_VERSION)
  end
  local notes = whatsNew(m)
  WebRequest.get(url("tool.lua"), function(r) onPayload(r, version, notes) end)
end

-- Seconds to hold this object's request for: over 0, under SPREAD, the same
-- number every session for any one object. Folded by hand because this Lua
-- rejects tonumber(guid, 36), and math.random belongs to the tool above.
local function stagger()
  local guid, n = tostring(self.getGUID() or ""), 0
  for i = 1, #guid do n = (n * 31 + string.byte(guid, i)) % 100003 end
  return (n % (SPREAD * 100 - 1) + 1) / 100
end

-- One check, now. The chat command calls this, and so can the tool above:
-- from its own code, or from Global with obj.call("Updater_check"). The tool
-- needs no call of its own for the command below to work.
function Updater_check()
  if not SELF_UPDATE then return end
  -- A fresh ask, a fresh answer: every copy clears the flag in this frame,
  -- long before the first reply can come back.
  pcall(function() Global.setVar(GLOBAL_KEY .. "_ANSWER", "") end)
  Wait.time(function() WebRequest.get(url("manifest.json"), onManifest) end,
            stagger())
end

-- The tool's UI, spliced in above this block as TOOL_XML by scripts/validate.py
-- and applied here rather than kept on the object. One file, one write: an
-- update cannot land half a tool, because there are no halves. The tool's own
-- onLoad runs first, so whatever it registers - the custom assets a layout
-- names by image="", for one - is in place before the layout that wants them.
-- A tool with no UI declares no TOOL_XML and this does nothing at all.
local toolLoad = onLoad
function onLoad(saved)
  if type(toolLoad) == "function" then toolLoad(saved) end
  if not TOOL_XML then return end
  self.UI.setXml(TOOL_XML)                        -- WRITE: the only UI write
  -- setXml is queued, and the elements it creates are not addressable in this
  -- frame or the next: setValue and setAttribute on them do nothing, and say
  -- nothing. A tool that fills its layout in at load does that from onUIReady
  -- and never has to guess a delay of its own - this is the only place that
  -- number lives, so getting it wrong is one edit rather than one per tool.
  if type(onUIReady) == "function" then Wait.frames(onUIReady, UI_FRAMES) end
end

-- Chat reaches object scripts, not just the Global one, so every copy on the
-- table hears the host's command for itself and checks itself: no object ever
-- speaks to another, and nothing has to be added to the Global script. The
-- only thing read out of chat is whether the line is exactly CHAT_COMMAND from
-- someone with admin. Whatever onChat the tool above defined is captured here
-- and still called with everything, so this cannot eat a tool's own commands.
local toolChat = onChat
function onChat(message, player)
  if SELF_UPDATE and message == CHAT_COMMAND and player and player.admin then
    Updater_check()
  end
  if type(toolChat) == "function" then return toolChat(message, player) end
end

-- Optional migration hook. Returns the version that wrote the saved state and
-- the version running now; do any migrating in the tool above, not here.
function Updater_stateVersion(saved)
  local ok, t = pcall(JSON.decode, saved or "")
  local v = (ok and type(t) == "table") and t.version or nil
  return v, TOOL_VERSION
end
