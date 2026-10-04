-- TTS-SELFUPDATE:mundane-controller
--
-- ==============================================================
--  MUNDANE CONTROLLER (N26) by Antares77
--
--  The table's game: before it, the setup (the scenario, objective and
--  crews rolled, Attacker and Defender, then "Start Game"); the turn -- a
--  click on it readies every fighter for the next -- the two players'
--  victory points and gangs, and each gang's Bottle Check, due once one
--  of its fighters has gone Out of Action this turn. Every roll the fighter cards make (and
--  its own Roll Dice / Roll Firepower / Roll Injuries buttons) falls in a
--  line under its panel (see DICE).
--
--  The fighter cards find it by its tag (CONTROLLER_TAG): they have it
--  throw their dice (throwDice), tell it when a fighter goes Out of
--  Action (onFighterOut) and ask it for the table's own rules (getRules:
--  see RULES) -- the homebrew rules chosen on the panel's Homebrew Rules
--  page (see HOMEBREW) are those rules. Cards older than the Mundane
--  Importer's are brought up to date by the importer, when there is one on
--  the table, before this calls on every fighter.
-- ==============================================================

local CONTROLLER_NAME = "Mundane Controller"
local VERSION         = "?"   -- the running version, handed over by the updater block

--@@SHARED_BEGIN
-- ══════════════════════════════════════════════════════════════
--  Shared: the same in the Mundane Importer and the Mundane
--  Controller (copied in whole from Mundane_Shared.lua, where it is kept)
-- ══════════════════════════════════════════════════════════════

-- What concerns no gang in particular (turns, conditions cleared on the
-- table, a gang yet to be named) starts with this in chat -- as the
-- cards' lines do (their CFG.infoPrefix is the same [Info]). A line about
-- one gang starts with its name, "[Goliaths] ".
local CHAT_PREFIX = "[Info] "

-- Tag added to every model that receives a card, so other scripts can find them.
local IMPORT_TAG = "Mundane Import"

-- The Mundane Importer's own tag, put on it when it loads: the Controller
-- asks it to bring older cards up to date (its upgradeCards) before it
-- calls on every fighter.
local IMPORTER_TAG = "Mundane Importer"

-- The Mundane Controller's own tag, put on it when it loads: a fighter's
-- card has whatever carries it throw its dice (throwDice) and tells it
-- when the fighter goes Out of Action (onFighterOut). The card's
-- CFG.controllerTag is the same.
local CONTROLLER_TAG = "Mundane Controller"

-- The tag naming the gang a model was last imported for (the gang's name
-- from the roster export follows), so the models of one gang can be found
-- together -- the importer's "Apply UI to the whole Gang" / "Reset UI for
-- the whole Gang" work on them, the Controller's Bottle Check counts them.
-- No " - " in it: TTS won't take one in a tag typed by hand, and players
-- can put a model in a gang themselves ("Mundane Gang_Goliaths").
-- The card has the same (CFG.gangTag).
local GANG_TAG = "Mundane Gang_"
-- earlier versions' tags: removed on import. The first two were gang tags
-- and still count as one until then (see gangOf; the card's
-- CFG.oldGangTags).
local OLD_TAGS = { "Mundane Gang - ", "Mundane Controller_", "Mundane Gang: ", "Mundane Owner: " }

local function trim(s)
    s = (s or ""):gsub("^%s+", "")
    return (s:gsub("%s+$", ""))
end

-- A model's gang tag, if it has one -- or its gang tag from before GANG_TAG
-- (OLD_TAGS[1] / [2]), until it is imported again.
local function gangOf(obj)
    local ok, tags = pcall(function() return obj.getTags() end)
    for _, pre in ipairs({ GANG_TAG, OLD_TAGS[1], OLD_TAGS[2] }) do
        for _, t in ipairs(ok and tags or {}) do
            if t:sub(1, #pre) == pre and #t > #pre then return t end
        end
    end
end

-- obj.call(fn, arg), protected, only if `obj`'s script has the global
-- function `fn` (its text is looked at first): a call to a function a
-- script lacks -- a model with no card yet, a card older than the function
-- -- makes TTS log "Lua Error <fn>: Object reference not set to an
-- instance of an object", which no pcall hides. Something that can't hand
-- over its script is called anyway. Whether it ran, and what it returned.
--   Looking means copying the whole script out of TTS -- a fighter card's
-- is most of a megabyte, and a new turn asks every one. So a script that
-- carries MUNDA_STAMP (a mark it sets anew each time it loads: the cards,
-- this script) is read once: every function it has is noted (KNOWN, by
-- GUID) and holds for as long as its mark stays the same -- a reload, a
-- card brought up to date, gives it a new one.
MUNDA_STAMP = table.concat({ os.time(), os.clock(), math.random(1, 999999999) }, "-")
local KNOWN = {}
local function callIfHas(obj, fn, arg)
    local okG, guid = pcall(function() return obj.getGUID() end)
    guid = okG and type(guid) == "string" and guid or nil
    local known, has = guid and KNOWN[guid], nil
    if known then
        local ok, stamp = pcall(function() return obj.getVar("MUNDA_STAMP") end)
        if ok and stamp ~= nil and stamp == known.stamp then has = known.fns[fn] == true else KNOWN[guid] = nil end
    end
    if has == nil then
        local ok, script = pcall(function() return obj.getLuaScript() end)
        has = not (ok and type(script) == "string") or script:find("function " .. fn .. "(", 1, true) ~= nil
        if ok and type(script) == "string" and guid and script:find("MUNDA_STAMP", 1, true) then
            local okV, stamp = pcall(function() return obj.getVar("MUNDA_STAMP") end)
            if okV and stamp ~= nil then
                local fns = {}
                for name in script:gmatch("function ([%w_]+)%(") do fns[name] = true end
                KNOWN[guid] = { stamp = stamp, fns = fns }
            end
        end
    end
    if not has then return false end
    return pcall(function() return obj.call(fn, arg) end)
end

-- ── The panel's look ─────────────────────────────────────────────

-- How finely the panel's text is drawn: the panel is built this many times
-- its size and shown scaled back down, so every glyph has that many times
-- the texels -- sharper up close (1 = built at its own size).
local PANEL_DETAIL = 2

-- The parchment picture behind the panel (the AoS Coherency Tool's, by
-- Antares77), hosted on the Steam Cloud.
local PANEL_BG = "https://steamusercontent-a.akamaihd.net/ugc/12352082712112839381/58ABA6CE8570F5CB9E72C7E53BE4BE3A2CD8C9F7/"
local BG_RATIO = 1847 / 1337           -- the parchment picture's height / width

-- The panel's look (after the AoS Coherency Tool by Antares77): an
-- anthracite border round a parchment field with its
-- picture, anthracite type, and buttons that are a white wash over the
-- picture with a soft bevel. A lit button -- Import, Apply, the chosen
-- background, the Controller's bars and plates -- is anthracite with a
-- pale label.
local INK, PALE, PAPER = "#293133", "#F2F1EC", "#E6E5E1"
local WASH  = "#FFFFFF40|#FFFFFF73|#FFFFFF26|#FFFFFF26"
local LIT   = "#293133E6|#3A4447E6|#1C2224E6|#29313366"
local RED   = "#7A2020D9|#963030D9|#5A1515D9|#7A202066"
local BEVEL = ' outline="#29313366" outlineSize="2 2"'
local function colors(c) return string.format("%s|%s|%s|%s", c, c, c, c) end

local function xmlEsc(s)
    return (tostring(s or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

-- A text or button label changed in place: TTS takes a button's label as
-- its "text" attribute, a text's as its value -- both are set.
local function setLabel(id, text)
    self.UI.setAttribute(id, "text", text)
    self.UI.setValue(id, text)
end

-- ── Where a panel lies on its object ─────────────────────────────

-- A point `x`, `y` panel units from the middle of a panel (position /
-- rotation / scale like PANEL; the panel's own axes: x to the right, y up
-- as it reads), in its object's own space: local x and z. An object's UI
-- x / y lie along its local x / z, 100 UI units to a local unit; a panel
-- turned half round ("0 0 180") reads the right way up from the object's
-- +z side.
local function panelLocal(panel, x, y)
    local function nums(str)
        local t = {}
        for v in tostring(str):gmatch("%-?[%d%.]+") do t[#t + 1] = tonumber(v) end
        return t
    end
    local pos, rot, sc = nums(panel.position), nums(panel.rotation), nums(panel.scale)
    local px, py = x * (sc[1] or 1), y * (sc[2] or 1)
    local a = math.rad(rot[3] or 0)
    local ux = (pos[1] or 0) + px * math.cos(a) - py * math.sin(a)
    local uy = (pos[2] or 0) + px * math.sin(a) + py * math.cos(a)
    return ux / 100, uy / 100
end

-- ── Feedback ─────────────────────────────────────────────────────

-- The header's Feedback button (top right) and the tablet it puts up: a
-- TTS Tablet showing the feedback form (FEEDBACK.URL), locked, lying past
-- the panel's top edge and tilted towards the players so it is easy to
-- read. The importer and the Controller share it: one form, one tablet --
-- either one's button takes it away again, or moves it to its own panel.
-- Both buttons are lit (anthracite, pale label) while the tablet is there.
local FEEDBACK = {
    MARK = "✉︎", TEXT = "Feedback",   -- the envelope its own text: with the word it leaves a wide gap
    W = 124, H = 30, MARK_W = 22,           -- the button, and the envelope's room in it (panel units)
    URL   = "https://docs.google.com/forms/d/e/1FAIpQLSdOTHX_jjUigf9HpH9mRPav5yBvyKPLSV9g1Q09N9dnUHUU7g/viewform?usp=publish-editor",
    NAME  = "Mundane Feedback",             -- the tablet's name
    TAG   = "Mundane Feedback",             -- the tablet's tag
    -- the tags of the tablets older scripts put up, one each: found and
    -- taken away like the shared one
    OLD   = { "Mundane Feedback_Mundane Importer", "Mundane Feedback_Mundane Controller" },
    -- where the tablet lies (see FEEDBACK.spot): from the point across this
    -- object's middle from the panel's top edge, PAST world units on along
    -- the panel's down direction (negative: back towards the panel's up)
    PAST  = -4.5,
    LIFT  = 2,      -- and this high above this object
    TILT  = 30,     -- leaned back this far (degrees)
    TURN  = 0,      -- turned this much more about the vertical, from the panel's down direction
}

-- Every feedback tablet on the table (the shared one, and any an older
-- script put up), as a list -- empty also outside TTS.
function FEEDBACK.tablets()
    local out = {}
    local tags = { FEEDBACK.TAG }
    for _, tag in ipairs(FEEDBACK.OLD) do tags[#tags + 1] = tag end
    for _, tag in ipairs(tags) do
        local ok, list = pcall(function() return getObjectsWithTag(tag) end)
        for _, o in ipairs(ok and type(list) == "table" and list or {}) do
            local okD, gone = pcall(function() return o.isDestroyed() end)
            if not (okD and gone) then out[#out + 1] = o end
        end
    end
    return out
end

-- The feedback tablet, or nil.
function FEEDBACK.tablet()
    return FEEDBACK.tablets()[1]
end

-- The button: a plain button with the envelope and the word over it, lit
-- while the tablet is up (`on`; FEEDBACK.draw changes it in place).
function FEEDBACK.xml()
    local w, h, m = FEEDBACK.W, FEEDBACK.H, FEEDBACK.MARK_W
    local left = -w / 2 + 8
    local on = FEEDBACK.tablet() ~= nil
    local ink = on and PALE or INK
    return string.format([[
        <Panel id="feedbackBox" rectAlignment="MiddleRight" width="%d" height="%d" color="#00000000">
          <Button id="feedbackBtn" width="%d" height="%d" colors="%s" onClick="onFeedback"></Button>
          <Text id="feedbackMark" offsetXY="%g 0" width="%d" height="%d" fontSize="16" fontStyle="Bold"
                color="%s" raycastTarget="false">%s</Text>
          <Text id="feedbackText" offsetXY="%g 0" width="%d" height="%d" fontSize="16" fontStyle="Bold"
                color="%s" alignment="MiddleLeft" raycastTarget="false">%s</Text>
        </Panel>]], w, h, w, h, on and LIT or WASH, left + m / 2, m, h, ink, FEEDBACK.MARK,
        left + m + 4 + (w - 8 - m - 4 - 8) / 2, w - 8 - m - 4 - 8, h, ink, FEEDBACK.TEXT)
end

-- The button lit (`on`: the tablet is up) or not, in place.
function FEEDBACK.draw(on)
    pcall(function()
        self.UI.setAttribute("feedbackBtn", "colors", on and LIT or WASH)
        self.UI.setAttribute("feedbackMark", "color", on and PALE or INK)
        self.UI.setAttribute("feedbackText", "color", on and PALE or INK)
    end)
end

-- Asked by the other script when it puts the tablet up or takes it away,
-- so both buttons agree.
function feedbackLit(on)
    FEEDBACK.draw(on == true)
end

-- This button and every other importer's and Controller's lit or not.
function FEEDBACK.drawAll(on)
    FEEDBACK.draw(on)
    for _, tag in ipairs({ IMPORTER_TAG, CONTROLLER_TAG }) do
        local ok, list = pcall(function() return getObjectsWithTag(tag) end)
        for _, o in ipairs(ok and type(list) == "table" and list or {}) do
            if o ~= self then callIfHas(o, "feedbackLit", on) end
        end
    end
end

-- Where the tablet goes for a panel (position / rotation / scale like
-- PANEL) `h` tall: its centre and rotation in the world -- nil outside TTS.
-- It is reckoned from the point across this object's middle from the
-- panel's top edge, along the panel's down direction (PAST, TURN).
function FEEDBACK.spot(panel, h)
    local x, z = panelLocal(panel, 0, h / 2)              -- the panel's top edge
    local ux, uz = panelLocal(panel, 0, h / 2 + 100)      -- and on up the panel
    local ok, a, b = pcall(function()                     -- both across the middle
        return self.positionToWorld({ -x, 0, -z }), self.positionToWorld({ -ux, 0, -uz })
    end)
    if not (ok and a and b) then return nil end
    local ax, ay, az = a.x or a[1], a.y or a[2], a.z or a[3]
    local dx, dz = (b.x or b[1]) - ax, (b.z or b[3]) - az
    local len = math.sqrt(dx * dx + dz * dz)
    if len < 1e-6 then dx, dz, len = 0, 1, 1 end
    dx, dz = dx / len, dz / len
    return { ax + dx * FEEDBACK.PAST, ay + FEEDBACK.LIFT, az + dz * FEEDBACK.PAST },
           { FEEDBACK.TILT, math.deg((math.atan2 or math.atan)(dx, dz)) + FEEDBACK.TURN, 0 }
end

-- The tablet shows `url` -- left alone if it does already.
function FEEDBACK.show(tab, url)
    local ok, cur = pcall(function() return tab.Browser.url end)
    if not (ok and cur) then ok, cur = pcall(function() return tab.getValue() end) end
    if ok and cur == url then return end
    if not pcall(function() tab.Browser.url = url end) then pcall(function() tab.setValue(url) end) end
end

-- The button pressed: the tablet put up over a panel (PANEL) `h` tall --
-- or, when it is up already (put up by either script), taken away. A press
-- while the tablet is still spawning does nothing.
function FEEDBACK.open(panel, h)
    if FEEDBACK.spawning then return end
    local up = FEEDBACK.tablets()
    if #up > 0 then
        for _, o in ipairs(up) do pcall(function() o.destruct() end) end
        return FEEDBACK.drawAll(false)
    end
    local at, rot = FEEDBACK.spot(panel, h)
    if not at then return end
    local name, tag, url = FEEDBACK.NAME, FEEDBACK.TAG, FEEDBACK.URL
    FEEDBACK.spawning = true
    local ok = pcall(function()
        spawnObject({ type = "Tablet", position = at, rotation = rot, sound = false,
            callback_function = function(o)
                FEEDBACK.spawning = nil
                o.setLock(true)
                o.setName(name)
                o.addTag(tag)
                o.setPosition(at)
                o.setRotation(rot)
                FEEDBACK.show(o, url)
            end })
    end)
    if not ok then FEEDBACK.spawning = nil; return end
    pcall(function() Wait.time(function() FEEDBACK.spawning = nil end, 5) end)   -- a spawn that never came back
    FEEDBACK.drawAll(true)
end

-- The whole panel round its content: the defaults, an anthracite border
-- (3) round the parchment field with its picture, and in it a column
-- (padding 9, rows 6 apart) of the header (40 tall: version and credit on
-- the left, the title in the middle) and then `t.body`, its rows; `t.over`
-- goes over the whole field. t = { id, position, rotation, scale, width,
-- height, title, version, body, over }.
local function panelShell(t)
    return string.format([[
<Defaults>
  <Text color="%s" fontSize="16" alignment="MiddleCenter"/>
  <Button colors="%s" textColor="%s" fontSize="16" fontStyle="Bold" outline="#29313366" outlineSize="2 2"/>
  <InputField fontStyle="Bold" textColor="%s" colors="#FFFFFF40|#FFFFFF73|#FFFFFF26|#FFFFFF26"
              outline="#29313366" outlineSize="2 2"/>
</Defaults>
<Panel id="%s" position="%s" rotation="%s" scale="%s" width="%d" height="%d"
       color="%s" padding="3 3 3 3">
  <Panel id="panelField" color="%s">
    <Mask id="bgMask">
      <Image id="bgImage" image="mundanePanelBg" raycastTarget="false"
             rectAlignment="UpperCenter" width="%d" height="%d"/>
    </Mask>
    <VerticalLayout padding="9 9 9 9" spacing="6" childForceExpandHeight="false">
      <Panel id="headerPanel" preferredHeight="40" color="#00000000">
        <Text id="titleText" width="%d" height="40" fontSize="22" fontStyle="Bold">%s</Text>
        <Text id="versionText" rectAlignment="UpperLeft" offsetXY="0 -2" width="120" height="20" fontSize="15"
              fontStyle="Bold" alignment="MiddleLeft">v%s</Text>
        <Text rectAlignment="UpperLeft" offsetXY="0 -22" width="140" height="16" fontSize="11"
              alignment="MiddleLeft">Made by Antares77</Text>
%s
      </Panel>
%s
    </VerticalLayout>
%s
  </Panel>
</Panel>]], INK, WASH, INK, INK,
        t.id, t.position, t.rotation, t.scale, t.width, t.height, INK, PAPER,
        t.width - 6, math.floor((t.width - 6) * BG_RATIO),
        t.width - 24, xmlEsc(t.title), xmlEsc(t.version), FEEDBACK.xml(), t.body, t.over or "")
end

-- The panel built PANEL_DETAIL times its size (every size in the XML
-- multiplied, font sizes kept whole) and scaled back down by the same, so
-- it covers the same table but its text has that many times the texels.
-- `root`: the id of the panel whose scale takes it back.
local SIZE_ATTRS = { "fontSize", "preferredHeight", "preferredWidth", "spacing", "width", "height",
                     "padding", "outlineSize", "offsetXY" }
local function detailed(xml, root)
    local k = PANEL_DETAIL
    if k == 1 then return xml end
    for _, a in ipairs(SIZE_ATTRS) do
        xml = xml:gsub("(%s" .. a .. '=")([^"]*)(")', function(pre, v, post)
            v = v:gsub("%-?[%d%.]+", function(n)
                n = tonumber(n) * k
                return a == "fontSize" and string.format("%d", math.floor(n + 0.5)) or string.format("%g", n)
            end)
            return pre .. v .. post
        end)
    end
    return (xml:gsub('(<Panel id="' .. root .. '"[^>]-scale=")([^"]*)(")', function(pre, v, post)
        return pre .. v:gsub("[%d%.]+", function(n) return string.format("%g", tonumber(n) / k) end) .. post
    end))
end
--@@SHARED_END

--@@RULES_BEGIN
-- ══════════════════════════════════════════════════════════════
--  Rules: the same in the fighter card and the Mundane Controller
--  (copied in whole from Mundane_Rules.lua, where it is kept)
-- ══════════════════════════════════════════════════════════════

-- The game's rules as data: every action, condition, skill, piece of
-- wargear and weapon accessory the card knows, the dice's faces, the
-- stats' limits, the weapon traits it reacts to and the ranges it
-- measures. Everything here is the default -- the N26 rules. A table's own
-- rules (homebrew) are kept by the Mundane Controller as overrides and laid
-- over these (see RULES.merge): the card asks the Controller for them when
-- it loads and whenever the Controller says they have changed. One table,
-- RULES; the card knows its parts by their old names too (ACTIONS =
-- RULES.actions, ...).
local RULES = {}

-- The kinds of action, each with its colour in A's panel: a colour of the
-- card's (a COL key) or one of its own ("#RRGGBB").
RULES.actionTypes = {
    movement = "actMovement",   -- Movement
    close    = "actClose",      -- Close Combat
    shooting = "actShooting",   -- Shooting
    utility  = "actUtility",    -- Utility
    wyrd     = "actWyrd",       -- Wyrd
}

-- Every action a fighter can take. `cost` is S (a simple action), D (a
-- double one) or F (a free one, which spends no action but still counts as
-- used), shown in the arrow's diamond
-- (a cost like "S/C" -- C: continuous, only shown -- or "S/D" spends as
-- its first letter, see the card's SKILL.cost); actions have no icons.
-- `type` picks its colour (actionTypes); one with none keeps the plain
-- toggle colour. Clicking one spends it (see the card's useAction) and
-- calls the onActionChosen stub -- what an action does is up to the rules
-- layer, but for four the card knows by their keys: treat_ally,
-- group_activation, coup_de_grace and reload (see useAction) -- and after
-- dash no ranged weapon can be fired, but for one with Assault (see the
-- card's TRAIT_RULES.shot). `distance`: how far the action moves its
-- fighter, a list of { stat, times } added up -- "D6" for a die thrown for
-- it -- shown over the stats and said with the action (see the card's
-- ACTIVATION.moveBy), the bar's title `distanceTitle` or the label with
-- what it adds up ("Dash (M + I)"). Fight and the Shoot actions pay for the
-- weapons' attacks: taken from the panel, they light up the weapons they
-- are for, and the attack after them spends nothing more (see the card's
-- ACTIVATION.attackCost). `desc`, when filled in, shows over the stats
-- while the cursor is on the action.
RULES.actions = {
    { key = "move",             label = "Move",             cost = "S", type = "movement", desc = "",
      distance = { { "M", 1 } }, distanceTitle = "Movement" },
    { key = "dash",             label = "Dash",             cost = "D", type = "movement", desc = "",
      distance = { { "M", 1 }, { "I", 1 } } },
    { key = "engage",           label = "Engage",           cost = "S", type = "close",    desc = "",
      distance = { { "D6", 1 } } },
    { key = "charge",           label = "Charge",           cost = "D", type = "close",    desc = "",
      distance = { { "M", 1 }, { "D6", 1 } } },
    { key = "coup_de_grace",    label = "Coup de Grace",    cost = "S", type = "close",    desc = "" },
    { key = "interact",         label = "Interact",         cost = "S", type = "utility",  desc = "" },
    { key = "shoot",            label = "Shoot",            cost = "S", type = "shooting", desc = "" },
    { key = "braced_shot",      label = "Braced Shot",      cost = "D", type = "shooting", desc = "" },
    { key = "aimed_shot",       label = "Aimed Shot",       cost = "D", type = "shooting", desc = "" },
    { key = "reload",           label = "Reload",           cost = "S", type = "shooting", desc = "" },
    { key = "treat_ally",       label = "Treat Ally",       cost = "S", type = "utility",  desc = "" },
    { key = "group_activation", label = "Group Activation", cost = "S", type = "utility",  desc = "" },
    { key = "fight",            label = "Fight",            cost = "D", type = "close",    desc = "" },
    { key = "retreat",          label = "Retreat",          cost = "D", type = "movement", desc = "" },
    { key = "crawl",            label = "Crawl",            cost = "D", type = "movement", desc = "" },
    { key = "desperate_escape", label = "Desperate Escape", cost = "D", type = "movement", desc = "" },
    { key = "tend_wounds",      label = "Tend Wounds",      cost = "D", type = "utility",  desc = "" },
    -- not an action of the rules: it opens the Recovery Test panel (see
    -- the card's recoveryTest). `always`: never dimmed, spends no action,
    -- never used
    { key = "recovery_test",    label = "Recovery Test",    cost = "RT", type = "utility", always = true, desc = "" },
    -- `wyrd`: not in any status's panel -- a fighter that can use Wyrd
    -- powers (a Wyrd, fighter.category "wyrd", or one with a Wyrd power)
    -- has these on its Special tab while Active, Suppressed or Engaged
    { key = "maintain_control_f", label = "Maintain Control", cost = "F", type = "wyrd", wyrd = true, desc = "" },
    { key = "maintain_control_s", label = "Maintain Control", cost = "S", type = "wyrd", wyrd = true, desc = "" },
    { key = "concentrate",        label = "Concentrate",      cost = "S", type = "wyrd", wyrd = true, desc = "" },
}

-- What A's panel offers in each status, as its two columns: `right` next to
-- A, `left` beyond it, each top to bottom (keys of actions; one that isn't
-- there is left out). A status can leave a column out.
-- (Suppressed is Active without the double actions.)
RULES.statusActions = {
    active = {
        left  = { "move", "dash", "engage", "charge", "coup_de_grace", "interact" },
        right = { "shoot", "braced_shot", "aimed_shot", "reload", "treat_ally", "group_activation" },
    },
    suppressed = {
        left  = { "move", "engage", "coup_de_grace", "interact" },
        right = { "shoot", "reload", "treat_ally", "group_activation" },
    },
    engaged = {
        right = { "fight", "retreat" },
    },
    seriously_injured = {
        right = { "crawl", "desperate_escape", "tend_wounds", "recovery_test" },
    },
}

-- C's panel: conditions, each a named toggle with its icon (the card's
-- ASSETS cond_<key>; `short` stands in until the icon exists). None stack
-- except those marked `stacks`, which count up one per click in the panel
-- and down one per click in the bar under the stats. Hovering one's icon
-- in that bar shows its name and `desc` over the stats; hovering it in
-- C's panel shows them only when `desc` is filled in.
--   mods  = what the condition does to the stats, per stack. The card shows
--           the lowered number (never past RULES.limits) and stat tests use it.
--   set   = stats the condition sets to a number, whatever the changes above
--           make of it ({ WS = 6 }: Feared); shown green / orange for better
--           / worse than it would be.
--   hitOnly = the fighter's attacks of a kind ("melee", "ranged") hit only
--           on this natural roll or more, whatever modifies them
--           ({ melee = 6 }: Blind).
-- What a condition does beyond changing stats is the card's
-- onConditionChanged's.
RULES.conditions = {
    { key = "intoxicated", label = "Intoxicated", short = "ITX", desc = "" },
    { key = "radphage",    label = "Radphage",    short = "RAD", desc = "",
      mods = { T = -1 } },                    -- -1 Toughness while active
    { key = "concussion",  label = "Concussion",  short = "CON", desc = "", stacks = true,
      mods = { I = -1 } },                    -- -1 Initiative per stack (min 1)
    { key = "shackled",    label = "Shackled",    short = "SHK", desc = "" },
    { key = "webbed",      label = "Webbed",      short = "WEB", desc = "" },
    { key = "insanity",    label = "Insanity",    short = "INS", desc = "" },
    -- put on a fighter hit by a Flash weapon (the card's traitHit): its
    -- melee attacks hit only on a natural 6
    { key = "blind",       label = "Blind",       short = "BLD", desc = "",
      set = { WS = 6 }, hitOnly = { melee = 6 } },
    -- put on a fighter by a Fearsome enemy (the card's rollAttack), gone when
    -- its activation is over
    { key = "feared",      label = "Feared",      short = "FEA", desc = "",
      set = { WS = 6 } },                     -- WS 6+ while active
    -- on a Wyrd while a Continuous power is in effect (the card puts it on and
    -- takes it off with the power)
    { key = "maintaining_power", label = "Maintaining Power", short = "PWR", desc = "" },
    -- nothing of its own: a reminder for a custom condition
    { key = "special",     label = "Special",     short = "SPC", desc = "" },
}

-- Skills (fighter.skills: the names as the roster lists them), matched by
-- name in any case. They show by name in a row under the stats, each
-- capitalised word by word (Counter-attack -> Counter-Attack) -- or as
-- `short`, if given. Hovering a name shows the full name and `desc`.
-- `mods` is what the skill does to the stats, as the conditions' (+1 is one
-- higher: { I = 1 }): the card shows the changed number (never past
-- RULES.limits) in green where that is better, orange where worse, and
-- hovering the stat lights the skill's name up in that colour. A skill
-- that is really an action has `action`, its cost (S, D or F, or a
-- combination like "F/C", as in the actions) and `type` (its colour,
-- actionTypes): it also goes into A's panel, under the Special tab. One
-- with `costs` changes what actions cost its fighter ({ <action key> =
-- new cost }, see the card's SKILL.costOf): Inspiring makes Group
-- Activation free. A skill not listed here still shows, with no
-- description. What else a skill can say:
--   weapon     a weapon it arms its fighter with (name and profiles, as a
--              weapon of the roster's: Headbutt) -- a roster that lists a
--              weapon of that name already keeps its own, which then is
--              the skill's all the same: no use while the skills are
--              disabled;
--   meleeS     what it adds to the Strength of the melee profiles with a
--              trait, { <key in traits> = N } (Heavy Blows: +1 with Heavy);
--   secondary  how many attacks the second melee weapon of an activation
--              starts at, instead of one (Two-Weapon Fighter; see the
--              card's TRAIT_RULES.opening);
--   master     true: it always assists a friend and interferes with an
--              enemy in close combat, however many enemies it is fighting
--              itself (Combat Master; see the card's TRAIT_RULES.supportNear).
--   springUp   true: activated while Suppressed, it makes an Agility test
--              and, passing it, keeps both its actions (Spring Up; see the
--              card's activate);
--   catfall    true: a fall counts one level less for it (never less than
--              the lowest), and an Agility test then saves it from being
--              Suppressed by the fall (Catfall; see the card's fallingDown);
--   distance   for a skill that is an action: the inches it moves its
--              fighter, shown and said in chat when it is taken -- a list
--              of { stat, times }, added up (Sprint: M + 2x I), as the
--              actions' own `distance` is;
--   fearsome   true: an enemy that starts a fight against it makes a
--              Willpower check first, and fails into the Feared condition
--              (see the card's rollAttack) -- unless it is Fearsome itself;
--   ironJaw    N: against attacks with no AP (and Light weapons used while
--              engaged), it counts N higher in Toughness (Iron Jaw: 2; see
--              the card's woundPlan);
--   steel      true: hit by a ranged attack, it may make a Cool check to
--              keep from being Suppressed (Nerves Of Steel; see the card's
--              rangedHit);
--   unstoppable  true: activating with a wound lost, it makes a Willpower
--              check at once, and regains a wound when it passes;
--   backstab   true: its melee weapons have the Backstab trait -- one that
--              has it already adds 2 to its Strength, not 1 (Backstab; see
--              the card's TRAIT_RULES.stab);
--   cutThroat  true: its Coup de Grace, when the enemy rolls more, is
--              rolled again, once (Cut-Throat; see the card's
--              ACTIVATION.coup);
--   lieLow     true: while it is Suppressed it can't be the target of a
--              ranged attack -- an enemy about to shoot it is told so, and
--              asked whether to go on (Lie Low; see the card's rollAttack);
--   shoots     N: it may make N Shoot actions in an activation, not one
--              (Fast Shot: 2) -- Shoot only, so never a second shot with a
--              Heavy weapon, which is a Braced Shot;
--   gunfighter true: its Shoot with a Light weapon lets it fire a second
--              weapon with Light as part of that action, for no action of
--              its own (Gunfighter; see the card's TRAIT_RULES.shot);
--   hipShooting  true: its ranged weapons without Heavy have the Assault
--              trait (Hip-Shooting);
--   marksman   N: while it isn't Engaged, its ranged attacks on an enemy
--              beyond the weapon's Short Range but within its Long Range
--              are N better to hit (Marksman: 1; see the card's
--              TRAIT_RULES.marksman);
--   aimed      N: its Aimed Shot is N better to hit, not 1 (Sharpshooter: 2);
--   fastReload true: its Reload reloads every profile that is out of ammo,
--              not one (Fast Reload; see the card's reloadWeapon);
--   ironWill   N: while it is on the table, its gang's Bottle Checks are
--              taken against N more (Iron Will: 1; see the Mundane
--              Controller's Bottle Check);
--   label      for a skill that is an action: what the action is called
--              on the Special tab, when not by the skill's own name
--              (Munitioneer: Distribute Ammo);
--   distribute N: its action hands out ammo -- every fighter of its gang
--              within N inches with a weapon out of ammo makes an
--              Intelligence check at once, and reloads on passing it
--              (Munitioneer: 6; see the card's ACTIVATION.distribute);
--   aka        other names the roster may list it under (a list: another
--              spelling finds the same entry);
--   when       a status's key: its `mods` count only while the fighter is
--              in that status (Mesh Armour: "engaged");
--   once       true, for one that is an action: it can be taken once a
--              game -- dimmed from then on, until the Mundane Controller's
--              Start Game (the Stimm-Slug);
--   boost      for one that is an action: what taking it does to the
--              stats, as `mods`, until the fighter is next activated
--              ({ M = 2, S = 2, T = 2 }: the Stimm-Slug);
--   reaction   what that boost costs as it ends: { roll = N, wounds = W }
--              -- a D6 as the fighter activates, W wounds lost on N or
--              less (see the card's ACTIVATION.comedown);
--   noFall     true: a fall does nothing to it -- no Agility test, no
--              wound, never Suppressed (Grav Chute; see the card's
--              fallingDown);
--   assist     N: a friend's Recovery test it assists is rolled with N
--              more Injury dice on top of the assist's own (Medicae Kit:
--              1; see the card's recoveryTest);
--   inv        N: an invulnerable save of N+ -- never worsened by AP, never
--              bettered by cover or anything else that betters a save; each
--              wound takes whichever of the two saves is better (see the
--              card's takeSaves) (Refractor Shield: 5);
--   burns      true: the first natural 1 on a save taken with its `inv`
--              burns it out for the rest of the battle -- its name turns
--              grey, and a left click on it switches it back on or off
--              (Refractor Shield; the Bio-Booster, which is used up so);
--   bioBooster N: the first time in the battle a wound that goes through
--              brings the fighter to 0 wounds, that wound's Lethality is N
--              less -- down to 0: two Injury dice of their own instead, the
--              better kept -- and the item is used up (`burns`: grey, a
--              left click puts it back; see the card's ACTIVATION.damage)
--              (Bio-Booster: 1);
--   noAp       words a weapon's name may start with (a list, any case):
--              hits from such a weapon have no AP against it (Reflec
--              Shroud: Las, Plasma, Melta);
--   immune     weapon traits (RULES.traits keys) that do nothing to it,
--              and conditions (keys) it never gets (Hazard Suit: Blaze,
--              Radphage);
--   gasInv     N: an invulnerable save of N+ against Gas weapons only
--              (Respirator: 5).
-- What a Wyrd power (`type = "wyrd"`) does once manifested -- nothing
-- before: a power that fails, or is disrupted out of it, does none of it.
-- "While in effect" is for a Continuous power, until it ends (see the
-- card's ACTIVATION.cast); "until the end of the turn", until the fighter
-- is next readied (the Mundane Controller's next turn). Ranges are base to
-- base. Only an Active fighter can be Suppressed.
--   maintained { stat = N }: what it does to its Wyrd's own stats while in
--              effect, as `mods` (Quickening: +3 M, +2 I) -- shown purple;
--   overLimit  true: those may take a stat past its highest (RULES.limits);
--   weapon     (Continuous) the Wyrd is equipped with it only while in
--              effect (Force Blast, Scouring);
--   flaming    a trait one melee weapon of the Wyrd's gains while in
--              effect: its melee weapons light up purple, and the first
--              one clicked is the one (Flaming Weapon: "Blaze (5+)");
--   meleeL     N: its melee profiles' L, that much higher while in effect
--              (Warp Strength: 1);
--   target     what it does to the one enemy the player has selected as
--              it is cast (none selected, or too far: nothing):
--                range   inches (none: any distance);
--                roll    a stat the Wyrd tests first, nothing on a fail
--                        (Assail: "BS");
--                suppress  the enemy is Suppressed;
--                test    the test the enemy makes ("Cl", "Wil", "agility",
--                        "nerve" -- a Nerve Check, Suppressed on a fail);
--                ifReady the test only while the enemy has its Ready
--                        marker; needReady: nothing at all without it;
--                fail    what a failed test does: "unready" (it loses its
--                        Ready marker) or a condition's key ("insanity");
--                hit     a hit of { S, AP, L }: the Wound roll follows;
--                base    stats set to these, before any modifier, while in
--                        effect (Paroxysm: BS and WS 6+);
--                needStatus  only an enemy in this status; out: it goes Out
--                        of Action (Eternal Slumber);
--   area       what it does at once, until the end of the turn, to every
--              fighter of `side` ("friends", "enemies", "all") within
--              `range` -- and the Wyrd itself with `self`: `mods` (as a
--              condition's: Warp Shield, Sv one better) or `oneAction`
--              (one action when activated, Suppressed or not: Freeze Time);
--   aura       what it does while in effect to every fighter of `side`
--              within `range` (none: anywhere) -- as they come and go:
--              `mods`, or `lend` (stats it lends them where its own are
--              better: Unbreakable Will, Wil and Cl);
--   rerollHits true: while in effect, enemies re-roll every ranged hit
--              die that hits, once (Cacophony Of Silence);
--   void       N: while in effect, an enemy within N inches shooting the
--              Wyrd counts it as at Long range, never Short (A Perfect Void);
--   visions    { range, condition }: until the end of the turn, an enemy
--              ending its activation within range gains the condition
--              (Maddening Visions).
-- A fighter's skills do nothing while it is at 0 wounds, Seriously Injured
-- or Out of Action (the card's SKILL.off).
RULES.skills = {
    { name = "Counter-Attack", desc = "" },
    { name = "Inspiring",      desc = "", costs = { group_activation = "F" } },
    { name = "Juggernaut",     desc = "" },
    -- savant
    { name = "Fast Reload",    desc = "", fastReload = true },
    { name = "Iron Will",      desc = "", ironWill = 1 },
    { name = "Medicate",       desc = "", action = "S", type = "utility" },
    { name = "Munitioneer",    desc = "", action = "S", type = "utility",
      label = "Distribute Ammo", distribute = 6 },   -- within 6"
    -- agility
    { name = "Catfall",        desc = "", catfall = true },
    { name = "Spring Up",      desc = "", springUp = true },
    { name = "Sprint",         desc = "", action = "D", type = "movement",
      distance = { { "M", 1 }, { "I", 2 } } },   -- M + 2x I
    -- close combat
    { name = "Berserker",          desc = "", mods = { A = 1 } },   -- +1 Attacks
    { name = "Combat Master",      desc = "", master = true },
    { name = "Headbutt",           desc = "", weapon = { name = "Headbutt", profiles = {
        { SR = "E", LR = "-", S = "S+1", AP = "-", L = "1", traits = "Additional Attack (1), Melee" } } } },
    { name = "Heavy Blows",        desc = "", meleeS = { heavy = 1 } },
    { name = "Two-Weapon Fighter", desc = "", secondary = 2 },
    { name = "Fearsome",           desc = "", fearsome = true },
    { name = "Iron Jaw",           desc = "", ironJaw = 2 },
    { name = "Nerves Of Steel",    desc = "", steel = true },
    { name = "Unstoppable",        desc = "", unstoppable = true },
    -- cunning
    { name = "Backstab",   desc = "", backstab = true },
    { name = "Cut-Throat", desc = "", cutThroat = true },
    { name = "Lie Low",    desc = "", lieLow = true },
    -- shooting
    { name = "Fast Shot",    desc = "", shoots = 2 },
    { name = "Gunfighter",   desc = "", gunfighter = true },
    { name = "Hip-Shooting", desc = "", hipShooting = true },
    { name = "Marksman",     desc = "", marksman = 1 },
    { name = "Sharpshooter", desc = "", aimed = 2 },
    -- Wyrd powers: actions on the Special tab, whatever the status
    -- ("/C": continuous -- it stays in effect, see the card's
    -- ACTIVATION.cast). What one does once manifested (see the card's
    -- ACTIVATION.manifest), as the fields above the list explain; one with
    -- none of them does nothing the card knows of.
    { name = "Force Blast",          desc = "", action = "F/C", type = "wyrd",
      weapon = { name = "Force Blast", profiles = {
        { SR = '8"', LR = '12"', S = "2", AP = "-1", L = "1", traits = "Knockback (3+)" } } } },
    { name = "Flaming Weapon",       desc = "", action = "F/C", type = "wyrd", flaming = "Blaze (5+)" },
    { name = "Freeze Time",          desc = "", action = "D",   type = "wyrd",
      area = { range = 12, side = "all", oneAction = true } },
    { name = "Weapon Jinx",          desc = "", action = "S",   type = "wyrd" },
    { name = "Terrify",              desc = "", action = "D",   type = "wyrd",
      target = { range = 18, suppress = true, test = "Cl", ifReady = true, fail = "unready" } },
    { name = "Quickening",           desc = "", action = "S/C", type = "wyrd",
      maintained = { M = 3, I = 2 }, overLimit = true },
    { name = "Hypnosis",             desc = "", action = "S",   type = "wyrd" },
    { name = "Unbreakable Will",     desc = "", action = "F/C", type = "wyrd",
      aura = { range = 9, side = "friends", lend = { "Wil", "Cl" } } },
    { name = "Zealot",               desc = "", action = "S/C", type = "wyrd" },
    { name = "Mind Control",         desc = "", action = "S",   type = "wyrd" },
    { name = "Assail",               desc = "", action = "S",   type = "wyrd",
      target = { roll = "BS", suppress = true } },
    { name = "Force Wave",           desc = "", action = "S",   type = "wyrd" },
    { name = "Catalyst",             desc = "", action = "F/C", type = "wyrd" },
    { name = "Hypnotic Gaze",        desc = "", action = "D",   type = "wyrd",
      target = { range = 9, needReady = true, test = "agility", fail = "unready" } },
    { name = "The Horror",           desc = "", action = "S",   type = "wyrd",
      target = { range = 12, test = "nerve" } },
    { name = "Leech Essence",        desc = "", action = "S",   type = "wyrd",
      target = { range = 12, hit = { S = 3, AP = -1, L = 1 } } },
    { name = "Paroxysm",             desc = "", action = "S/C", type = "wyrd",
      target = { range = 9, base = { BS = 6, WS = 6 } } },
    { name = "Aura Of Despair",      desc = "", action = "F/C", type = "wyrd",
      aura = { side = "enemies", mods = { Cl = -1 } } },
    { name = "Hallucinations",       desc = "", action = "S",   type = "wyrd",
      target = { range = 12, test = "Wil", fail = "insanity" } },
    { name = "Crush",                desc = "", action = "F",   type = "wyrd" },
    { name = "Force Field",          desc = "", action = "S/C", type = "wyrd" },
    { name = "Terrible Truths",      desc = "", action = "S",   type = "wyrd",
      target = { range = 6, test = "Wil", fail = "insanity" } },
    { name = "Psychotic Lure",       desc = "", action = "S",   type = "wyrd" },
    { name = "Deceitful Thoughts",   desc = "", action = "D",   type = "wyrd",
      target = { range = 6, test = "Wil" } },
    { name = "Cacophony Of Silence", desc = "", action = "S/C", type = "wyrd", rerollHits = true },
    { name = "A Perfect Void",       desc = "", action = "F/C", type = "wyrd", void = 10 },
    { name = "Eternal Slumber",      desc = "", action = "S",   type = "wyrd",
      target = { range = 3, needStatus = "seriously_injured", out = true } },
    { name = "Scouring",             desc = "", action = "F/C", type = "wyrd",
      weapon = { name = "Scouring", profiles = {
        { SR = "T", LR = "-", S = "2", AP = "-", L = "1", traits = "Blaze (5+), Template" } } } },
    { name = "Levitation",           desc = "", action = "F/C", type = "wyrd", maintained = { M = 3 } },
    { name = "Warp Strength",        desc = "", action = "F/C", type = "wyrd", maintained = { S = 2 }, meleeL = 1 },
    { name = "Warp Shield",          desc = "", action = "S",   type = "wyrd",
      area = { range = 3, side = "friends", self = true, mods = { Sv = -1 } } },
    { name = "Maddening Visions",    desc = "", action = "S",   type = "wyrd",
      visions = { range = 3, condition = "insanity" } },
}

-- Wargear (fighter.wargear: the names as the roster lists them), just as
-- the skills -- shown by name in its own row, under the skills' (in the
-- headers colour); `short`, `desc`, `mods`, `action` / `type`, `costs`
-- and the rest work the same -- but wargear never stops working: at 0
-- wounds its fighter still has all of it, its actions on the Special tab
-- too (only a Seriously Injured fighter takes none of those). The
-- roster's statline already counts what armour and mounts do: `mods` are
-- only for what it doesn't.
RULES.wargear = {
    { name = "Bio-Booster",            desc = "", aka = { "Bio Booster", "Biobooster" },
      bioBooster = 1, burns = true },
    { name = "Bomb Delivery Rats",     desc = "" },
    { name = "Book Of The Redemption", desc = "" },
    { name = "Chaos Familiar",         desc = "" },
    { name = "Dirt Bike",              desc = "" },
    { name = "Drop Rig",               desc = "", action = "S", type = "utility", label = "Descend" },
    { name = "Grapnel Launcher",       desc = "", action = "D", type = "utility", label = "Grapnel" },
    { name = "Grav Chute",             desc = "", noFall = true },
    { name = "Hazard Suit",            desc = "", immune = { "blaze", "radphage" } },
    { name = "Medicae Kit",            desc = "", assist = 1 },
    { name = "Mesh Armour",            desc = "", aka = { "Mesh Armor" },
      mods = { Sv = -1 }, when = "engaged" },       -- a save one better in close combat
    { name = "Pyromantic Mantle",      desc = "" },
    { name = "Reflec Shroud",          desc = "", noAp = { "Las", "Plasma", "Melta" } },
    { name = "Refractor Shield",       desc = "", inv = 5, burns = true },
    { name = "Respirator",             desc = "", gasInv = 5 },
    { name = "Stimm-Slug Stash",       desc = "", aka = { "Stim-Slug Stash" },
      action = "F", type = "utility", label = "Stimm-Slug", once = true,
      boost = { M = 2, S = 2, T = 2 }, reaction = { roll = 1, wounds = 1 } },
}

-- Weapon accessories. The roster names a weapon with its accessories in
-- brackets after it ("Lasgun (Mono-Sight)"): those listed here -- found in
-- any case, hyphens and spaces aside (Infra-Sight, Infrasight) -- are
-- taken out of the name the card shows and put after the traits of the
-- weapon's profiles instead. What most of them do is in the roster's
-- profile already; what one can say for the card to do:
--   aimed   N: an Aimed Shot with the weapon is N better to hit, not 1
--           (Mono-Sight: 2) -- not on top of a skill's (Sharpshooter): the
--           better of the two counts;
--   aka     other names the roster may list it under (a list).
RULES.accessories = {
    { name = "Focusing Crystal" },
    { name = "Hotshot Las Pack" },
    { name = "Infra-Sight" },
    { name = "Las-Projector" },
    { name = "Mono-Sight", aimed = 2 },
    { name = "Suspensors" },
    { name = "Telescopic Sight" },
}

-- How each stat is tested (see the card's rollStat): the number of D6. M
-- and A are rolled but never tested. `under`: pass on a total at or below
-- the stat, otherwise at or above it. Roll-under stats also drop any "+"
-- on the card: a target rolled under reads "9", not "9+".
RULES.statRolls = {
    I   = { dice = 1, under = true  },
    T   = { dice = 1, under = true  },
    S   = { dice = 1, under = true  },
    Ld  = { dice = 2, under = true  },
    Wil = { dice = 2, under = true  },
    Int = { dice = 2, under = true  },
    Cl  = { dice = 2, under = true  },
    BS  = { dice = 1, under = false },
    WS  = { dice = 1, under = false },
    Sv  = { dice = 1, under = false },
}

-- The lowest and highest number each stat can show, whatever changes it:
-- a number set by hand, a condition, a skill, wargear or a weapon never
-- takes it past them. M is in inches; WS, BS and Sv are rolled at or over,
-- so 2+ (a save 3+) is the best they get and 6+ the worst. A right click on
-- a stat steps it up to its highest, then round to its lowest -- for
-- adjusting the statline by hand in play. `default`: any other (W).
RULES.limits = {
    M  = { 1, 12 },
    WS = { 2, 6 },  BS = { 2, 6 },  Sv = { 3, 6 },
    S  = { 1, 10 }, T  = { 1, 10 }, I  = { 1, 10 }, A = { 1, 10 },
    Ld = { 4, 10 }, Cl = { 4, 10 }, Wil = { 4, 10 }, Int = { 4, 10 },
    default = { 1, 10 },
}

-- The weapon traits the card reacts to, as Lua patterns (lower case,
-- matched against a whole comma-separated trait). N is a single digit.
RULES.traits = {
    melee     = "melee",
    smoke     = "smoke",              -- a hit with it doesn't Suppress (nor does Melee)
    unstable  = "unstable",
    unwieldy  = "unwieldy",
    light     = "light",
    rapidFire = "rapid fire%s*%(%s*%d%+?%s*%)",   -- Rapid Fire (N) / (N+)
    paired    = "paired",               -- Paired (N)             (names only:
    additional = "additional attacks?", -- Additional Attack(s) (N)  see the card's TRAIT_RULES.number)
    backstab  = "backstab",           -- +1 S against an enemy a friend is fighting too
    combi    = "combi",
    limited   = "limited",
    singleShot = "single shot",
    shield    = "shield",
    parry     = "parry",
    reliable  = "reliable",
    ammo      = "ammo",               -- Ammo (N+): a D6 after shooting, OUT below N (the card's TRAIT_RULES.ammoNeed)
    scarce    = "scarce",             -- Scarce (N+): a reload needs a D6 of N or more (the card's TRAIT_RULES.scarce)
    heavy     = "heavy",              -- a Braced Shot, and no Aimed Shot (in melee: Heavy Blows)
    assault   = "assault",            -- after a Dash, one Shoot with it, for no action
    toxin     = "toxin",              -- Toxin (N+)  (the card's TRAIT_RULES.toxin)
    shock     = "shock",              -- Shock (N+): a hit roll of N+ wounds automatically, as a 6
    knockback = "knockback",          -- Knockback (N+): a hit roll of N+ knocks the target back (once an attack)
    blast     = "blast[^,]*",         -- Blast (3") / (5"): a Knockback with it knocks nobody back
    cursed    = "cursed",             -- a target hit makes a Willpower check, failed: Insanity
    flash     = "flash",              -- ranged: no Wound roll; the target hit is Blind and loses its Ready marker
    graviton  = "graviton pulse",     -- ranged: no Wound roll
    lance     = "lance",              -- melee: +1 S on the charge ("A + 1") for a Mounted fighter
    template  = "template",           -- ranged: no hit roll, every enemy selected is hit
    blaze     = "blaze",              -- Blaze (N+): a Wound roll of N+ makes one more hit, which hits by itself
    -- what a wound does (the card's TRAIT_RULES.hurts; N without a number: 6)
    damage    = "damage",             -- Damage (N): a wound through takes N wounds off (without it: 1)
    rending   = "rending",            -- Rending (N+): a natural N+ to wound (Shock's 6 too) -- that wound's AP one worse
    shred     = "shred",              -- Shred (N+): N+ to wound -- that wound's Lethality one higher
    concussive = "concussive",        -- Concussive (N+): each N+ to wound -- a stack of Concussion
    gas       = "gas",                -- no armour save (a Respirator: 5+ invulnerable against it)
    web       = "web",                -- no armour save, no damage: Webbed instead
    radphage  = "rad%-?phage",        -- Rad-Phage: a wound -- the Radphage condition
}

-- The dice with faces of their own (the Mundane Controller's custom dice
-- show them): injuryDice, what each face of an Injury dice stands for --
-- rolled for a Recovery test: 1-2 Injury, 3-5 Serious Injury, 6 Out of
-- Action -- and firepower, the hits on each face of a Firepower dice, the
-- 1 also an Ammo check.
RULES.injuryDice = { "injured", "injured", "serious", "serious", "serious", "out" }
RULES.injury = {   -- each result: its name, and how good it is (the best die is kept)
    -- `short`: how chat writes it ("Recovery Test: Inj")
    out     = { label = "Out of Action",  rank = 1, short = "OOA" },
    serious = { label = "Serious Injury", rank = 2, short = "S. Inj" },
    injured = { label = "Injury",         rank = 3, short = "Inj" },
}
RULES.firepower = { { hits = 1, ammo = true }, { hits = 1 }, { hits = 1 }, { hits = 2 }, { hits = 2 }, { hits = 3 } }

-- The rule numbers among the card's settings (copied into its CFG):
--   engageRange   Engaged, automatically: when a fighter is put down, it
--                 and every enemy whose base is within this many inches of
--                 its base become Engaged (see the card's checkEngagement).
--   nerveRanges   Nerve Check: a friend of one of these ranks (fighter.rank)
--                 within its range in inches, base to base, and in sight
--                 lends its Cl when that is higher -- the best one counts.
--   nerveOutRange A fighter going Out of Action: its friends within this
--                 many inches (base to base, sight or not) must take a
--                 Nerve Check. A Prospect only shakes other Prospects;
--   nerveOutNone  one tagged with any of these (its role line:
--                 "Cyber-mastiff • Pet") shakes nobody;
--   nerveOutFoes  true: enemies within range test too.
--   groupRange    Group Activation: of the Ready friends the player has
--                 selected, those within this many inches, base to base,
--                 are the ones a passed check takes along (see the card's
--                 groupActivation).
--   preMeasure    true: pre-measuring is allowed -- the cursor on Group
--                 Activation in A's panel highlights every friend within
--                 groupRange, on Distribute Ammo every friend within its
--                 range.
--   agility       Agility test: one D6, passed on this or more;
--   agilityGang   the fighters of a gang of this `type` add `mod` to that
--                 die (the type as the roster names it under the gang's
--                 name, any case) -- unless the gang is any of `unless`,
--                 which the roster names in brackets after the type
--                 ("House Escher (Malstrain Corrupted)").
--   coupGang      Coup de Grace: the fighters of a gang of this `type` add
--                 `mod` to their own roll (read as agilityGang is).
--   fallSave     Falling Down: a passed Agility test takes this many
--                 inches off the height fallen;
--   fallLevels    what is left then decides what the fall does -- less than
--                 the first: Suppressed (if Active), and an activation ends; up to the
--                 second: a wound lost as well (at 0 wounds an Injury dice);
--                 more: Out of Action (see the card's fallingDown).
--   disruptRange  Wyrd powers: an enemy Wyrd within this many inches (base to
--                 base) with sight of the caster may try to disrupt the
--                 cast (see the card's ACTIVATION.cast);
--   disruptMod    a passed disrupt takes this off the caster's Willpower
--                 check (it may go below the lowest Wil);
--   concentrateMod  Concentrate adds this to Willpower checks to manifest
--                 powers until the activation ends;
--   maintainMod   Maintain Control (S) adds this to its Willpower check
--                 (Maintain Control (F) adds nothing);
--   powersLastNext  how long a Continuous power lasts. false: until the end
--                 of its Wyrd's activation, unless a Maintain Control passed
--                 during it holds it -- then until the end of the next
--                 activation, and so on, each Maintain Control passed in an
--                 activation holding it through that activation's end. true:
--                 a power cast lasts through the end of that activation
--                 without one, and then goes the same way.
--   shockNatural  Shock (N+) and Knockback (N+): false -- the hit roll
--                 with its modifiers must reach N (Shock (6+) with +1 to
--                 hit: a 5 does); true -- the die's own roll.
--   knockback     Knockback (N+): how many inches the target is knocked
--                 back, shown on its card once the attack is over -- the
--                 players move the model (see the card's knockback).
--   rapidOneHit   Shock (N+) on a Rapid Fire shot: false -- every hit the
--                 Firepower dice give shares the hit roll, so every one of
--                 them wounds automatically; true -- only the first does.
--   saveFails     a save roll of this or less always fails, whatever the
--                 save (2: a natural 1 or 2);
--   dicePause     seconds a roll that follows another waits after that one
--                 showed (the Wound roll after the Hit roll, the saves
--                 after the Wound roll ...); the last roll of all stays
--                 the card's diceShow seconds whatever this says.
--   coverShort, coverLong  what cover adds to a save roll against a ranged
--                 attack from within the weapon's Short Range, and from
--                 beyond it (within Long Range) -- a weapon with only one of
--                 the two in inches ("T", "-") always gives that one's (see
--                 the card's takeSaves);
--   coverTemplate what cover adds against a ranged attack with neither
--                 range in inches (a Template's "T").
RULES.cfg = {
    engageRange   = 1,
    nerveRanges   = { leader = 12, champion = 6 },
    nerveOutRange = 3,
    nerveOutNone  = { "pet" },
    nerveOutFoes  = false,
    groupRange    = 3,
    preMeasure    = false,
    agility       = 4,
    agilityGang   = { type = "House Escher", mod = 1,
                      unless = { "Chaos Corrupted", "Genestealer Corrupted", "Genestealer Infected",
                                 "Malstrain Corrupted" } },
    coupGang      = { type = "Genestealer Cults", mod = 1 },
    fallSave     = 3,
    fallLevels    = { 3, 6 },
    disruptRange  = 18,
    disruptMod    = -2,
    concentrateMod = 1,
    maintainMod   = 3,
    powersLastNext = false,
    shockNatural  = false,
    knockback     = 1,
    rapidOneHit   = false,
    saveFails     = 2,
    coverShort    = 1,
    coverLong     = 2,
    coverTemplate = 1,
    dicePause     = 3,
}

-- ── Overrides ────────────────────────────────────────────────
-- A table's own rules are a table of overrides, part by part, laid over
-- the defaults above (RULES.merge); a part left out stays as it is. Each
-- part takes them as it is shaped (RULES.PARTS):
--   "key" / "name"  (actions, conditions / skills, wargear, accessories) a
--       list of entries, each found by its `key` (a skill, wargear or
--       accessory by its `name`, any case):
--         one not there yet is added, at the end;
--         one that is there has the fields given changed, the rest kept
--         (a field set to false is removed);
--         `replace = true`: it is replaced by the one given, as a whole;
--         `disabled = true`: it is taken out.
--   "map"  (actionTypes, statusActions, statRolls, limits, traits, injury)
--       by key: a value replaces the default's -- a table of fields (not a
--       list) has its fields laid over the default's instead, as above --
--       false takes the key out, a new key is added.
--   "values"  (cfg) as a map, but only the keys already there, and false
--       is a value.
--   "list"  (injuryDice, firepower) the whole list, replaced.
-- For example:
--   {
--     actions    = { { key = "hide", label = "Hide", cost = "S", type = "utility" },
--                    { key = "dash", cost = "S" },
--                    { key = "coup_de_grace", disabled = true } },
--     statusActions = { active = { left = { "move", "dash", "engage", "charge", "interact", "hide" } } },
--     limits     = { M = { 1, 14 } },
--     firepower  = { { hits = 1, ammo = true }, { hits = 1 }, { hits = 2 }, { hits = 2 }, { hits = 3 }, { hits = 3 } },
--     cfg        = { nerveRanges = { leader = 18 } },
--   }
RULES.PARTS = {
    actionTypes = "map",   actions  = "key",  statusActions = "map", conditions = "key",
    skills      = "name",  wargear  = "name", statRolls     = "map", limits     = "map",
    traits      = "map",   injury   = "map",  injuryDice    = "list", firepower = "list",
    cfg         = "values", accessories = "name",
}

-- A copy of `v` all the way down (tables are never shared with it).
function RULES.copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = RULES.copy(x) end
    return t
end

-- Whether `a` and `b` hold the same, all the way down.
function RULES.same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not RULES.same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

-- Whether table `t` is a list (or empty): replaced whole, never merged.
function RULES.isList(t) return t[1] ~= nil or next(t) == nil end

-- The fields of `over` laid over table `into` (copies): false removes one.
function RULES.lay(into, over)
    for k, v in pairs(over) do
        if v == false then into[k] = nil else into[k] = RULES.copy(v) end
    end
    return into
end

-- An entry's id in a part of kind "key" / "name" (see RULES.PARTS).
function RULES.id(kind, e)
    if type(e) ~= "table" then return nil end
    if kind == "name" then return e.name ~= nil and tostring(e.name):lower() or nil end
    return e.key
end

-- The rules the overrides `over` make: a fresh table of every part (see
-- RULES.PARTS), the defaults with `over` laid over them. Anything it
-- doesn't understand is passed over; nil or {} gives the defaults.
function RULES.merge(over)
    local out = RULES.copy(RULES.DEFAULT)
    if type(over) ~= "table" then return out end
    for part, kind in pairs(RULES.PARTS) do
        local o, t = over[part], out[part]
        if type(o) ~= "table" then
            -- not overridden
        elseif kind == "list" then
            out[part] = RULES.copy(o)
        elseif kind == "map" or kind == "values" then
            for k, v in pairs(o) do
                if kind == "values" and t[k] == nil then
                    -- not a setting of the rules: left alone
                elseif v == false and kind == "map" then
                    t[k] = nil
                elseif type(v) == "table" and type(t[k]) == "table" and not RULES.isList(v)
                       and not RULES.isList(t[k]) then
                    RULES.lay(t[k], v)
                else
                    t[k] = RULES.copy(v)
                end
            end
        else
            for _, e in ipairs(o) do
                local id = RULES.id(kind, e)
                local at
                for i, x in ipairs(id ~= nil and t or {}) do
                    if RULES.id(kind, x) == id then at = i break end
                end
                if id == nil then
                    -- no key / name: nothing to go by
                elseif e.disabled then
                    if at then table.remove(t, at) end
                else
                    local entry = RULES.lay((at and not e.replace) and t[at] or {}, e)
                    entry.replace, entry.disabled = nil, nil
                    t[at or #t + 1] = entry
                end
            end
        end
    end
    return out
end

-- Functions that work out what follows from the rules (see RULES.follow).
RULES.followers = {}

-- Runs `fn` now, and again every time the rules in force change.
function RULES.follow(fn)
    RULES.followers[#RULES.followers + 1] = fn
    fn()
end

-- Puts the rules the overrides `over` make in force (RULES.merge): each
-- part that differs is changed in place -- the tables stay the same
-- tables, so whatever holds one sees the change -- and then every
-- RULES.follow function runs. Returns whether anything changed.
function RULES.use(over)
    local merged, changed = RULES.merge(over), false
    for part in pairs(RULES.PARTS) do
        local live = RULES[part]
        if not RULES.same(live, merged[part]) then
            for k in pairs(live) do live[k] = nil end
            for k, v in pairs(merged[part]) do live[k] = v end
            changed = true
        end
    end
    if changed then
        for _, fn in ipairs(RULES.followers) do fn() end
    end
    return changed
end

-- The defaults, as written above, for RULES.merge to start from.
RULES.DEFAULT = {}
for part in pairs(RULES.PARTS) do RULES.DEFAULT[part] = RULES.copy(RULES[part]) end
--@@RULES_END

-- ══════════════════════════════════════════════════════════════
--  Settings
-- ══════════════════════════════════════════════════════════════

-- The dice. Every roll -- a fighter card's (its stat tests, A's Special
-- tab, Recovery tests, Nerve Checks, attacks, reloads: see throwDice), a
-- Bottle Check, the Roll Dice / Roll Firepower / Roll Injuries buttons --
-- is thrown here (this object's own rolls also said on everyone's screen):
-- dropped from DROP (world units) above the table, tumbling (SPIN radians
-- a second, at least half of it about every axis) and pushed up to PUSH
-- (world units a second) sideways, any way, in a line BELOW panel units
-- under the panel (worked out like the plates: BOTTLE.spot).
-- Once they rest they are lined up side by side, STEP apart, in the order
-- they were thrown (SORT "thrown"; "up" / "down" line them up by face
-- instead -- only on the table: the card and chat always get them in the
-- order thrown), the rolled face up and every die of a kind turned the
-- same way (TURN[kind] degrees more about the vertical: the Firepower and
-- Injury dice's symbols towards the players), locked -- and stay there until
-- the next roll (a save keeps them too). A roll asked for while one is still
-- falling waits for it, and NEXT seconds more so the last can be seen.
-- Clicks on the buttons within JOIN seconds of each other add to one roll
-- (up to MAX dice), thrown once no click has come for JOIN seconds. WAIT:
-- the longest the dice are waited for before they are read as they lie.
-- A die counts as down only once it has fallen FALL world units from where
-- it spawned and rests again (TTS can hold a fresh die still in mid-air,
-- "resting", for a moment); until it falls it is kicked again every KICK
-- frames, and once more as it starts to fall (see DICE.settled).
--   URL: the custom dice's art, one image per kind (TTS's D6 template with
-- the faces drawn on). Until set, TTS's own D6 (PLAIN) is thrown, in the
-- roller's colour. A Firepower or Injury dice is
-- read from its number through CHART (the rules' RULES.firepower /
-- RULES.injuryDice, as the cards read them). SCALE: the dice's size.
local DICE = {
    URL   = { d6 = "https://steamusercontent-a.akamaihd.net/ugc/14438694407390139777/F5A3307604C00D6896ACC7B82B6735BD024137EA/", firepower = "https://steamusercontent-a.akamaihd.net/ugc/14511214079636238699/82E750A272596F79249868C7DD4611B69FF6D099/", injury = "https://steamusercontent-a.akamaihd.net/ugc/14681495304683522636/208E2C4C0EF8613F91ACC93C75BDDF1493D6926E/" },
    PLAIN = "Die_6",
    BELOW = 100, DROP = 4, SPIN = 18, PUSH = 3, STEP = 1.4, SCALE = 1,
    SORT  = "thrown", TURN = { d6 = 0, firepower = 180, injury = 180 },
    APART = 4,              -- a roll-off's two dice: this far apart, each on its side's side
    JOIN = 1, NEXT = 1.5, WAIT = 12, MAX = 20,
    FALL  = 0.3, KICK = 10,
    TAG   = "Mundane Dice",
    NAMES = { d6 = "D6", firepower = "Firepower Dice", injury = "Injury Dice" },
    CHART = { firepower = RULES.firepower, injury = RULES.injuryDice },
}

-- The Controller's panel on this object: where it sits (its size: see
-- PANEL_W / PLAY_BASE) -- on the object's +z side, turned half round so
-- it reads the right way up from there (see panelLocal).
local PANEL = { position = "0 335 -5", rotation = "0 0 180", scale = "1 1 1" }

-- The die on the Bottle Check's roll button -- the fighter card's own
-- (its ASSETS stat_die), so both look alike. Empty: a "D" instead.
local DIE_ICON = "https://steamusercontent-a.akamaihd.net/ugc/12001738551517573707/F2E806437431BEE65DD78832C9C5A286D327A301/"

-- The deployment's model: rolled on the setup's Roll for Deployment, a
-- see-through custom model of the deployment zones is put in the middle
-- of the table (0, 0, 0; locked). MESH[face of the D6] gives its mesh's
-- link: { link, stretch = true } -- one model made for a BASE" map,
-- stretched across (not up) to the map size chosen; { link } -- one model
-- for every map size, as it is; or { [36] = link, [48] = link } -- one per
-- map size. COLLIDER is the one collider every model shares (stretched
-- with a stretched one). Empty link: no model for it; chat says so.
-- It is tinted TINT (8100FF at alpha 150), turned TURN degrees at a time
-- and stretched up / down by STEP (of its own height, never below STEP)
-- by the small buttons beside the row -- kept for the next one (saved).
-- A right click on the row takes it away, and the next puts it back;
-- Start Game takes it away, and going back from round 1 to the setup puts
-- it back. SIZES: the map sizes the setup's Map Size goes through, in turn.
local DEPLOY = {
    SIZES = { 36, 48 },
    MESH = {
        { "https://steamusercontent-a.akamaihd.net/ugc/9465755442651241131/390F4CE0CDC31319D057EA10E172162A1488D256/", stretch = true },         -- 1 Sniping Range
        { "https://steamusercontent-a.akamaihd.net/ugc/9465755442651241131/390F4CE0CDC31319D057EA10E172162A1488D256/", stretch = true },         -- 2 Face Off
        { "https://steamusercontent-a.akamaihd.net/ugc/9465755442651241131/390F4CE0CDC31319D057EA10E172162A1488D256/", stretch = true },         -- 3 Stand Off
        { "https://steamusercontent-a.akamaihd.net/ugc/11891530078336619171/3F73632BB82474CB818688E2AF2B0080B726354D/" },                         -- 4 Ambush
        { [36] = "https://steamusercontent-a.akamaihd.net/ugc/17867774420708299133/10A0F962A14186C96646CA6F25A87194272F8D2E/", [48] = "https://steamusercontent-a.akamaihd.net/ugc/17929910256943798418/A327586A2CD4B113197323620CFE2C157DEF2352/" },       -- 5 Free for All
        { [36] = "https://steamusercontent-a.akamaihd.net/ugc/15512193714167926411/4AFE70845D320E07D87041B2CC95B5E87A7EFDE0/", [48] = "https://steamusercontent-a.akamaihd.net/ugc/14713276897348078853/B3B86E458A793322E22F8D4A93D0E3182D5B0E8D/" },       -- 6 Chance Encounter
    },
    BASE = 36,
    COLLIDER = "https://steamusercontent-a.akamaihd.net/ugc/9590185350319248742/E1ACACACB191CDC4F0211AC33E42B34B043DBD19/",
    TINT = { r = 0x81 / 255, g = 0, b = 1, a = 150 / 255 },
    TURN = 90, STEP = 0.5,
    TAG  = "Mundane Deployment",
    turn = 0, tall = 1,     -- how the last one stood: turned, and stretched up (saved)
}

-- Homebrew: the table's own rules, as named sets, each a choice between
-- the rules as written and the set's -- two radio buttons on the panel's
-- second page, Homebrew Rules (the main page's button opens it, Back
-- leaves it as it was), where "Apply selected Rules to all Models" puts every choice in
-- force at once -- kept with the Controller. Each of SETS:
--   id     what a save knows it by (the same however the set is renamed)
--   off    the first button: the rules as written -- about 24 letters fit
--   name   the second: the set's rules
--   offDesc  under them while the first is chosen: what the rules as
--          written do, a line or two
--   desc   the same while the second is chosen: what the set does
--   rules  the overrides the set makes, in the format of the rules (see the
--          overrides in RULES: actions, conditions, skills, wargear, limits,
--          cfg, ...). Sets that are on are laid over each other in this
--          order, so where two change the same thing the later one wins --
--          but sets that add different actions, change different limits
--          and so on just add up.
-- (An "&" in a name or description reads "and", a "<" or ">" is dropped:
-- TTS shows what is escaped as it is.)
local HOMEBREW = {
    SETS = {
        { id = "pre_measure", off = "No Pre-Measuring", name = "Allow Pre-Measuring",
          offDesc = "Nothing shows who is in range before an action is taken: distances are judged by eye.",
          desc = "The cursor on Group Activation or Distribute Ammo highlights friendly fighters within range.",
          rules = { cfg = { preMeasure = true } } },
        { id = "long_powers", off = "RAW Continuous Powers", name = "Long Continuous Powers",
          offDesc = "A Continuous Power lasts until the end of the Wyrd's activation (if not Maintain Control (S)).",
          desc = "A Continuous Power lasts until the end of the Wyrd's next activation.",
          rules = { cfg = { powersLastNext = true } } },
        { id = "shock_natural", off = "Modified Shock/Knockback", name = "Natural Shock/Knockback",
          offDesc = "The Hit roll's modifiers count for Shock (X+) and Knockback (X+): (6+) with +1 to hit triggers on a 5.",
          desc = "Only the die counts for Shock (X+) and Knockback (X+): (6+) triggers on a natural 6 alone.",
          rules = { cfg = { shockNatural = true } } },
        { id = "rapid_one_hit", off = "Rapid Fire has Hit-Rolls", name = "Rapid Fire has 1 Hit-Roll",
          offDesc = "A Shock hit at Rapid Fire makes every hit's Wound roll an automatic 6.",
          desc = "A Shock hit at Rapid Fire makes only the first hit's Wound roll an automatic 6.",
          rules = { cfg = { rapidOneHit = true } } },
        { id = "slow_dice", off = "Fast Dice Speed", name = "Slow Dice Speed",
          offDesc = "A roll that follows another (the Wound roll after the Hit roll, the saves after it) waits 3 s.",
          desc = "A roll that follows another (the Wound roll after the Hit roll, the saves after it) waits 4.5 s.",
          rules = { cfg = { dicePause = 4.5 } } },
    },
    on = {},                -- id -> true, for the sets that are on (saved)
    SEP_H = 2,              -- the line between two sets on the page
    pick = {},              -- id -> true: the page's choice, until applied
    page = false,           -- the Homebrew Rules page shows (not saved)
}

-- The panel's size (the importer's, so the two look alike side by side)
-- and what follows from it: a row's width inside the border (3) and the
-- padding (9), and the play section under the header (40, then 6) --
-- two bars of buttons, the victory points and the turn, the gangs' names
-- and their Bottle Checks, 6 apart. The Homebrew Rules page takes the
-- play section's place, as tall: its heading, a rule (3), for each set a
-- row of radio buttons over its description, and at the bottom the Apply
-- button, 6 apart.
local PANEL_W   = 600
local PLAY_BASE = 664
local ROW_W     = PANEL_W - 2 * 9 - 2 * 3
local PLAY_H    = PLAY_BASE - 2 * 9 - 2 * 3 - 40 - 6
local BAR_H     = 30                   -- each row of buttons on top (two rows)
local HB_HEAD_H = 28                   -- the Homebrew Rules heading
local HB_ROW_H  = 34                   -- each set's radio buttons ...
local HB_DESC_H = 34                   -- ... and its description under them
local HB_APPLY_H = 40                  -- Apply selected Rules to all Models
local PANEL_H   = PLAY_BASE
local BOTTLE_H  = 120                  -- the two Bottle Checks, under the victory points
local NAME_H    = 32                   -- the gangs' names, over the Bottle Checks
local VP_ROW_H  = PLAY_H - 2 * (BAR_H + 6) - 6 - NAME_H - 6 - BOTTLE_H   -- the victory points and the turn

-- The turn it counts (0: the game hasn't started -- the plate shows the
-- game's setup, see SETUP), and the two players' victory points and names.
local turn = 0
local vp, vpNames = { 0, 0 }, { "Player 1", "Player 2" }

-- A clear button over a whole plate, so the plate itself is clicked: a
-- light tint on hover.
local function plateButton(id, fn)
    return string.format('<Button id="%s" colors="#00000000|#FFFFFF14|#FFFFFF26|#00000000" outline="#00000000"' ..
        ' onClick="%s" />', id, fn)
end

-- Reset all Fighters: every fighter's card back to the fighter as
-- imported (see onResetFighters) -- after a second click, within WAIT
-- seconds, while the button asks.
local RESET = {
    LABEL = "Reset all Fighters",
    ASK   = "Click again to reset",
    WAIT  = 4,
    ASKING = "#B03030E6|#C04040E6|#8A2020E6|#B0303066",   -- brighter than RED while it asks
    asking = false, token = 0,
}

-- The game's setup, on the round plate until the game starts: a column
-- of buttons (ROWS, top to bottom, all as tall) -- the map size (a click
-- goes on to the next of DEPLOY.SIZES), three that roll a D6 in the dice
-- line for the battle's deployment, objective and crews (said on
-- everyone's screen, and the result is the button's text from then on; a
-- click rolls again -- the deployment also puts its model on the table,
-- see DEPLOY), the roll-off for who chooses Attacker and Defender,
-- three that do nothing yet, and Start Game (the round plate's own left
-- click: round 1, and the plate shows the round from then on). Each row of
-- ROWS:
--   label    what the button reads until it has rolled
--   start    Start Game
--   key      what a save knows its roll by
--   say      the word the result is said after ("Scenario: Ambush")
--   results  what each face of the D6 means (as said)
--   button   ... and as the button shows it, where it differs: "\n" for
--            a line break of its own
--   rollOff  a D6 for each side, thrown together (DICE.APART apart, the
--            left side's on the left): the higher one chooses -- a tie
--            is thrown again
--   map      the map size
--   deploy   the deployment: its model, and the small buttons beside it
--            (TOOL_W wide each, GAP apart) that turn it, and raise and
--            lower it
-- Which side attacks shows at the bottom of each victory points plate
-- (the left one is the Attacker until swapped there). Crews with
-- reinforcements are remembered on the round plate (SETUP.reminder).
local SETUP = {
    ROWS = {
        { label = "Map Size", map = true },
        { label = "Roll for Deployment", key = "deployment", say = "Deployment", deploy = true,
          results = { "Sniping Range", "Face Off", "Stand Off", "Ambush", "Free for All", "Chance Encounter" } },
        { label = "Roll for Objective", key = "objective", say = "Objective",
          results = { "King of the Hive", "Turf War", "Tunnel Clash", "Object Lesson", "Flank 'em", "Burn Them Out" } },
        { label = "Roll for Crews", key = "crews", say = "Crew",
          results = { "Hybrid (3 + D3) - Reinforcements (5) - D3 per Round", "Custom (10)", "Hybrid (3 + 4)",
                      "Attacker: Hybrid (4 + 4)  ||  Defender: Custom (3) - Reinforcements (7) - D3 per Round",
                      "Custom (5)", "Hybrid (D3 + 5)" },
          button = { [1] = "Hybrid (3 + D3)\nReinforcements (5) - D3 per Round",
                     [4] = "Attacker: Hybrid (4 + 4)\nDefender: Custom (3) - Reinforcements (7) - D3 per Round" } },
        { label = "Determine Attacker | Defender", key = "sides", rollOff = true },
        { label = "Choose Crews" },
        { label = "Gang Tactics" },
        { label = "Deployment (Defender starts)" },
        { label = "Start Game", start = true },
    },
    attacker = 1,           -- the side (1 left, 2 right) that attacks; the other defends (saved)
    map      = 36,          -- the map size, in inches a side (saved)
    rolled   = {},          -- a roll's key -> the face it came up (saved)
    rolling  = {},          -- a row -> true while its die is falling
    W = ROW_W - 2 * 130 - 12,   -- the round plate's width
    GAP = 4, PAD = 6,       -- the rows: apart, and clear of the plate's edge (each as tall: the rest)
    FONT = 17, MIN = 9,     -- a row's text: its size, and the smallest it shrinks to
    TOOL_W = 36,            -- the deployment's small buttons: each column's width
    FILL  = "#4D5A5EE6",    -- a row: lighter than the plate, so it reads as a button
    START = "#E6E5E1E6",    -- Start Game: parchment, with anthracite type
    ATTACKER = "#E0B830E6", DEFENDER = "#2BB3ADE6",   -- yellow and turquoise, with anthracite type
    SAY = { 1, 0.85, 0.4 }, -- what the rolls and swaps say
}

-- How wide a character of Arial Bold is, in ems (any other: as wide as
-- an "n") -- to wrap and size a row's text (see SETUP.fit).
SETUP.EM = {}
for chars, em in pairs({ [" ijlI.,;!|'"] = 0.278, ["ft():-"] = 0.333, r = 0.389, z = 0.5,
                         ["acekpsvxy0123456789J"] = 0.556, ["+"] = 0.584, ["bdghnopquFLTZ"] = 0.611,
                         ["EPSVXY"] = 0.667, ["ABCDHKNRU"] = 0.722, ["wGOQ"] = 0.778, M = 0.833, m = 0.889,
                         W = 0.944 }) do
    for c in chars:gmatch(".") do SETUP.EM[c] = em end
end
function SETUP.em(c) return SETUP.EM[c] or 0.611 end

-- `text` wrapped at its spaces (and its own line breaks) and sized to fit
-- `w` x `h`: the lines (joined by line breaks) and the font size -- FONT,
-- or as much smaller as it needs (never below MIN).
function SETUP.fit(text, w, h)
    local function width(s, size)
        local n = 0
        for c in s:gmatch(".") do n = n + SETUP.em(c) end
        return n * size
    end
    local lines
    for size = SETUP.FONT, SETUP.MIN, -1 do
        lines = {}
        for given in (text .. "\n"):gmatch("([^\n]*)\n") do
            local first = #lines + 1
            for word in given:gmatch("%S+") do
                local cur = #lines >= first and lines[#lines]
                if cur and width(cur .. " " .. word, size) <= w then lines[#lines] = cur .. " " .. word
                else lines[#lines + 1] = word end
            end
        end
        local fits = #lines * size * 1.2 <= h
        for _, l in ipairs(lines) do fits = fits and width(l, size) <= w end
        if fits then return table.concat(lines, "\n"), size end
    end
    return table.concat(lines, "\n"), SETUP.MIN
end

-- Row `k`'s middle (up from the plate's) and height, and its button's
-- width and middle across -- the plate's height shared out evenly between
-- the rows; the deployment's button leaves room for its small buttons on
-- the right.
function SETUP.place(k)
    local n = #SETUP.ROWS
    local h = (VP_ROW_H - 6 - 2 * SETUP.PAD - (n - 1) * SETUP.GAP) / n
    local w, tools = SETUP.W - 6 - 2 * SETUP.PAD, SETUP.ROWS[k].deploy and 2 * (SETUP.TOOL_W + SETUP.GAP) or 0
    return (VP_ROW_H - 6) / 2 - SETUP.PAD - (k - 1) * (h + SETUP.GAP) - h / 2, h, w - tools, -tools / 2
end

-- Side `n`'s name as the setup says it: its gang's, or "Player <n>".
function SETUP.side(n)
    local name = trim(tostring(vpNames[n] or ""))
    return name ~= "" and name or ("Player " .. n)
end

-- The reminder at the bottom of the round plate once the game is under
-- way: what each part of the crews rolled that brings reinforcements
-- brings every round, as "Reinforcements - D3" -- "Defender:
-- Reinforcements - D3" when only one side's part of it does. Nil when none
-- does (or no crews were rolled).
function SETUP.reminder()
    for _, row in ipairs(SETUP.ROWS) do
        local text = row.key == "crews" and row.results[SETUP.rolled.crews or 0]
        if text then
            local out = {}
            for part in (text .. "||"):gmatch("(.-)||") do
                local each = part:match("Reinforcements %(%d+%) %- (%S+) per Round")
                if each then
                    local who = trim(part):match("^(%a+):")
                    out[#out + 1] = (who and who .. ": " or "") .. "Reinforcements - " .. each
                end
            end
            return #out > 0 and table.concat(out, ", ") or nil
        end
    end
end

-- What row `k` reads, fitted: its text and font size.
function SETUP.view(k)
    local row = SETUP.ROWS[k]
    local text = row.label
    local face = row.key and SETUP.rolled[row.key]
    if row.map then text = string.format('Map Size: %d" x %d"', SETUP.map, SETUP.map)
    elseif SETUP.rolling[k] then text = "Rolling..."
    elseif face and row.rollOff then text = SETUP.side(face) .. " chooses"
    elseif face then text = row.say .. ": " .. (row.button and row.button[face] or row.results[face])
    end
    local _, h, w = SETUP.place(k)
    return SETUP.fit(text, w - 6, h - 4)
end

-- The reminder (SETUP.reminder) as the round plate shows it: its text,
-- font size, and whether it shows -- at the bottom, in the last row's
-- place, as big as a row's text.
function SETUP.note()
    local text = SETUP.reminder()
    local _, h, w = SETUP.place(#SETUP.ROWS)
    local fitted, size = SETUP.fit(text or "", w - 6, h - 4)
    return fitted, size, text ~= nil
end
function SETUP.noteXml()
    local y, h, w = SETUP.place(#SETUP.ROWS)
    local text, size, on = SETUP.note()
    return string.format('<Text id="roundNote" active="%s" rectAlignment="MiddleCenter" offsetXY="0 %g" width="%g"' ..
        ' height="%g" fontSize="%d" fontStyle="Bold" alignment="MiddleCenter" color="%s" raycastTarget="false">%s</Text>',
        tostring(on), y, w - 6, h - 4, size, PALE, xmlEsc(text))
end

-- The setup's column of rows, in the round plate (shown before round 1).
function SETUP.xml()
    local out = { string.format('<Panel id="setupPanel" active="%s" rectAlignment="MiddleCenter" width="%g" height="%g"' ..
        ' color="#00000000">', tostring(turn < 1), SETUP.W - 6, VP_ROW_H - 6) }
    for k, row in ipairs(SETUP.ROWS) do
        local y, h, w, x = SETUP.place(k)
        local text, size = SETUP.view(k)
        out[#out + 1] = string.format([[
                <Panel id="setup_%d" rectAlignment="MiddleCenter" offsetXY="%g %g" width="%g" height="%g" color="%s"%s>
                  %s
                  <Text id="setupTxt_%d" rectAlignment="MiddleCenter" width="%g" height="%g" fontSize="%d" fontStyle="Bold"
                        alignment="MiddleCenter" color="%s" raycastTarget="false">%s</Text>
                </Panel>]], k, x, y, w, h, row.start and SETUP.START or SETUP.FILL, BEVEL,
            plateButton("setupBtn_" .. k, row.start and "onAdvanceTurn" or "onSetup"), k, w - 6, h - 4, size,
            row.start and INK or PALE, SETUP.esc(text))
        if row.deploy then out[#out + 1] = SETUP.toolsXml(y, h, w / 2 + x) end
    end
    out[#out + 1] = "</Panel>"
    return table.concat(out, "\n")
end

-- A row's text as a Text holds it: inch marks and apostrophes as they
-- are (a Text would show an entity as it is written).
function SETUP.esc(s)
    return (tostring(s or ""):gsub("&", "and"):gsub("[<>]", ""))
end

-- The deployment's small buttons, right of its button (whose right edge
-- is at `right`), in a row `h` tall at `y`: one that turns the model
-- (deployTurn, as tall as the row) and, in a column beside it, one that
-- raises it over one that lowers it (deployUp / deployDown) -- each a
-- clear button over a framed panel, like the rows.
function SETUP.toolsXml(y, h, right)
    local tw, g = SETUP.TOOL_W, SETUP.GAP
    local function tool(id, x, yy, hh, label, size)
        return string.format([[
                <Panel id="%sBox" rectAlignment="MiddleCenter" offsetXY="%g %g" width="%g" height="%g" color="%s"%s>
                  %s
                  <Text rectAlignment="MiddleCenter" width="%g" height="%g" fontSize="%d" fontStyle="Bold"
                        alignment="MiddleCenter" color="%s" raycastTarget="false">%s</Text>
                </Panel>]], id, x, yy, tw, hh, SETUP.FILL, BEVEL, plateButton(id, "onDeployTool"), tw, hh, size, PALE, label)
    end
    local x1, x2, hh = right + g + tw / 2, right + 2 * g + 1.5 * tw, (h - 2) / 2
    return tool("deployTurn", x1, y, h, "90°", 13) .. "\n" ..
        tool("deployUp", x2, y + hh / 2 + 1, hh, "▲", 10) .. "\n" ..
        tool("deployDown", x2, y - hh / 2 - 1, hh, "▼", 10)
end

-- Row `k` redrawn in place (font sizes scaled by PANEL_DETAIL like the
-- built XML's).
function SETUP.draw(k)
    local text, size = SETUP.view(k)
    self.UI.setAttribute("setupTxt_" .. k, "fontSize", string.format("%d", size * PANEL_DETAIL))
    setLabel("setupTxt_" .. k, text)
end

-- Every row redrawn (a side's name in the roll-off's result may have
-- changed).
function SETUP.drawAll()
    for k in ipairs(SETUP.ROWS) do SETUP.draw(k) end
end

-- Side `n`'s part, as its victory points plate shows it: the word and the
-- colour behind it.
function SETUP.role(n)
    if n == SETUP.attacker then return "Attacker", SETUP.ATTACKER end
    return "Defender", SETUP.DEFENDER
end

-- Attacker and Defender swapped, both plates redrawn, and said in chat.
function SETUP.swap()
    SETUP.attacker = 3 - SETUP.attacker
    for n = 1, 2 do
        local word, fill = SETUP.role(n)
        setLabel("vpRoleTxt_" .. n, word)
        self.UI.setAttribute("vpRole_" .. n, "color", fill)
    end
    printToAll(string.format("%sAttacker: %s -- Defender: %s", CHAT_PREFIX, SETUP.side(SETUP.attacker),
        SETUP.side(3 - SETUP.attacker)), SETUP.SAY)
end

-- The deployment's model on the table, if there is one (the last spawned,
-- else the first found with DEPLOY.TAG -- one from before a load).
function DEPLOY.find()
    local o = DEPLOY.obj
    if o and not (o.isDestroyed and o.isDestroyed()) then return o end
    local ok, list = pcall(function() return getObjectsWithTag(DEPLOY.TAG) end)
    DEPLOY.obj = ok and type(list) == "table" and list[1] or nil
    return DEPLOY.obj
end

-- Every deployment model taken off the table. Returns whether there was one.
function DEPLOY.remove()
    local any = false
    local ok, list = pcall(function() return getObjectsWithTag(DEPLOY.TAG) end)
    for _, o in ipairs(ok and type(list) == "table" and list or {}) do
        any = true
        pcall(function() o.destruct() end)
    end
    if DEPLOY.obj then
        any = true
        pcall(function() if not DEPLOY.obj.isDestroyed() then DEPLOY.obj.destruct() end end)
    end
    DEPLOY.obj = nil
    return any
end

-- Deployment `face`'s model on the map size chosen: its mesh's link, its
-- collider's, and how far it is stretched across (1: made for that size).
function DEPLOY.model(face)
    local mesh = DEPLOY.MESH[face] or {}
    if mesh[1] == nil then return mesh[SETUP.map] or "", DEPLOY.COLLIDER, 1 end
    return mesh[1], DEPLOY.COLLIDER, mesh.stretch and SETUP.map / DEPLOY.BASE or 1
end

-- The model of deployment `face` (Roll for Deployment's result) on the
-- map size chosen, in place of any other: in the middle of the table,
-- turned DEPLOY.turn, stretched up DEPLOY.tall, locked, see-through. With no link for
-- it, chat says so and nothing is put down.
function DEPLOY.spawn(face, name)
    DEPLOY.remove()
    local url, collider, stretch = DEPLOY.model(face)
    if url == "" or not spawnObject then
        printToAll(string.format('%sNo deployment model for %s on a %d" x %d" map yet.', CHAT_PREFIX, name or "?",
            SETUP.map, SETUP.map), { 0.7, 0.7, 0.7 })
        return nil
    end
    local ok, o = pcall(spawnObject, {
        type = "Custom_Model",
        position = { 0, 0, 0 },
        rotation = { 0, DEPLOY.turn, 0 },
        scale = { stretch, DEPLOY.tall, stretch },
        sound = false,
        callback_function = function(obj)
            pcall(function()
                obj.setLock(true)
                obj.setName("Deployment: " .. (name or ""))
                obj.setColorTint(DEPLOY.TINT)
            end)
        end,
    })
    if not (ok and o) then return nil end
    pcall(function()
        o.setCustomObject({ mesh = url, collider = collider, type = 0, cast_shadows = false })
    end)
    pcall(function() o.setLock(true) end)
    pcall(function() o.addTag(DEPLOY.TAG) end)
    DEPLOY.obj, DEPLOY.stretch = o, stretch
    return o
end

-- The deployment rolled put on the table again (nothing when none was
-- rolled). Returns the model, if one was put down.
function DEPLOY.again()
    for _, row in ipairs(SETUP.ROWS) do
        local face = row.deploy and SETUP.rolled[row.key]
        if face then return DEPLOY.spawn(face, row.results[face]) end
    end
end

-- Row `k`'s roll-off: a D6 for each side, thrown together, the left
-- side's on the left. The higher one chooses Attacker and Defender (said
-- on everyone's screen, and on the row); a tie is thrown again.
function SETUP.rollOff(k, color)
    SETUP.rolling[k] = true
    SETUP.draw(k)
    DICE.request({ kinds = { "d6", "d6" }, apart = DICE.APART, inOrder = true, color = color,
        done = function(faces, digital)
            local how = digital and " (rolled digitally)" or ""
            if faces[1] == faces[2] then
                DICE.announce(string.format("%sRoll-off: %s and %s both roll %d -- rolled again%s", CHAT_PREFIX,
                    SETUP.side(1), SETUP.side(2), faces[1], how), SETUP.SAY)
                return SETUP.rollOff(k, color)
            end
            local win = faces[1] > faces[2] and 1 or 2
            SETUP.rolling[k] = nil
            SETUP.rolled[SETUP.ROWS[k].key] = win
            SETUP.draw(k)
            DICE.announce(string.format("%s%s chooses%s", CHAT_PREFIX, SETUP.side(win), how), SETUP.SAY)
        end })
end

-- A player's victory points, beside the turn: clicking the plate counts
-- them (left +1, right -1). At its bottom the side's part, Attacker or
-- Defender (vpRole_<n>: a click there swaps them, see SETUP). The gang's
-- name is over its Bottle Check (nameXml).
local function vpXml(n)
    local word, fill = SETUP.role(n)
    return string.format([[
          <Panel preferredWidth="130" color="%s" outline="#29313366" outlineSize="2 2" padding="2 2 2 2">
            <Panel color="#00000000" outline="#E6E5E159" outlineSize="1 1">
              %s
              <Text rectAlignment="UpperCenter" offsetXY="0 -8" width="126" height="44" fontSize="36"
                    fontStyle="Bold" color="%s" raycastTarget="false">VP</Text>
              <Text id="vpText_%d" rectAlignment="MiddleCenter" offsetXY="0 -10" width="120" height="140"
                    fontSize="90" fontStyle="Bold" color="%s" raycastTarget="false">%d</Text>
              <Panel id="vpRole_%d" rectAlignment="MiddleCenter" offsetXY="0 %g" width="114" height="34" color="%s"%s>
                %s
                <Text id="vpRoleTxt_%d" rectAlignment="MiddleCenter" width="110" height="30" fontSize="20" fontStyle="Bold"
                      alignment="MiddleCenter" color="%s" raycastTarget="false">%s</Text>
              </Panel>
            </Panel>
          </Panel>]], LIT, plateButton("vpBtn_" .. n, "onVp"), PALE, n, PALE, vp[n],
        n, -(VP_ROW_H - 4) / 2 + 6 + 17, fill, BEVEL, plateButton("vpRoleBtn_" .. n, "onSwapRoles"), n, INK, word)
end

-- A player's gang name (to type in, or put one of the gang's models on
-- their victory points plate), as wide as their Bottle Check under it.
local function nameXml(n)
    return string.format([[
          <InputField id="vpName_%d" preferredWidth="%g" fontSize="16" characterLimit="40" textAlignment="MiddleCenter"
                      textColor="%s" colors="%s" outline="#29313366" outlineSize="2 2"
                      text="%s" onEndEdit="onVpName" />]], n, (ROW_W - 6) / 2, PALE,
        "#293133E6|#3A4447E6|#1C2224E6|#293133E6", xmlEsc(vpNames[n]))
end

-- The Bottle Check (see BOTTLE): each player's, under their gang's name,
-- half the row wide. It is the fighter card's Nerve Check panel in the
-- Controller's colours: "Bottle Check" over two diamonds, centred -- the
-- Ld it is taken against (bottleVal: left click one more, right click one
-- fewer, by hand; green while the gang's Iron Will raises it, see
-- BOTTLE.target), with "Ld" left of it, and the die that rolls it
-- (bottleRoll: the card's die, DIE_ICON, upright over it -- ICON of the
-- diamond's side, as on the card's roll buttons -- or a "D"). The panel
-- itself (bottle_<n>) turns dark red while the check must be taken; a left
-- click on "Bottle Check" (bottleHead_<n>) switches that by hand. Every
-- diamond is a turned button with a plain Text over it (a turned button's
-- label would turn with it).
local BOTTLE = {
    due   = {},             -- gang (BOTTLE.key) -> "due" (to take: lit) or "done", this turn
    hand  = {},             -- per side: an Ld set by hand (nil: the gang's best)
    seen  = {},             -- per side: the model last found on its victory points plate
    D = 40, GAP = 10,       -- the diamonds: side, and tip to tip apart (panel units)
    ICON  = 0.78,           -- the die's size, a fraction of a diamond's side (the card's LAY.dieIcon)
    LD_W = 26, LD_GAP = 8,  -- "Ld": about how wide, and how far from the first diamond's tip
    PLAIN = "#293133E6",
    LIT   = "#7A2020D9",    -- a check to take (the Clear All Conditions red)
    HAND  = "#F0C060",      -- an Ld set by hand
    UP    = "#6EE07A",      -- an Ld the gang's Iron Will raises (the card's green for a better value)
    TOP   = 0.25,           -- this object's top, in its own space: where models on the plates stand
}
local function bottleXml(n)
    local W, d = (ROW_W - 6) / 2, BOTTLE.D
    local step, y = d * math.sqrt(2) + BOTTLE.GAP, -18
    local function dia(id, i, label, fn, ink)
        local x = (i - 1.5) * step                          -- the two centred in the panel
        return string.format(
            '<Button id="%s_%d" rectAlignment="MiddleCenter" offsetXY="%g %g" width="%d" height="%d" rotation="0 0 45"' ..
            ' colors="%s" outline="#E6E5E159" outlineSize="1 1" onClick="%s" />' ..
            '<Text id="%sTxt_%d" rectAlignment="MiddleCenter" offsetXY="%g %g" width="%d" height="%d" fontSize="20"' ..
            ' fontStyle="Bold" color="%s" raycastTarget="false">%s</Text>',
            id, n, x, y, d, d, WASH, fn, id, n, x, y, d, d, ink or PALE, label)
    end
    -- the roll diamond: the die over it, its Text empty (kept, for the "D")
    local function die()
        if DIE_ICON == "" then return dia("bottleRoll", 2, "D", "onBottleRoll") end
        local s = d * BOTTLE.ICON
        return dia("bottleRoll", 2, "", "onBottleRoll") .. string.format(
            '<Image id="bottleRollIcon_%d" rectAlignment="MiddleCenter" offsetXY="%g %g" width="%g" height="%g"' ..
            ' image="mundaneDie" raycastTarget="false" />', n, 0.5 * step, y, s, s)
    end
    local v, will = BOTTLE.value(n)
    return string.format([[
          <Panel id="bottle_%d" preferredWidth="%g" color="%s" outline="#29313366" outlineSize="2 2" padding="3 3 3 3">
            <Panel color="#00000000" outline="#E6E5E159" outlineSize="1 1">
              <Button id="bottleHead_%d" rectAlignment="UpperCenter" offsetXY="0 -6" width="%g" height="28"
                      colors="#00000000|#FFFFFF14|#FFFFFF26|#00000000" outline="#00000000" onClick="onBottleHead" />
              <Text rectAlignment="UpperCenter" offsetXY="0 -6" width="%g" height="28" fontSize="20" fontStyle="Bold"
                    color="%s" raycastTarget="false">Bottle Check</Text>
              <Text rectAlignment="MiddleCenter" offsetXY="%g %g" width="40" height="%d" fontSize="22" fontStyle="Bold"
                    color="%s" raycastTarget="false">Ld</Text>
              %s%s
            </Panel>
          </Panel>]], n, W, BOTTLE.color(n), n, W - 20, W - 20, PALE,
        -step / 2 - d * math.sqrt(2) / 2 - BOTTLE.LD_GAP - BOTTLE.LD_W / 2, y, d, PALE,
        dia("bottleVal", 1, v and tostring(v) or "-", "onBottleValue", BOTTLE.ink(n, will)), die())
end

-- The play section, under the header: two slim bars of buttons ("Clear
-- All Conditions", "Reset all Fighters" and "Homebrew Rules", then "Roll Dice", "Roll Firepower"
-- and "Roll Injuries": a die under the panel per click, quick clicks
-- gathered into one roll -- see DICE.click), then the turn in a framed
-- plate between the two players' victory points -- before the game the
-- setup's buttons (SETUP), Start Game first; from turn 1 "Turn" over the
-- number (the panel turnView), and clicking it advances the turn (every fighter
-- readied; a right click steps it back, below turn 1 to the setup) -- and
-- under them each player's gang name (nameXml) over their Bottle Check
-- (bottleXml).
local function playXml()
    return string.format([[
      <VerticalLayout id="playSection" preferredHeight="%d" spacing="6" childForceExpandHeight="false">
        <HorizontalLayout preferredHeight="%d" spacing="6">
          <Button id="clearConditions" fontSize="15" colors="%s" textColor="%s" onClick="onClearConditions">Clear All Conditions</Button>
          <Button id="resetFighters" fontSize="15" colors="%s" textColor="%s" onClick="onResetFighters">%s</Button>
          <Button id="homebrewBtn" fontSize="15" colors="%s" textColor="%s" onClick="onHomebrewOpen">%s</Button>
        </HorizontalLayout>
        <HorizontalLayout preferredHeight="%d" spacing="6">
          <Button id="rollDiceBtn" fontSize="15" colors="%s" textColor="%s" onClick="onRollDiceBtn">Roll Dice</Button>
          <Button id="rollFirepowerBtn" fontSize="15" colors="%s" textColor="%s" onClick="onRollFirepowerBtn">Roll Firepower</Button>
          <Button id="rollInjuriesBtn" fontSize="15" colors="%s" textColor="%s" onClick="onRollInjuriesBtn">Roll Injuries</Button>
        </HorizontalLayout>
        <HorizontalLayout preferredHeight="%d" spacing="6" childForceExpandWidth="false">
%s
          <Panel preferredWidth="%d" color="%s" outline="#29313366" outlineSize="2 2" padding="3 3 3 3">
            <Panel color="#00000000" outline="#E6E5E159" outlineSize="1 1">
              <Panel id="turnView" active="%s" rectAlignment="MiddleCenter" width="%d" height="%d" color="#00000000">
                %s
                <Text id="turnCaption" rectAlignment="MiddleCenter" offsetXY="0 90" width="%d" height="70"
                      fontSize="51" fontStyle="Bold" color="%s" raycastTarget="false">Round</Text>
                <Text id="turnText" rectAlignment="MiddleCenter" offsetXY="0 -20" width="%d" height="170"
                      fontSize="150" fontStyle="Bold" color="%s" raycastTarget="false">%s</Text>
                %s
              </Panel>
              %s
            </Panel>
          </Panel>
%s
        </HorizontalLayout>
        <HorizontalLayout preferredHeight="%d" spacing="6" childForceExpandWidth="false">
%s
%s
        </HorizontalLayout>
        <HorizontalLayout preferredHeight="%d" spacing="6" childForceExpandWidth="false">
%s
%s
        </HorizontalLayout>
      </VerticalLayout>]], PLAY_H, BAR_H, LIT, PALE, RED, PALE, RESET.LABEL, LIT, PALE, HOMEBREW.button(), BAR_H, LIT, PALE, LIT, PALE, LIT, PALE,
        VP_ROW_H, vpXml(1), SETUP.W, LIT, tostring(turn >= 1), SETUP.W - 6, VP_ROW_H - 6,
        plateButton("turnBtn", "onAdvanceTurn"), SETUP.W - 30, PALE, SETUP.W - 30, PALE, tostring(turn), SETUP.noteXml(),
        SETUP.xml(), vpXml(2), NAME_H, nameXml(1), nameXml(2), BOTTLE_H, bottleXml(1), bottleXml(2))
end

-- A homebrew set's name or description as a Text shows it (see HOMEBREW).
local function hbText(s)
    return (tostring(s or ""):gsub("&", "and"):gsub("[<>]", ""))
end

-- Radio button `k` of a set (1: the rules as written, 2: the set's) as it
-- looks on the page: lit, "● ...", while it is the page's choice (see
-- HOMEBREW.pick), else washed, "○ ..." -- its colours, ink and label --
-- and the description under the set: what the chosen one does.
local function hbLook(set, k)
    local on = HOMEBREW.pick[set.id] == true
    local chosen = on == (k == 2)
    return chosen and LIT or WASH, chosen and PALE or INK,
           (chosen and "● " or "○ ") .. hbText(k == 2 and set.name or set.off),
           hbText(on and set.desc or set.offDesc)
end

-- The Homebrew Rules page, in the play section's place (hidden until the
-- main page's button opens it): its heading with Back, a rule, and for
-- each set its two radio buttons (hbOpt_<i>_1: as written, hbOpt_<i>_2:
-- the set's) over its description (hbDesc_<i>), then -- at the bottom,
-- the room left between -- Apply selected Rules to all Models (homebrewApply).
local function homebrewXml()
    local rows, n = {}, #HOMEBREW.SETS
    for i, set in ipairs(HOMEBREW.SETS) do
        local c1, i1, l1, desc = hbLook(set, 1)
        local c2, i2, l2 = hbLook(set, 2)
        -- a line between two sets
        rows[i] = (i > 1 and string.format('        <Image preferredHeight="%d" color="#29313366" />\n', HOMEBREW.SEP_H)
            or "") .. string.format([[
        <HorizontalLayout preferredHeight="%d" spacing="6">
          <Button id="hbOpt_%d_1" fontSize="15" colors="%s" textColor="%s" onClick="onHomebrewOption">%s</Button>
          <Button id="hbOpt_%d_2" fontSize="15" colors="%s" textColor="%s" onClick="onHomebrewOption">%s</Button>
        </HorizontalLayout>
        <Panel preferredHeight="%d" color="#00000000">
          <Text id="hbDesc_%d" width="%d" height="%d" fontSize="13" fontStyle="Bold" alignment="MiddleLeft"
                horizontalOverflow="Wrap" raycastTarget="false">%s</Text>
        </Panel>]], HB_ROW_H, i, c1, i1, l1, i, c2, i2, l2, HB_DESC_H, i, ROW_W - 4, HB_DESC_H,
            desc)
    end
    -- the room left: the page less its heading, rule, rows, the lines
    -- between them and Apply, and the 6 between each two of them
    local spare = math.max(0, PLAY_H - HB_HEAD_H - 3 - n * (HB_ROW_H + HB_DESC_H) - (n - 1) * HOMEBREW.SEP_H
        - HB_APPLY_H - 6 * (3 * n + 2))
    local ac, ai = HOMEBREW.applyLook()
    return string.format([[
      <VerticalLayout id="homebrewPage" active="%s" preferredHeight="%d" spacing="6" childForceExpandHeight="false">
        <HorizontalLayout preferredHeight="%d" spacing="6" childForceExpandWidth="false">
          <Panel preferredWidth="%d" color="#00000000">
            <Text width="%d" height="%d" fontSize="18" fontStyle="Bold" alignment="MiddleLeft">Homebrew Rules</Text>
          </Panel>
          <Button id="homebrewBack" preferredWidth="110" fontSize="15" onClick="onHomebrewBack">Back</Button>
        </HorizontalLayout>
        <Image preferredHeight="3" color="#29313399" />
%s
        <Panel preferredHeight="%d" color="#00000000" />
        <Button id="homebrewApply" preferredHeight="%d" fontSize="18" colors="%s" textColor="%s"
                onClick="onHomebrewApply">Apply selected Rules to all Models</Button>
      </VerticalLayout>]], tostring(HOMEBREW.page), PLAY_H, HB_HEAD_H, ROW_W - 116, ROW_W - 116, HB_HEAD_H,
        table.concat(rows, "\n"), spare, HB_APPLY_H, ac, ai)
end

-- The whole panel (see panelShell): the play section under the header --
-- or, in its place, the Homebrew Rules page.
local function panelXml()
    return panelShell({ id = "controllerPanel", position = PANEL.position, rotation = PANEL.rotation,
        scale = PANEL.scale, width = PANEL_W, height = PANEL_H, title = CONTROLLER_NAME,
        version = VERSION, body = playXml() .. "\n" .. homebrewXml() })
end

-- The picture behind the panel, and the Bottle Check's die, as the
-- panel's own UI assets.
local function panelAssets()
    local out = { { name = "mundanePanelBg", url = PANEL_BG } }
    if DIE_ICON ~= "" then out[#out + 1] = { name = "mundaneDie", url = DIE_ICON } end
    return out
end

-- A player's victory points, clicking their plate: left click one up,
-- right click one down (never below 0).
function onVp(player, value, id)
    local n = tonumber(tostring(id or ""):match("^vpBtn_(%d)$"))
    if not (n and vp[n]) then return end
    vp[n] = math.max(0, vp[n] + (tostring(value) == "-2" and -1 or 1))
    setLabel("vpText_" .. n, tostring(vp[n]))
end

-- A player's name typed in -- the gang whose Bottle Check that side shows
-- (a model put on the plate types it in, see BOTTLE.tick).
function onVpName(player, value, id)
    local n = tonumber(tostring(id or ""):match("^vpName_(%d)$"))
    if n and vpNames[n] then
        vpNames[n] = trim(tostring(value or ""))
        BOTTLE.hand[n] = nil
        BOTTLE.draw(n)
        SETUP.drawAll()
    end
end

-- ── The Bottle Check ─────────────────────────────────────────────
-- A gang with a fighter taken Out of Action this turn must take one: the
-- fighter's card tells this object (onFighterOut), and that gang's panel
-- -- the side whose name is the gang's -- glows until the check is rolled
-- or the turn changes; once a turn. It is taken on 2D6
-- against the best Ld of the gang's fighters still on the table (not Out
-- of Action), Loners left out unless every one is a Loner -- one higher
-- for each of them with the Iron Will skill, the number then green. A
-- player puts one of their gang's models on their victory points plate to
-- name their side after the gang.

-- A gang's name as the check compares it: trimmed, any case.
function BOTTLE.key(name) return trim(tostring(name or "")):lower() end

-- A model's gang name: its gang tag without the tag's prefix (nil: none).
function BOTTLE.gangName(obj)
    local tag = gangOf(obj)
    if not tag then return nil end
    for _, pre in ipairs({ GANG_TAG, OLD_TAGS[1], OLD_TAGS[2] }) do
        if tag:sub(1, #pre) == pre then return tag:sub(#pre + 1) end
    end
    return tag
end

-- The fighters of gang `name` on the table, each { name, ld, loner, will }
-- as its card tells it (engageInfo; an older card's Ld read from
-- getFighter) -- those Out of Action left out. `will`: what its Iron Will
-- adds to the number the check is taken against.
function BOTTLE.fighters(name)
    local key, out = BOTTLE.key(name), {}
    if key == "" then return out end
    for _, obj in ipairs(getAllObjects()) do
        if IMPORT_TAG ~= "" and obj.hasTag(IMPORT_TAG) and BOTTLE.key(BOTTLE.gangName(obj)) == key then
            local ok, info = callIfHas(obj, "engageInfo")
            info = ok and type(info) == "table" and info or {}
            local ld, gone = tonumber(info.ld), info.out
            if not ld then
                local okF, f = callIfHas(obj, "getFighter")
                if okF and type(f) == "table" then
                    ld = tonumber(tostring((f.stats or {}).Ld or ""):match("%d+"))
                    gone = gone or f.outOfAction
                end
            end
            if not gone and (ld or info.name) then
                out[#out + 1] = { name = info.name or obj.getName(), ld = ld, loner = info.loner == true,
                                  will = tonumber(info.ironWill) or 0 }
            end
        end
    end
    return out
end

-- The Ld a Bottle Check is taken against for fighters `list`: the highest
-- of those that aren't Loners -- of the Loners only when all are -- and
-- whose it is (nil: no Ld at all). And what Iron Will does for them: 1 is
-- taken off the check's roll for every fighter of theirs with the skill
-- (what each card says its Iron Will is worth, added up) -- the third
-- value back.
function BOTTLE.best(list)
    local all, will = true, 0
    for _, f in ipairs(list) do
        if not f.loner then all = false end
        will = will + (f.will or 0)
    end
    local best, who
    for _, f in ipairs(list) do
        if f.ld and (all or not f.loner) and (not best or f.ld > best) then best, who = f.ld, f.name end
    end
    return best, who, will
end

-- What gang `name`'s Bottle Check is taken against, as things stand: its
-- best Ld and, since taking Iron Will's off the roll comes to the same,
-- that much added to it (12 at most: 2D6 never roll more). Returns the
-- number (nil: no Ld at all), how much of it is Iron Will's, and whose Ld
-- it is, for chat ("Boss's Ld", "Boss's Ld 8 +1 Iron Will").
function BOTTLE.target(name)
    local best, who, will = BOTTLE.best(BOTTLE.fighters(name))
    if not best then return nil, 0, nil end
    local target = math.min(12, best + will)
    will = target - best
    who = who and (who .. "'s Ld") or "Ld"
    if will > 0 then who = string.format("%s %d +%d Iron Will", who, best, will) end
    return target, will, who
end

-- The number side `n` shows: set by hand, else its gang's (BOTTLE.target)
-- -- and how much of it is Iron Will's (none of one set by hand).
function BOTTLE.value(n)
    if BOTTLE.hand[n] then return BOTTLE.hand[n], 0 end
    local target, will = BOTTLE.target(vpNames[n])
    return target, will
end

-- The colour side `n`'s number shows in: one set by hand in its own, one
-- Iron Will raises (by `will`) green, else plain.
function BOTTLE.ink(n, will)
    return BOTTLE.hand[n] and BOTTLE.HAND or (will or 0) > 0 and BOTTLE.UP or PALE
end

-- Whether side `n`'s check must be taken (its panel glows), and its colour.
function BOTTLE.lit(n)
    local key = BOTTLE.key(vpNames[n])
    return key ~= "" and BOTTLE.due[key] == "due"
end
function BOTTLE.color(n)
    return BOTTLE.lit(n) and BOTTLE.LIT or BOTTLE.PLAIN
end

-- Whether side `n` has a name of its own (not the "Player <n>" it starts
-- with, nor empty).
function BOTTLE.named(n)
    local key = BOTTLE.key(vpNames[n])
    return key ~= "" and key ~= ("player " .. n)
end

-- Side `n`'s panel redrawn: its glow and its Ld.
function BOTTLE.draw(n)
    self.UI.setAttribute("bottle_" .. n, "color", BOTTLE.color(n))
    local v, will = BOTTLE.value(n)
    setLabel("bottleValTxt_" .. n, v and tostring(v) or "-")
    self.UI.setAttribute("bottleValTxt_" .. n, "color", BOTTLE.ink(n, will))
end

-- A new turn (either way): no check to take any more, nothing set by hand.
function BOTTLE.newTurn()
    BOTTLE.due, BOTTLE.hand = {}, {}
    for n = 1, 2 do BOTTLE.draw(n) end
end

-- Where a part of the play section lies on this object, in its local x / z,
-- worked out from the layout (panelXml / playXml) and PANEL through
-- panelLocal: side `n`'s
-- victory points plate (`what` "vp", with its size), its gang name and
-- Bottle Check ("bottle") or, for "line", the middle of the line the dice
-- fall in, DICE.BELOW under the panel (any `n`).
function BOTTLE.spot(n, what)
    local sc = {}
    for v in tostring(PANEL.scale):gmatch("%-?[%d%.]+") do sc[#sc + 1] = tonumber(v) end
    local side = n == 1 and -1 or 1
    local rowTop = PANEL_H / 2 - 3 - 9 - 40 - 6 - 2 * (BAR_H + 6)   -- the victory points row's top
    local x, y, w, h = side * (ROW_W / 2 - 65), rowTop - VP_ROW_H / 2, 130, VP_ROW_H
    if what == "bottle" then       -- the gang's name and its Bottle Check under it
        x, y, w, h = side * (ROW_W + 6) / 4, rowTop - VP_ROW_H - 6 - (NAME_H + 6 + BOTTLE_H) / 2,
            (ROW_W - 6) / 2, NAME_H + 6 + BOTTLE_H
    end
    if what == "line" then
        x, y = 0, -PANEL_H / 2 - DICE.BELOW
    end
    local sx, sy = sc[1] or 1, sc[2] or 1
    local lx, lz = panelLocal(PANEL, x, y)
    return lx, lz, w * sx / 100, h * sy / 100
end

-- The first model with a gang tag standing on side `n`'s victory points
-- plate or its gang name / Bottle Check (nil: none).
function BOTTLE.modelOn(n)
    return BOTTLE.modelAt(n, "vp") or BOTTLE.modelAt(n, "bottle")
end
function BOTTLE.modelAt(n, what)
    if not (Physics and Physics.cast and self.positionToWorld) then return nil end
    local x, z, w, h = BOTTLE.spot(n, what)
    local p = self.positionToWorld({ x, BOTTLE.TOP, z })
    local okS, sc = pcall(function() return self.getScale() end)
    sc = okS and type(sc) == "table" and sc or {}
    local okR, rot = pcall(function() return self.getRotation() end)
    local hits = Physics.cast({ origin = { p.x, p.y + 1.5, p.z }, direction = { 0, 1, 0 }, type = 3,
        size = { w * (sc.x or 1), 3, h * (sc.z or 1) }, orientation = okR and rot or nil, max_distance = 0 }) or {}
    for _, hit in ipairs(hits) do
        local o = hit.hit_object
        if o and o ~= self and BOTTLE.gangName(o) then return o end
    end
end

-- Half a second after anything on the table is picked up, put down or
-- removed (BOTTLE.soon), and every BOTTLE.POLL seconds besides: a model
-- newly put on a victory points plate names that side after its gang (said
-- in chat, the model flashed) -- not while the Homebrew Rules page hides
-- the plates. Looking only when something moved spares a slow machine the
-- plates' physics casts twice a second all game.
function BOTTLE.tick()
    if HOMEBREW.page then return end      -- the plates are hidden behind the Homebrew Rules page
    for n = 1, 2 do
        local o = BOTTLE.modelOn(n)
        if o ~= BOTTLE.seen[n] then
            BOTTLE.seen[n] = o
            local g = o and BOTTLE.gangName(o)
            if g then
                vpNames[n] = g
                self.UI.setAttribute("vpName_" .. n, "text", g)
                SETUP.drawAll()
                pcall(function() o.highlightOn({ 0.9, 0.8, 0.4 }, 1) end)
                printToAll(string.format("%s%s play on the %s.", CHAT_PREFIX, g, n == 1 and "left" or "right"),
                    { 0.9, 0.8, 0.4 })
                BOTTLE.hand[n] = nil
                BOTTLE.draw(n)
            end
        end
    end
end

BOTTLE.POLL, BOTTLE.soonToken = 2, 0
function BOTTLE.soon()
    BOTTLE.soonToken = BOTTLE.soonToken + 1
    local token = BOTTLE.soonToken
    Wait.time(function() if token == BOTTLE.soonToken then BOTTLE.tick() end end, 0.5)
end
function onObjectDrop() BOTTLE.soon() end
function onObjectPickUp() BOTTLE.soon() end
function onObjectDestroy() BOTTLE.soon() end

-- The Bottle Check's two D6, thrown in the dice's line under the panel
-- (see DICE), then done(faces, digital) -- in the order thrown.
function BOTTLE.throw(n, color, done)
    DICE.request({ kinds = { "d6", "d6" }, color = color, done = done })
end

-- ── The dice ─────────────────────────────────────────────────────
-- Every roll falls in one line under the panel (see DICE): a card's (see
-- throwDice), a Bottle Check's, the Roll Dice / Firepower / Injuries
-- buttons'.
-- A roll: { kinds = { "d6", "firepower", ... }, color = the roller's, and
-- who hears of it: done(faces, digital, dice) and / or a card (from = its
-- GUID, token), or -- own, the buttons' -- said on everyone's screen;
-- apart = its dice fall in a row in the order thrown, that far apart, and
-- lie so (none: they fall from the middle out, and lie STEP apart);
-- inOrder = never lined up by SORT }.
-- DICE.busy is the roll falling now, DICE.queue the rolls waiting for it,
-- DICE.shown the last roll's dice, lined up; DICE.open the buttons' roll
-- still gathering clicks. The tokens let a newer wait win over an older one.
DICE.busy, DICE.queue, DICE.shown, DICE.open = nil, {}, {}, nil
DICE.joinToken = 0
DICE.ORDER = { d6 = 1, firepower = 2, injury = 3 }   -- mixed kinds line up in this order

-- Throws roll `req` now, or once the one falling has been lined up.
function DICE.request(req)
    if DICE.busy or #DICE.queue > 0 then DICE.queue[#DICE.queue + 1] = req else DICE.start(req) end
end

-- The line the dice fall in: its middle in the world, and the way it runs
-- (the panel's x, flat, one world unit long) -- nil outside TTS.
function DICE.line()
    if not self.positionToWorld then return nil end
    local x, z = BOTTLE.spot(1, "line")
    local ox, oz = panelLocal(PANEL, 0, 0)
    local rx, rz = panelLocal(PANEL, 100, 0)              -- the panel's x, one local unit
    local ok, a, b = pcall(function()
        return self.positionToWorld({ x, 0, z }), self.positionToWorld({ x + rx - ox, 0, z + rz - oz })
    end)
    if not (ok and a and b) then return nil end
    local ax, ay, az = a.x or a[1], a.y or a[2], a.z or a[3]
    local dx, dz = (b.x or b[1]) - ax, (b.z or b[3]) - az
    local len = math.sqrt(dx * dx + dz * dz)
    if len < 1e-6 then dx, dz, len = 1, 0, 1 end
    return { x = ax, y = ay, z = az }, { x = dx / len, z = dz / len }
end

-- A roll begins: the last roll's dice go, and its dice fall (one each of
-- req.kinds) -- or, outside TTS, its faces are rolled digitally at once.
function DICE.start(req)
    DICE.clear()
    DICE.busy, req.dice = req, {}
    req.mid, req.dir = DICE.line()
    local real = req.mid ~= nil and spawnObject ~= nil and Wait ~= nil and Wait.condition ~= nil
    for _, kind in ipairs(req.kinds) do
        if real then DICE.spawn(req, kind) else req.dice[#req.dice + 1] = { kind = kind } end
    end
    if not real then return DICE.finish(req) end
    Wait.condition(function() DICE.finish(req) end, function() return req.finished or DICE.settled(req) end,
        DICE.WAIT, function() DICE.finish(req) end)
end

-- One die of `kind` for roll `req`: dropped from DICE.DROP over the line --
-- the first in its middle, the others either side in turn (0, +1, -1, +2
-- ... steps, a little off), so dice a click adds don't drift one way --
-- turned any way and spinning: the custom dice's art when its URL is set,
-- else TTS's own D6 in a light shade of the roller's colour.
function DICE.spawn(req, kind)
    local i = #req.dice + 1
    local k = i - 1
    local off = (k % 2 == 1 and 1 or -1) * math.ceil(k / 2) * DICE.STEP + (math.random() - 0.5) * 0.3
    if req.apart then off = (k - (#req.kinds - 1) / 2) * req.apart end   -- in a row, in order, that far apart
    local m, d, url, s = req.mid, req.dir, DICE.URL[kind] or "", DICE.SCALE
    -- the roll's entry: where it spawned and, once spawned, its kick (see
    -- DICE.settled)
    local entry = { kind = kind, from = { x = m.x + d.x * off, y = m.y + DICE.DROP, z = m.z + d.z * off } }
    req.dice[i] = entry
    local ok, o = pcall(spawnObject, {
        type = url ~= "" and "Custom_Dice" or DICE.PLAIN,
        position = { entry.from.x, entry.from.y, entry.from.z },
        rotation = { math.random(0, 359), math.random(0, 359), math.random(0, 359) },
        scale = { s, s, s },
        callback_function = function(obj)
            pcall(function()
                obj.setName(DICE.NAMES[kind] or "D6")
                obj.addTag(DICE.TAG)
                if url == "" and req.color and stringColorToRGB then
                    local c = stringColorToRGB(req.color)
                    obj.setColorTint({ 0.45 + 0.55 * c.r, 0.45 + 0.55 * c.g, 0.45 + 0.55 * c.b })
                end
                -- tumbling about every axis (at least half of SPIN each
                -- way, so none just drops flat) ...
                local function turn() return (math.random() * 0.5 + 0.5) * DICE.SPIN * (math.random() < 0.5 and -1 or 1) end
                local av = { turn(), turn(), turn() }
                -- ... and pushed up to PUSH sideways, any way (the row is
                -- lined up afterwards anyway), so it rolls on when it lands.
                local a, v = math.random() * 2 * math.pi, (math.random() * 0.5 + 0.5) * DICE.PUSH
                local function go()
                    pcall(function()
                        if obj.isDestroyed and obj.isDestroyed() then return end
                        obj.setAngularVelocity(av)
                        if v > 0 then
                            local ok, now = pcall(function() return obj.getVelocity() end)
                            local fall = ok and type(now) == "table" and tonumber(now.y or now[2]) or 0
                            obj.setVelocity({ v * math.cos(a), fall, v * math.sin(a) })
                        end
                    end)
                end
                -- set now and again two frames on: TTS may still be finishing
                -- the spawn, and a velocity set then can be lost (the die just
                -- drops, showing the face it spawned with) -- and kept, to
                -- give again (DICE.settled)
                entry.kick = go
                go()
                if Wait and Wait.frames then Wait.frames(go, 2) end
            end)
        end,
    })
    if ok and o and url ~= "" then pcall(function() o.setCustomObject({ image = url, type = 1 }) end) end
    entry.obj = ok and o or nil
end

-- Whether roll `req` can be read: every die fallen and at rest again (one
-- taken off the table meanwhile doesn't count). Called every frame until
-- then. TTS can hold a fresh die still in mid-air for a moment, calling it
-- resting all the while -- read then, the roll would come back at once
-- with the faces the dice spawned with. So a die is down only once it has
-- moved FALL from its spawn point and rests; until it falls it is kicked
-- again every KICK frames, and once more as it starts to fall, so it
-- tumbles on the way down.
function DICE.settled(req)
    local all = true                               -- every die looked at: each is kicked as needed
    for _, d in ipairs(req.dice) do
        if d.obj then
            local ok, down = pcall(function()
                if d.obj.isDestroyed() then return true end
                if d.obj.spawning or not d.kick then return false end
                if not d.fell then
                    local p = d.obj.getPosition()
                    local x, y, z = tonumber(p.x or p[1]), tonumber(p.y or p[2]), tonumber(p.z or p[3])
                    local f = d.from
                    if (x - f.x) ^ 2 + (y - f.y) ^ 2 + (z - f.z) ^ 2 < DICE.FALL ^ 2 then
                        d.waited = (d.waited or 0) + 1
                        if d.waited % DICE.KICK == 0 then d.kick() end
                        return false
                    end
                    d.fell = true
                    d.kick()
                    return false
                end
                return d.obj.resting == true
            end)
            if not (ok and down) then all = false end
        end
    end
    return all
end

-- Roll `req` has settled (or waited long enough): each die read as it lies
-- (rolled digitally if it can't be), lined up (by SORT), handed to whoever
-- asked in the order thrown -- the roll's order is kept on the card and in
-- chat -- then the next roll waiting, if any.
function DICE.finish(req)
    if req.finished then return end
    req.finished = true
    local list = {}
    for i, d in ipairs(req.dice) do
        local face
        if d.obj then
            local ok, v = pcall(function() return d.obj.getValue() end)
            face = ok and tonumber(v) or nil
        end
        d.face, d.digital, d.at = face or math.random(1, 6), face == nil, i
        list[i] = d
    end
    local thrown = {}
    for i, d in ipairs(list) do thrown[i] = d end
    if DICE.SORT ~= "thrown" and not req.inOrder then
        table.sort(list, function(a, b)
            local ka, kb = DICE.ORDER[a.kind] or 9, DICE.ORDER[b.kind] or 9
            if ka ~= kb then return ka < kb end
            if a.face ~= b.face then
                if DICE.SORT == "down" then return a.face > b.face end
                return a.face < b.face
            end
            return a.at < b.at
        end)
    end
    DICE.lineUp(req, list)
    DICE.shown, DICE.busy = list, nil
    DICE.deliver(req, thrown)
    DICE.next()
end

-- The dice of `list` moved into a row along the line, in its order, STEP
-- apart and at the height the lowest came to rest at, each with its face
-- up and all turned alike (DICE.faceUp) -- then locked.
function DICE.lineUp(req, list)
    if not req.mid then return end
    local low
    for _, d in ipairs(list) do
        local ok, p = pcall(function() return d.obj.getPosition() end)
        local y = ok and p and tonumber(p.y or p[2])
        if y then low = math.min(low or y, y) end
    end
    local okR, r = pcall(function() return self.getRotation() end)
    local yaw = (okR and r and tonumber(r.y or r[2])) or 0
    local n, m, dir = #list, req.mid, req.dir
    for i, d in ipairs(list) do
        if d.obj then
            local off = (i - (n + 1) / 2) * (req.apart or DICE.STEP)
            pcall(function()
                d.obj.setPositionSmooth({ m.x + dir.x * off, low or m.y + 1, m.z + dir.z * off }, false, true)
                local rot = DICE.faceUp(d.obj, d.face, yaw + (DICE.TURN[d.kind] or 0))
                if rot then d.obj.setRotationSmooth(rot, false, true) end
            end)
        end
    end
    Wait.time(function()
        for _, d in ipairs(list) do
            if d.obj then pcall(function() if not d.obj.isDestroyed() then d.obj.setLock(true) end end) end
        end
    end, 1.5)
end

-- The rotation that shows face `face` of die `o` up (its rotation values),
-- turned `yaw` degrees -- or nil when TTS doesn't say.
function DICE.faceUp(o, face, yaw)
    local ok, rv = pcall(function() return o.getRotationValues() end)
    for _, r in ipairs(ok and type(rv) == "table" and rv or {}) do
        local rot = r.rotation
        if rot and tostring(r.value) == tostring(face) then
            return { rot.x or rot[1] or 0, ((rot.y or rot[2] or 0) + yaw) % 360, rot.z or rot[3] or 0 }
        end
    end
end

-- The faces, in the order they lie, to whoever asked for roll `req`: its
-- done function, the card that asked (onDiceThrown), or -- the buttons'
-- -- everyone, in chat.
function DICE.deliver(req, list)
    local faces, digital = {}, false
    for i, d in ipairs(list) do faces[i], digital = d.face, digital or d.digital end
    if req.done then req.done(faces, digital, list) end
    if req.from then
        local ok, o = pcall(getObjectFromGUID, req.from)
        if ok and o then
            callIfHas(o, "onDiceThrown", { token = req.token, faces = faces, digital = digital })
        end
    end
    if req.own then DICE.say(req, list, digital) end
end

-- This object's own rolls said on everyone's screen (and in chat).
function DICE.announce(msg, rgb)
    if broadcastToAll then broadcastToAll(msg, rgb) else printToAll(msg, rgb) end
end

-- The Injury dice's results as the chat names them (RULES.injury's short
-- names: Inj, S. Inj, OOA), and their ranks (1 the worst).
RULES.follow(function()
    DICE.INJURY, DICE.RANK = {}, {}
    for k, r in pairs(RULES.injury) do DICE.INJURY[k], DICE.RANK[k] = r.short or r.label, r.rank or 0 end
end)

-- The buttons' roll said on everyone's screen, in the roller's colour: the
-- D6 and their total, the Firepower dice (CHART) and their hits -- and
-- whether an Ammo check is due -- and the Injury dice's results, every
-- one and the best after them ("Inj, OOA = Inj"; no count of dice, no
-- faces).
function DICE.say(req, list, digital)
    local d6, fp, inj, total, hits, ammo, best = {}, {}, {}, 0, 0, false, nil
    for _, d in ipairs(list) do
        if d.kind == "firepower" then
            local f = DICE.CHART.firepower[d.face] or DICE.CHART.firepower[1]
            fp[#fp + 1] = string.format("%d hit%s%s", f.hits, f.hits == 1 and "" or "s", f.ammo and " + Ammo" or "")
            hits, ammo = hits + f.hits, ammo or f.ammo == true
        elseif d.kind == "injury" then
            local k = DICE.CHART.injury[d.face] or "serious"
            inj[#inj + 1] = DICE.INJURY[k]
            if not best or (DICE.RANK[k] or 0) > (DICE.RANK[best] or 0) then best = k end
        else
            d6[#d6 + 1], total = tostring(d.face), total + d.face
        end
    end
    local parts = {}
    if #d6 == 1 then parts[#parts + 1] = "a D6: " .. d6[1]
    elseif #d6 > 1 then parts[#parts + 1] = string.format("%dD6: %s = %d", #d6, table.concat(d6, " + "), total) end
    if #fp == 1 then
        parts[#parts + 1] = "the Firepower dice: " .. fp[1]:gsub(" %+ Ammo$", " + Ammo check")
    elseif #fp > 1 then
        parts[#parts + 1] = string.format("%d Firepower dice: %s = %d hits%s", #fp, table.concat(fp, ", "), hits,
            ammo and " -- Ammo check" or "")
    end
    if #inj > 0 then
        parts[#parts + 1] = "Injury dice: " .. table.concat(inj, ", ") .. (#inj > 1 and " = " .. DICE.INJURY[best] or "")
    end
    local rgb = { 0.9, 0.9, 0.9 }
    if req.color and stringColorToRGB then
        local ok, c = pcall(stringColorToRGB, req.color)
        if ok and c then rgb = c end
    end
    DICE.announce(string.format("%s%s rolls %s%s", CHAT_PREFIX, req.color or "Someone", table.concat(parts, "; "),
        digital and " (rolled digitally)" or ""), rgb)
end

-- The last roll's dice taken off the table as the next roll begins --
-- with any left lying from before a save (they carry DICE.TAG).
function DICE.clear()
    for _, d in ipairs(DICE.shown) do
        if d.obj then pcall(function() if not d.obj.isDestroyed() then d.obj.destruct() end end) end
    end
    DICE.shown = {}
    pcall(function() for _, o in ipairs(getObjectsWithTag(DICE.TAG)) do o.destruct() end end)
end

-- The next roll waiting, if any: thrown DICE.NEXT seconds after the last
-- was lined up, so that one can be seen (at once when nothing was thrown).
function DICE.next()
    if #DICE.queue == 0 then return end
    local function go()
        if DICE.busy or #DICE.queue == 0 then return end
        DICE.start(table.remove(DICE.queue, 1))
    end
    if DICE.shown[1] and DICE.shown[1].obj then Wait.time(go, DICE.NEXT) else go() end
end

-- A click on Roll Dice / Roll Firepower / Roll Injuries: one more die of
-- `kind` for the clicking player's roll while it is still gathering, else
-- a roll of its own (another player's gathering one is thrown first). It
-- is thrown -- all its dice at once -- when no click has come for
-- DICE.JOIN seconds.
function DICE.click(kind, player)
    local color = player and player.color or nil
    local req = DICE.open
    if req and req.color ~= color then
        DICE.open = nil
        DICE.request(req)
        req = nil
    end
    if req then
        if #req.kinds < DICE.MAX then req.kinds[#req.kinds + 1] = kind end
    else
        req = { kinds = { kind }, color = color, own = true }
        DICE.open = req
    end
    DICE.joinToken = DICE.joinToken + 1
    local t = DICE.joinToken
    Wait.time(function()
        if DICE.joinToken == t and DICE.open == req then
            DICE.open = nil
            DICE.request(req)
        end
    end, DICE.JOIN)
end

-- A fighter's card wants dice thrown (see its ACTIVATION.viaController): t
-- = { n, kind ("d6", "firepower", "injury"), color, label, from = the
-- card's GUID, token } -- or, for dice of several kinds (a weapon's
-- attack: its hit die, Firepower dice, the Ammo trait's die), `kinds`, one
-- die of each in the order thrown. They fall in the line like any roll;
-- the faces go back to the card's onDiceThrown, in the order thrown, once
-- they have settled. Returns true (taken).
function throwDice(t)
    t = type(t) == "table" and t or {}
    local kind = DICE.ORDER[t.kind] and t.kind or "d6"
    local kinds = {}
    if type(t.kinds) == "table" and #t.kinds > 0 then
        for i = 1, math.min(DICE.MAX, #t.kinds) do kinds[i] = DICE.ORDER[t.kinds[i]] and t.kinds[i] or "d6" end
    end
    for i = #kinds + 1, math.max(1, math.min(DICE.MAX, math.floor(tonumber(t.n) or 1))) do kinds[i] = kind end
    DICE.request({ kinds = kinds, color = t.color, label = t.label, from = t.from, token = t.token })
    return true
end

function onRollDiceBtn(player, value, id) DICE.click("d6", player) end
function onRollFirepowerBtn(player, value, id) DICE.click("firepower", player) end
function onRollInjuriesBtn(player, value, id) DICE.click("injury", player) end

-- A fighter's card: the fighter has gone Out of Action (t = { gang, name }),
-- or is back (t.back: revived). Its gang's Ld is looked at again either
-- way (one Out of Action doesn't count); going out, the gang must take a
-- Bottle Check this turn -- once, however many go.
function onFighterOut(t)
    t = type(t) == "table" and t or {}
    local gang = trim(tostring(t.gang or ""))
    local key = BOTTLE.key(gang)
    if key == "" then return end
    local due = not t.back and not BOTTLE.due[key]
    if due then BOTTLE.due[key] = "due" end
    local shown = false
    for n = 1, 2 do
        if BOTTLE.key(vpNames[n]) == key then shown = true; BOTTLE.draw(n) end
    end
    if not due then return end
    printToAll(string.format("[%s] %s is Out of Action: %s must take a Bottle Check this round.%s", gang,
        tostring(t.name or "A fighter"), gang,
        shown and "" or " Put one of its models on a Victory Points plate of the Mundane Controller."), { 1, 0.55, 0.2 })
end

-- "Bottle Check" over a side's diamonds, left click: the reminder that its
-- gang must take the check switched by hand -- on, or off when it was lit
-- by mistake (then a fighter going Out of Action later this turn lights it
-- again). Said in chat. A side without a gang yet asks for one, as the die
-- does.
function onBottleHead(player, value, id)
    local n = tonumber(tostring(id or ""):match("_(%d)$"))
    if not n or tostring(value) == "-2" or tostring(value) == "-3" then return end
    if not BOTTLE.named(n) then
        broadcastToAll(string.format("%sBottle Check: no gang on the %s yet -- put one of your gang's models on your " ..
            "Victory Points plate of the Mundane Controller.", CHAT_PREFIX, n == 1 and "left" or "right"), { 1, 0.55, 0.2 })
        return
    end
    local key = BOTTLE.key(vpNames[n])
    local on = BOTTLE.due[key] ~= "due"
    BOTTLE.due[key] = on and "due" or nil
    for m = 1, 2 do
        if BOTTLE.key(vpNames[m]) == key then BOTTLE.draw(m) end
    end
    printToAll(string.format("%sBottle Check for %s %s (set by hand)", CHAT_PREFIX, vpNames[n],
        on and "to take this round" or "no longer to take"), { 1, 0.55, 0.2 })
    return on
end

-- The Ld diamond: left click one more, right click one fewer (by hand).
function onBottleValue(player, value, id)
    local n = tonumber(tostring(id or ""):match("_(%d)$"))
    if not n then return end
    local v = BOTTLE.value(n) or 7
    BOTTLE.hand[n] = math.max(2, math.min(12, v + (tostring(value) == "-2" and -1 or 1)))
    BOTTLE.draw(n)
end

-- The die: the Bottle Check rolled, 2D6 at or under the Ld shown -- a
-- fail means one model of the gang must leave the battlefield, two on a
-- natural 12. Taken once the dice have settled; said in chat. A side still
-- without a name of its own ("Player <n>") only asks, on everyone's
-- screen, for one of the gang's models on its plate; a named one with no
-- Ld to go by (none of its fighters on the table, none set by hand) still
-- rolls, the total said without a verdict.
function onBottleRoll(player, value, id)
    local n = tonumber(tostring(id or ""):match("_(%d)$"))
    if not n then return end
    if not BOTTLE.named(n) then
        broadcastToAll(string.format("%sBottle Check: no gang on the %s yet -- put one of your gang's models on your " ..
            "Victory Points plate of the Mundane Controller.", CHAT_PREFIX, n == 1 and "left" or "right"), { 1, 0.55, 0.2 })
        return
    end
    local gang = vpNames[n]
    local target, who = BOTTLE.hand[n], "set by hand"
    if not target then
        local _
        target, _, who = BOTTLE.target(gang)
    end
    local key = BOTTLE.key(gang)
    if BOTTLE.due[key] == "due" then BOTTLE.due[key] = "done" end
    BOTTLE.draw(n)
    local color = player and player.color or nil
    BOTTLE.throw(n, color, function(faces, digital)
        local total = faces[1] + faces[2]
        local verdict
        if not target then
            verdict = "no Ld to test against (set one on the Ld diamond)"
        elseif total <= target then
            verdict = string.format("needs %d or less%s: PASS -- the gang holds its nerve",
                target, who and (" (" .. who .. ")") or "")
        else
            verdict = string.format("needs %d or less%s: FAIL%s -- %s of %s must leave the battlefield",
                target, who and (" (" .. who .. ")") or "", total == 12 and " (a natural 12)" or "",
                total == 12 and "2 models" or "1 model", gang)
        end
        DICE.announce(string.format("[%s] Bottle Check (2D6): %d + %d = %d, %s%s", gang, faces[1], faces[2], total,
            verdict, digital and " (rolled digitally)" or ""),
            (target and total <= target) and { 0.3, 1, 0.4 } or { 1, 0.35, 0.3 })
    end)
end

-- Calls `fn` on every fighter's card on the table (every model an import
-- tagged) that has it. Cards older than the Mundane Importer's are brought
-- up to date by it first (its upgradeCards) and left out -- they can take
-- the call once they have reloaded; with no importer on the table every
-- card that has `fn` takes it as it is. Returns how many took it, and how
-- many were brought up to date.
local function everyFighter(fn, arg)
    local skip, updated = {}, 0
    local ok, importers = pcall(function() return getObjectsWithTag(IMPORTER_TAG) end)
    for _, imp in ipairs(ok and type(importers) == "table" and importers or {}) do
        local okU, list = callIfHas(imp, "upgradeCards")
        for _, guid in ipairs(okU and type(list) == "table" and list or {}) do
            if not skip[guid] then skip[guid], updated = true, updated + 1 end
        end
    end
    local done = 0
    for _, obj in ipairs(getAllObjects()) do
        if IMPORT_TAG ~= "" and obj.hasTag(IMPORT_TAG) and not skip[obj.getGUID()] then
            if callIfHas(obj, fn, arg) then done = done + 1 end
        end
    end
    return done, updated
end

local function updatedNote(n)
    return n > 0 and string.format(" (%d older card(s) brought up to date first -- press again for them)", n) or ""
end

-- The round plate redrawn in place for `turn` (the round): the setup's
-- buttons before round 1, the round from then on, with the reinforcements
-- reminder (font sizes scaled by PANEL_DETAIL like the built XML's).
local function drawTurn()
    self.UI.setAttribute("setupPanel", "active", tostring(turn < 1))
    self.UI.setAttribute("turnView", "active", tostring(turn >= 1))
    setLabel("turnText", tostring(turn))
    local text, size, on = SETUP.note()
    self.UI.setAttribute("roundNote", "active", tostring(on))
    self.UI.setAttribute("roundNote", "fontSize", string.format("%d", size * PANEL_DETAIL))
    setLabel("roundNote", text)
end

-- A click on the turn (or on the setup's Start Game): the counter on one
-- (Start Game -> turn 1) and every fighter readied -- at Start Game every
-- weapon's Reliable trait ready again too (the card's resetReliable). A
-- right click only steps the counter back, for a turn advanced by mistake
-- -- below turn 1 to the setup.
function onAdvanceTurn(player, value, id)
    if tostring(value) == "-2" then
        local was = turn
        if turn > 0 then BOTTLE.newTurn() end
        turn = math.max(0, turn - 1)
        drawTurn()
        if was == 1 then DEPLOY.again() end               -- back to the setup: the deployment's model too
        return
    end
    turn = turn + 1
    drawTurn()
    BOTTLE.newTurn()
    local n, up = everyFighter("setReady", true)
    if turn == 1 then                                     -- Start Game: every Reliable ready, the deployment's model gone
        everyFighter("resetReliable")
        DEPLOY.remove()
    end
    printToAll(string.format("%sRound %d: %d fighter(s) readied%s.", CHAT_PREFIX, turn, n, updatedNote(up)),
        { 0.3, 1, 0.4 })
end

-- A click on a setup row (setupBtn_<k>, see SETUP) -- Map Size: either
-- mouse button, the next size; Roll for Deployment: a right click takes
-- its model away, or puts it back; otherwise a left click: a roll's D6
-- thrown in the dice line ("Rolling..." on the row until it lands), its
-- result said on everyone's screen and shown on the row; Determine
-- Attacker | Defender: the roll-off (SETUP.rollOff). The rest do nothing
-- yet.
function onSetup(player, value, id)
    local k = tonumber(tostring(id or ""):match("^setupBtn_(%d+)$"))
    local row = k and SETUP.ROWS[k]
    if row and row.deploy and tostring(value) == "-2" then
        if not DEPLOY.remove() then DEPLOY.again() end
        return
    end
    if row and row.map then return SETUP.nextMap(k) end                -- either mouse button
    if not row or tostring(value) ~= "-1" or SETUP.rolling[k] then return end
    if row.rollOff then return SETUP.rollOff(k, player and player.color or nil) end
    if not row.results then return end
    SETUP.rolling[k] = true
    SETUP.draw(k)
    DICE.request({ kinds = { "d6" }, color = player and player.color or nil, done = function(faces, digital)
        SETUP.rolling[k] = nil
        SETUP.rolled[row.key] = faces[1]
        SETUP.draw(k)
        DICE.announce(string.format("%s%s: %s%s", CHAT_PREFIX, row.say, row.results[faces[1]],
            digital and " (rolled digitally)" or ""), SETUP.SAY)
        if row.deploy then DEPLOY.spawn(faces[1], row.results[faces[1]]) end
    end })
end

-- The map size on to the next of DEPLOY.SIZES (row `k` redrawn); a
-- deployment model on the table is swapped for that size's.
function SETUP.nextMap(k)
    local i = 1
    for n, size in ipairs(DEPLOY.SIZES) do if size == SETUP.map then i = n end end
    SETUP.map = DEPLOY.SIZES[i % #DEPLOY.SIZES + 1]
    SETUP.draw(k)
    if DEPLOY.find() then DEPLOY.again() end
end

-- A click on one of the deployment's small buttons (any mouse button):
-- the model turned DEPLOY.TURN degrees, or stretched up / down by
-- DEPLOY.STEP of its height -- remembered for the next one.
function onDeployTool(player, value, id)
    id = tostring(id or "")
    if id == "deployTurn" then DEPLOY.turn = (DEPLOY.turn + DEPLOY.TURN) % 360
    elseif id == "deployUp" then DEPLOY.tall = DEPLOY.tall + DEPLOY.STEP
    elseif id == "deployDown" then DEPLOY.tall = math.max(DEPLOY.STEP, DEPLOY.tall - DEPLOY.STEP)
    else return end
    local o = DEPLOY.find()
    if not o then return end
    local across = DEPLOY.stretch or 1
    pcall(function()
        o.setRotation({ 0, DEPLOY.turn, 0 })
        o.setScale({ across, DEPLOY.tall, across })
    end)
end

-- A left click on a victory points plate's Attacker / Defender: swapped.
function onSwapRoles(player, value, id)
    if tostring(value) == "-1" then SETUP.swap() end
end

-- The Reset all Fighters button as it stands: red, brighter while it asks
-- for the second click.
function RESET.draw()
    setLabel("resetFighters", RESET.asking and RESET.ASK or RESET.LABEL)
    self.UI.setAttribute("resetFighters", "colors", RESET.asking and RESET.ASKING or RED)
    self.UI.setAttribute("resetFighters", "textColor", PALE)
end

-- A left click on Reset all Fighters: the first asks for a second (for
-- RESET.WAIT seconds), the second puts every fighter back as imported (the
-- card's resetFighter; older cards brought up to date first, as for every
-- call to all fighters).
function onResetFighters(player, value, id)
    if tostring(value) ~= "-1" then return end
    RESET.token = RESET.token + 1
    if not RESET.asking then
        RESET.asking = true
        RESET.draw()
        local token = RESET.token
        Wait.time(function()
            if token == RESET.token and RESET.asking then RESET.asking = false; RESET.draw() end
        end, RESET.WAIT)
        return
    end
    RESET.asking = false
    RESET.draw()
    local n, up = everyFighter("resetFighter")
    printToAll(string.format("%s%d fighter(s) reset to how they were imported%s.", CHAT_PREFIX, n, updatedNote(up)),
        { 1, 0.7, 0.2 })
end

function onClearConditions(player, value, id)
    local n, up = everyFighter("clearConditions")
    printToAll(string.format("%sConditions cleared on %d fighter(s)%s.", CHAT_PREFIX, n, updatedNote(up)),
        { 1, 0.7, 0.2 })
end

-- ── The table's own rules ─────────────────────────────────────
-- The overrides come from two places (see RULES): RULES.custom, what a
-- script gave setRules ({} = none), and the homebrew sets that are on
-- (HOMEBREW). RULES.active is them all laid over each other, in that order:
-- the overrides in force (nothing: the rules as written). The cards ask for
-- it (getRules) when they load and when told to (their loadRules); this
-- Controller reads its own dice through it too.
RULES.custom, RULES.active = {}, {}

-- The overrides `b` makes laid over the overrides `a`, as one override
-- table (a fresh one) that does what the two do one after the other --
-- which is not `b` merged over the defaults: a keyed table (a status's
-- actions, a stat's limits) in both has its fields laid over each other, a
-- list of entries (actions, skills ...) gets the later entries after the
-- earlier ones, and a list or a value of `b` replaces `a`'s.
function RULES.stack(a, b)
    local out = RULES.copy(type(a) == "table" and a or {})
    if type(b) ~= "table" then return out end
    for part, kind in pairs(RULES.PARTS) do
        local o, t = b[part], out[part]
        if type(o) ~= "table" then
            -- nothing of `b`'s here
        elseif type(t) ~= "table" or kind == "list" then
            out[part] = RULES.copy(o)
        elseif kind == "map" or kind == "values" then
            local d = RULES.DEFAULT[part]
            for k, v in pairs(o) do
                local was = t[k]
                if type(v) == "table" and type(was) == "table" and not RULES.isList(v) and not RULES.isList(was) then
                    for f, x in pairs(v) do t[k][f] = RULES.copy(x) end   -- a false stays: it still takes the field out
                else
                    t[k] = RULES.copy(v)
                    -- `b` starts the key afresh (`a` took it out, or set a
                    -- list): the defaults' other fields must not show through
                    if type(v) == "table" and not RULES.isList(v) and type(d[k]) == "table"
                       and not RULES.isList(d[k]) and (was == false or (type(was) == "table" and RULES.isList(was))) then
                        for f in pairs(d[k]) do if v[f] == nil then t[k][f] = false end end
                    end
                end
            end
        else
            for _, e in ipairs(o) do t[#t + 1] = RULES.copy(e) end
        end
    end
    return out
end

-- The overrides in force now: the custom ones, then each homebrew set that
-- is on, in the order of SETS.
function HOMEBREW.overrides()
    local out = RULES.copy(RULES.custom)
    for _, set in ipairs(HOMEBREW.SETS) do
        if HOMEBREW.on[set.id] then out = RULES.stack(out, set.rules) end
    end
    return out
end

-- Every fighter's card that can take them told to fetch the rules again
-- (its loadRules: it rebuilds only if they have changed for it). Returns
-- how many were told.
function RULES.push()
    local n = 0
    for _, obj in ipairs(getAllObjects()) do
        if IMPORT_TAG ~= "" and obj.hasTag(IMPORT_TAG) and callIfHas(obj, "loadRules") then n = n + 1 end
    end
    return n
end

-- The overrides in force worked out again (RULES.custom and the sets that
-- are on): when they differ from those in force, this Controller's dice
-- follow them and every card is told. Returns whether they changed, and how
-- many cards were told.
function RULES.refresh()
    local now = HOMEBREW.overrides()
    if RULES.same(now, RULES.active) then return false, 0 end
    RULES.active = now
    RULES.use(now)
    return true, RULES.push()
end

-- The overrides in force, for a fighter's card (its loadRules): a copy.
function getRules()
    return RULES.copy(RULES.active)
end

-- Puts the table's own rules in force: `t` the overrides (see RULES; nil
-- or {} = none), which count along with the homebrew sets that are on.
-- When they change the rules in force they are kept (saved with the
-- Controller), this Controller's dice follow and every card is told,
-- which is said in chat. Returns whether the rules in force changed.
function setRules(t)
    RULES.custom = RULES.copy(type(t) == "table" and t or {})
    local changed, n = RULES.refresh()
    if changed then
        printToAll(string.format("%sRules changed: %s -- %d fighter(s) told.", CHAT_PREFIX,
            next(RULES.active) and "the table's own" or "the rules as written", n), { 1, 0.7, 0.2 })
    end
    return changed
end

-- ── Homebrew ─────────────────────────────────────────────────────
-- The sets (HOMEBREW.SETS) that are on are rules of the table: laid over
-- the rules as written (RULES.stack) and handed to the cards like any
-- override (RULES.refresh). They are chosen on the Homebrew Rules page --
-- every choice there only marks the page (HOMEBREW.pick) until "Apply
-- selected Rules" puts them all in force at once.

-- A set's place in SETS, and the set, by its id (nil: no such set).
function HOMEBREW.find(id)
    for i, set in ipairs(HOMEBREW.SETS) do
        if set.id == id then return i, set end
    end
end

-- The main page's button: "Homebrew Rules", and how many sets are on.
function HOMEBREW.button()
    local n = #HOMEBREW.list()
    return n > 0 and string.format("Homebrew Rules (%d on)", n) or "Homebrew Rules"
end

-- Whether the page's choices differ from the sets in force.
function HOMEBREW.changed()
    for _, set in ipairs(HOMEBREW.SETS) do
        if (HOMEBREW.pick[set.id] == true) ~= (HOMEBREW.on[set.id] == true) then return true end
    end
    return false
end

-- Apply selected Rules to all Models as it looks: lit while there is something to
-- apply, washed while the page's choices are those in force.
function HOMEBREW.applyLook()
    local c = HOMEBREW.changed()
    return c and LIT or WASH, c and PALE or INK
end

-- A button's label changed, and then its colours and ink: TTS puts a
-- button's ink back to the panel's default (anthracite) when its label
-- changes, so the ink must come after it.
function HOMEBREW.label(id, text, c, ink)
    setLabel(id, text)
    self.UI.setAttribute(id, "colors", c)
    self.UI.setAttribute(id, "textColor", ink)
end

-- Set `i`'s radio buttons redrawn, as the page has it chosen, with the
-- description of the chosen one -- and Apply.
function HOMEBREW.draw(i)
    local set = HOMEBREW.SETS[i]
    for k = 1, 2 do
        local c, ink, label, desc = hbLook(set, k)
        HOMEBREW.label(string.format("hbOpt_%d_%d", i, k), label, c, ink)
        if k == 1 then setLabel("hbDesc_" .. i, desc) end
    end
    local c, ink = HOMEBREW.applyLook()
    self.UI.setAttribute("homebrewApply", "colors", c)
    self.UI.setAttribute("homebrewApply", "textColor", ink)
end

-- The Homebrew Rules page shown in the play section's place (`on`), its
-- choices those in force -- or the play section back, whatever the page
-- had chosen and not applied gone with it.
function HOMEBREW.show(on)
    HOMEBREW.page = on == true
    HOMEBREW.pick = {}
    for id in pairs(HOMEBREW.on) do HOMEBREW.pick[id] = true end
    for i in ipairs(HOMEBREW.SETS) do HOMEBREW.draw(i) end
    self.UI.setAttribute("playSection", "active", tostring(not HOMEBREW.page))
    self.UI.setAttribute("homebrewPage", "active", tostring(HOMEBREW.page))
    HOMEBREW.label("homebrewBtn", HOMEBREW.button(), LIT, PALE)
end

-- What chat says once the sets in force have changed: `what`, and how many
-- cards heard of it (none did when the rules in force stayed the same).
function HOMEBREW.say(what, changed, told)
    printToAll(string.format("%sHomebrew: %s -- %s.", CHAT_PREFIX, what,
        changed and string.format("%d fighter(s) told", told) or "no change to the rules"), { 1, 0.7, 0.2 })
end

-- Every choice the page has made put in force at once (the cards told
-- once), said in chat by the names of the choices that changed; then the
-- play section again. Returns whether any changed.
function HOMEBREW.apply()
    local what = {}
    for _, set in ipairs(HOMEBREW.SETS) do
        local want = HOMEBREW.pick[set.id] == true
        if want ~= (HOMEBREW.on[set.id] == true) then
            HOMEBREW.on[set.id] = want or nil
            what[#what + 1] = hbText(want and set.name or set.off)
        end
    end
    HOMEBREW.show(false)
    if #what == 0 then return false end
    local changed, told = RULES.refresh()
    HOMEBREW.say(table.concat(what, ", "), changed, told)
    return true
end

-- The set with id `id` switched on or off (`on` nil: the other way) at
-- once -- for a script (setHomebrew). Returns whether it changed.
function HOMEBREW.switch(id, on)
    local i, set = HOMEBREW.find(id)
    if not i then return false end
    if on == nil then on = not HOMEBREW.on[id] end
    if (HOMEBREW.on[id] == true) == (on == true) then return false end
    HOMEBREW.on[id] = on == true or nil
    HOMEBREW.pick[id] = HOMEBREW.on[id]
    HOMEBREW.draw(i)
    HOMEBREW.label("homebrewBtn", HOMEBREW.button(), LIT, PALE)
    local changed, told = RULES.refresh()
    HOMEBREW.say(hbText(on and set.name or set.off), changed, told)
    return true
end

-- The ids of the sets that are on, in the order of SETS (what is saved).
function HOMEBREW.list()
    local out = {}
    for _, set in ipairs(HOMEBREW.SETS) do
        if HOMEBREW.on[set.id] then out[#out + 1] = set.id end
    end
    return out
end

-- The main page's Homebrew Rules: the page opens. Back: it closes, nothing
-- changed.
function onHomebrewOpen(player, value, id) HOMEBREW.show(true) end
function onHomebrewBack(player, value, id) HOMEBREW.show(false) end

-- A click on a radio button (hbOpt_<set>_<1 | 2>, whichever mouse
-- button): that choice for the set, on the page only.
function onHomebrewOption(player, value, id)
    local i, k = tostring(id or ""):match("^hbOpt_(%d+)_([12])$")
    i = tonumber(i)
    local set = i and HOMEBREW.SETS[i]
    if not set then return end
    HOMEBREW.pick[set.id] = k == "2" or nil
    HOMEBREW.draw(i)
end

-- Apply selected Rules to all Models: see HOMEBREW.apply.
function onHomebrewApply(player, value, id) HOMEBREW.apply() end

-- The header's Feedback button: the feedback form on a tablet past the panel.
function onFeedback(player, value, id)
    FEEDBACK.open(PANEL, PANEL_H)
end

-- The sets, for a script: a list of { id, name (the set's choice), off
-- (the rules as written), on }.
function getHomebrew()
    local out = {}
    for _, set in ipairs(HOMEBREW.SETS) do
        out[#out + 1] = { id = set.id, name = set.name, off = set.off, on = HOMEBREW.on[set.id] == true }
    end
    return out
end

-- Switches a set at once: t = { id = "pre_measure", value = true | false }
-- (no value: the other way). Returns whether it changed.
function setHomebrew(t)
    t = type(t) == "table" and t or {}
    local on = t.value
    if on ~= nil then on = on == true end
    return HOMEBREW.switch(t.id, on)
end

function onSave()
    return JSON.encode({ version = VERSION, turn = turn, vp = vp, vpNames = vpNames, bottle = BOTTLE.due, rules = RULES.custom,
        homebrew = HOMEBREW.list(), setup = { attacker = SETUP.attacker, rolled = SETUP.rolled, map = SETUP.map,
                                              deployTurn = DEPLOY.turn, deployTall = DEPLOY.tall } })
end

-- The version comes from the updater block at the end of the published
-- script (none: "?").
function onLoad(saved)
    if Updater_stateVersion then
        local _
        _, VERSION = Updater_stateVersion(saved)
    end
    local ok, data = pcall(function() return JSON.decode(saved or "") end)
    if ok and type(data) == "table" then
        turn = tonumber(data.turn) or turn
        for i = 1, 2 do
            vp[i] = tonumber((data.vp or {})[i]) or vp[i]
            vpNames[i] = (data.vpNames or {})[i] or vpNames[i]
        end
        if type(data.bottle) == "table" then BOTTLE.due = data.bottle end
        if type(data.rules) == "table" then RULES.custom = data.rules end
        if type(data.setup) == "table" then
            SETUP.attacker = data.setup.attacker == 2 and 2 or 1
            for _, size in ipairs(DEPLOY.SIZES) do
                if tonumber(data.setup.map) == size then SETUP.map = size end
            end
            DEPLOY.turn = tonumber(data.setup.deployTurn) or DEPLOY.turn
            DEPLOY.tall = math.max(DEPLOY.STEP, tonumber(data.setup.deployTall) or DEPLOY.tall)
            SETUP.rolled = {}
            for _, row in ipairs(SETUP.ROWS) do
                local face = row.key and tonumber((data.setup.rolled or {})[row.key])
                if face and (row.rollOff and (face == 1 or face == 2) or row.results and row.results[face]) then
                    SETUP.rolled[row.key] = face
                end
            end
        end
        if type(data.homebrew) == "table" then
            HOMEBREW.on = {}
            for _, id in ipairs(data.homebrew) do
                if HOMEBREW.find(id) then HOMEBREW.on[id] = true end
            end
        end
    end
    RULES.active = HOMEBREW.overrides()
    RULES.use(RULES.active)
    -- the panel built on its main page, the Homebrew page's choices those in force
    HOMEBREW.page, HOMEBREW.pick = false, {}
    for id in pairs(HOMEBREW.on) do HOMEBREW.pick[id] = true end
    pcall(function() if not self.hasTag(CONTROLLER_TAG) then self.addTag(CONTROLLER_TAG) end end)
    self.UI.setXml(detailed(panelXml(), "controllerPanel"), panelAssets())
    Wait.time(BOTTLE.tick, BOTTLE.POLL, -1)
    -- the cards that loaded before this did asked no one: tell them now
    -- (the table's own rules only -- as written, they already have them)
    if next(RULES.active) then Wait.frames(RULES.push, 2) end
end

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
local TOOL_ID        = "mundane-controller"
local TOOL_VERSION   = "2.2.0"                 -- bumped with manifest.json
local TOOL_SIGNATURE = "TTS-SELFUPDATE:mundane-controller"

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
