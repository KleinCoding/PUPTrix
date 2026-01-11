-- Puppetmaster helper library

-- Used to access packet data
local packets = require('packets')

-- Accessing windower data
local res = require('resources')

-- Text renderer for HUD
local texts = require('texts')


-----------------------------------------
-- Hook booleans --
-----------------------------------------
local target_change_event_registered = false
local pet_buffs_hook_registered = false
local prerender_registered = false
local zone_change_hook_registered = false
local incoming_text_hook_registered = false
local item_use_hook_registered = false



-----------------------------------------
-- CONSTS
-----------------------------------------
local Towns = {
    [246] = "Ru'Lude Gardens",
    [236] = "Port Bastok",
    [50]  = "Port Jeuno",
    [51]  = "Lower Jeuno",
    [52]  = "Upper Jeuno",
    [53]  = "Rabao",
}

local MANEUVER_MAP = {
    ["Fire Maneuver"]    = "Fire",
    ["Water Maneuver"]   = "Water",
    ["Wind Maneuver"]    = "Wind",
    ["Earth Maneuver"]   = "Earth",
    ["Thunder Maneuver"] = "Thunder",
    ["Ice Maneuver"]     = "Ice",
    ["Light Maneuver"]   = "Light",
    ["Dark Maneuver"]    = "Dark",
}

-- TODO: These are wrong.
local BLOCKING_DEBUFF_IDS = {
    [2] = true,  -- Sleep
    [3] = true,  -- Sleep II
    [4] = true,  -- Sleep III
    [5] = true,  -- Sleepga
    [6] = true,  -- Sleepga II
    [7] = true,  -- Nightmare (sleep)
    [10] = true, -- Stun
    [13] = true, -- Charm
    [16] = true, -- Amnesia
    [17] = true, -- Petrification
    [28] = true, -- Terror
}


-- HUD Values
HUD_OPACITY_ACTIVE            = 0.7 -- Full visibility when active
HUD_OPACITY_IDLE              = 0.2 -- Dimmed opacity when idle/in town
HUD_FADE_SPEED                = 1 -- How quickly opacity transitions (lower = slower) -- TODO : Not working
HUD_BORDER_ALPHA              = 175 -- Border transparency (0–255)
HUD_BG_ALPHA                  = 80 -- Background transparency (0–255)
HUD_LABEL_WIDTH               = 20 -- Fixed label width for alignment
HUD_TEXT_ALPHA                = 150
HUD_TEXT_STROKE_ALPHA         = 125
local current_opacity         = HUD_OPACITY_ACTIVE
local opacity_target          = HUD_OPACITY_ACTIVE

-- AutoRepair values
local PET_HP_UPDATE_INTERVAL  = 1.0 -- once per second
local AUTO_REPAIR_THRESHHOLDS = { 0, 20, 40, 55, 70 }
local BASE_REPAIR_COOLDOWN    = 90 -- seconds
local UPGRADE_REDUCTION       = 3  -- seconds per upgrade level
local MAX_UPGRADE_LEVEL       = 5
local REPAIR_RANGE_YALMS      = 20
local AUTOREPAIR_SPAM_GUARD   = 3.5 -- seconds

-- AutoDeploy values
local DEPLOY_COOLDOWN         = 5
local DEPLOY_DEBOUNCE         = 0.5
local DEPLOY_DELAY            = 2.5



------------------------------------------------------------
-- Pet Enmity Auto Swap State Tracking
------------------------------------------------------------
-- // TODOS: Enmity set can get stuck. Need to reset state values when toggling off the feature. Need to reset state values on zone. Maybe when combat ends.
--// Gear seemed to get stuck when ending a HTBF while set was active
--// Need to track Flashbulb/Strobe cooldown even when feature is off? Otherwise logic assumes the voke/flash are ready when turned on mid combat
--// Need to reset states on player death, pet death, and zone
local Flashbulb_Timer = 45
local Strobe_Timer = 30
local Flashbulb_Recast = 0
local Strobe_Recast = 0
local Flashbulb_Time = 0
local Strobe_Time = 0
local PET_ENMITY_WINDOW = 3 -- seconds to hold enmity gear

auto_enmity_state = {
    active = false,
    ability = nil, -- 'Strobe' or 'Flashbulb'
    timer = 0      -- expiration timestamp
}

-----------------------------------------
-- Pet Weaponskill AutoSwap State Tracking
-----------------------------------------
local PET_WS_TP_THRESHOLD = 999 -- configurable trigger TP (e.g. 900/1000)
local PET_WS_ACTIVE_WINDOW = 4  -- seconds to stay in WS gear before check
local PET_WS_LOCKOUT = 3        -- seconds after WS before allowing reactivation
local last_pet_ws_time = 0
local pet_ws_active = false

-- TODO: Base Sets become part of the Matrix
-- TODO: Automatic matrix swapping based on subjob
-- TODO: Automatic Puppet type determination for Pet Matrix
-- TODO: 'None' Field for Pet Matrix needs to be available, or an off, etc
-- TODO: Expand Debug mode. 'Off' 'Light' and 'Full' settings.
-- TODO: Remove HUD opacity change smoothing logic
-- TODO: BLOCKING DEBUFFS. Prevent AutoManeuver, AutoDeploy, AutoRepair when affected by hard CC. Docs say check by name not ID

-- TODO: Pet Casting Set Support

-- TODO: Using Repair manually breaks repair CD tracking


-- TODO: HUD updates. Mini, Lite, and Full modes. Mini only shows sets and abbreviated modes (if on), Lite shows Matrix/Layers & Sets and shows modes (if on). Full shows all data and shows hotkeys
-- Should do Pet Type tracking next. Determine Pet Head/Body and store in state. Incorporate into PetMatrix determination and Pet WS set

-- TODO: For Matrixes, add a flag to gear matrix layers (priority) that when true, ensures that the layer takes precidence over pet matrix layers.
-- This is to ensure DT sets etc ignore active pet layer and get used first. Dalm's idea

-----------------------------------------
-- State
-----------------------------------------
current_state = {
    -- HUD Values
    hudView                = 'Full', -- current HUD layout mode - Full, SetsOnly, Condensed
    activeSetName          = 'None', -- Text string of current sets, for HUD display

    -- Player State
    playerStatus           = 'Idle', -- Current player state - Idle, Engaged
    petStatus              = 'None', -- Current pet state - None, Idle, Engaged
    petHP                  = 0,

    -- Matrix & Matrix Layers state
    matrixName             = 'gear_matrix', -- the key in global `matrices` to use
    layer                  = 'Normal', -- key for active matrix layer -- TODO: rename matrixLayer

    -- Pet Matrix & Pet Matrix Layers state --
    petMatrixCombo         = 'None', -- Key for active pet type to take from Pet Matrix e.g., "Valor_Valor", "Sharp_Sharp", etc.
    petMatrixLayer         = 'Normal', -- key for active pet matrix layer

    -- Custom Layers state
    customLayer            = 'Off', -- active custom set key (sets.layers.CustomLayers.*)

    -- Automation Mode Toggles
    autoManeuver           = false,

    -- Auto Deploy Toggle & State
    autoDeploy             = false,
    last_deploy_time       = 0,
    last_engaged_target_id = 0,

    -- Auto Repair Cycle & State
    autoRepairThreshold    = 0, -- AUTO_REPAIR_THRESHHOLDS = {0, 20, 40, 55, 70}
    repairCooldownUpgrades = 5, -- 0–5; each level reduces cooldown by 3 s -- TODO: Make settings const
    lastRepairAttempt      = 0, -- timestamp of last repair attempt (whether success or fail)
    lastRepairUsed         = 0, -- timestamp of last successful repair
    last_pet_hp_update     = 0, -- timestamp of last time script updated petHP value

    -- Auto Pet WS Toggle & Stat
    autoPetWSToggle        = false, -- TODO: Add check for engaged status so it doesnt spam when player and pet are idle
    autoPetWS              = {
        active = false,
        timer = 0,
        lockout = 0 --TODO: make a user config, and add 'overdriveLockout' for OD scenarios
    },

    -- Utility Toggles
    debugMode              = false,
    weaponLock             = true,
    autoEnmity             = false,

    -- Misc
    currentZoneId          = 'None', -- For managing Town sets
}

-- Auto-maneuver scheduler state
local automan = {
    queue                  = {}, -- FIFO of elements to reapply
    last_use               = 0, -- os.time() of last attempt (player or script)
    cooldown               = 11, -- seconds between maneuvers
    retry_delay            = 3, -- seconds to wait before retrying a failed attempt
    pending                = nil, -- { element="<Elem>", issued_at=timestamp }
    pending_to             = 4, -- seconds allowed for buff to appear after issuing

    manual_suppress_until  = 0, -- timestamp; while now < this, ignore buff-loss queues
    manual_suppress_window = 4, -- seconds to ignore loss events after a manual JA

    retry_counts           = {}, -- { ["Fire"] = 1, ["Water"] = 3, ... }
    max_retries            = 3,
}

-----------------------------------------
-- Utility Functions
-----------------------------------------

local function starts_with(str, start) -- check if a string starts with another string
    return str and start and str:sub(1, #start) == start
end

local function debug_chat(msg) -- Sends messages to chat based on debug toggle status
    if current_state.debugMode then windower.add_to_chat(122, msg) end
end

local function ordered_keys(tbl) -- Helper for matrix/set names
    local t = {}
    for k, _ in pairs(tbl or {}) do t[#t + 1] = k end
    table.sort(t)
    return t
end

local function combine_safe(a, b) -- Combines sets
    if not a then return b end
    if not b then return a end
    return set_combine(a, b)
end

local function safe_get(tbl, ...)
    local node = tbl
    for _, k in ipairs({ ... }) do
        if type(node) ~= 'table' then return nil end
        node = node[k]
    end
    return node
end

local function player_has_oil() -- TODO: Tie to settings for bags#s -- NOT WORKING
    -- container IDs from Windower:
    -- 0: inventory, 1: satchel, 2: sack, 3: case,
    -- 8–15: wardrobes 1–8
    local check_bags = { 0, 1, 2, 3, 8, 9, 10, 11, 12, 13, 14, 15 }

    for _, bag_id in ipairs(check_bags) do
        local bag = windower.ffxi.get_items(bag_id)
        if bag and bag.count and bag.count > 0 and bag.items then
            for _, item in pairs(bag.items) do
                if item and item.id == OIL_ITEM_ID and item.count and item.count > 0 then
                    debug_chat(string.format('[AutoRepair] Found Automaton Oil +3 in bag %d.', bag_id))
                    return true
                end
            end
        end
    end

    debug_chat('[AutoRepair] No Automaton Oil +3 found in any accessible bags.')
    return false
end

local function get_repair_cooldown() -- Determines Repair Cooldown
    local lvl = math.min(current_state.repairCooldownUpgrades or 0, MAX_UPGRADE_LEVEL)
    return BASE_REPAIR_COOLDOWN - (lvl * UPGRADE_REDUCTION)
end


local function update_pet_hp() -- Updates pet HP to state
    local now = os.clock()
    if now - current_state.last_pet_hp_update < PET_HP_UPDATE_INTERVAL then return end
    current_state.last_pet_hp_update = now

    local pet_mob = windower.ffxi.get_mob_by_target('pet')
    if pet_mob and pet_mob.hpp then
        current_state.petHP = pet_mob.hpp
    elseif pet and pet.hpp then
        current_state.petHP = pet.hpp
    else
        current_state.petHP = 0
    end
end

local function player_has_blocking_debuff() --- Check if the player currently has any blocking debuf -- TODO: NEED BUFF IDS
    local player = windower.ffxi.get_player()
    if not player or not player.buffs then return false end

    for _, buff_id in ipairs(player.buffs) do
        if BLOCKING_DEBUFF_IDS[buff_id] then
            local buff_name = res.buffs[buff_id] and res.buffs[buff_id].en or ("BuffID " .. buff_id)
            debug_chat(string.format("[DebuffCheck] Blocking debuff active: %s (ID %d)", buff_name, buff_id))
            return true
        end
    end

    return false
end

local function puppet_is_engaged() -- Returns true if the automaton is already engaged
    local puppet = windower.ffxi.get_mob_by_target('pet')
    if not puppet or not puppet.valid_target then return false end

    -- Assuming Status 1+ => engaged
    if puppet.status and puppet.status >= 1 then
        return true
    end

    return false
end

-----------------------------------------
-- HUD Setup -- TODO: Move to its own file
-----------------------------------------
local hud_settings = {
    pos   = { x = 2200, y = 700 },
    bg    = { alpha = HUD_BG_ALPHA, red = 20, green = 20, blue = 20 },
    flags = { draggable = true },
    text  = {
        font = 'Consolas',
        size = 10,
        stroke = { width = 1, alpha = HUD_TEXT_STROKE_ALPHA },
        red = 255,
        green = 255,
        blue = 255,
        alpha = HUD_TEXT_ALPHA
    },
}
local hud = nil

local DynamicLists = {
    Matrices          = { 'gear_matrix' }, -- keys under global `matrices` (tables)
    Layers            = { 'Normal' },  -- layers discovered in active matrix
    PetMatrixCombos   = { 'None' },    -- combos for active matrix
    PetMatrixLayers   = { 'Normal' },  -- layers for selected combo
    PetMatrixComboMap = {},            -- { combo -> {layers...} } for active matrix
    CustomLayers      = { 'Off' },     -- from sets.layers.CustomLayers
    HudViews          = { 'Full', 'SetsOnly', 'Condensed' },
}

local function fmt_count(cur, list) -- Helper to format counts (Layer (x/y))
    local tot = #list
    if tot > 1 then
        local idx = 1
        for i, v in ipairs(list) do if v == cur then
                idx = i; break
            end end
        return string.format("%s (%d/%d)", cur or "?", idx, tot)
    else
        return cur or (list[1] or "?")
    end
end


local function align_label(label, value) -- Label alignment
    return string.format("%-" .. HUD_LABEL_WIDTH .. "s %s", label .. ":", value or "")
end


local function set_opacity(active) -- Opacity helpers
    opacity_target = active and HUD_OPACITY_ACTIVE or HUD_OPACITY_IDLE
end

-----------------------------------------
-- HUD Renderer
-----------------------------------------
local function hud_update()
    if not hud then return end
    local lines = {}

    -------------------------------------------------
    -- Sets Only HUD
    -------------------------------------------------
    if current_state.hudView == 'SetsOnly' then
        -- Compact one-line display
        if current_state.activeSetName and current_state.activeSetName ~= 'None' then
            local combined = current_state.activeSetName:gsub("%+", "  ➜  ")
            table.insert(lines, "Sets: " .. combined)
        else
            table.insert(lines, "Sets: None")
        end

        -------------------------------------------------
        -- Condensed HUD
        -------------------------------------------------
    elseif current_state.hudView == 'Condensed' then
        table.insert(lines, align_label("MatrixLayer", fmt_count(current_state.layer, DynamicLists.Layers)))
        table.insert(lines,
            align_label("PetMatrixLayer", fmt_count(current_state.petMatrixLayer, DynamicLists.PetMatrixLayers)))
        table.insert(lines, align_label("AutoDeploy", current_state.autoDeploy and 'On' or 'Off'))

        -- Only show AutoManeuver in Condensed view if it's enabled
        if current_state.autoManeuver then
            table.insert(lines, align_label("AutoManeuver", "On"))
        end

        -- Only show AutoDeploy in Condensed view if it's enabled
        if current_state.autoDeploy then
            table.insert(lines, align_label("AutoDeploy", "On"))
        end
    else
        -------------------------------------------------
        -- Full HUD (default)
        -------------------------------------------------
        table.insert(lines, "[PUPtrix HUD]")
        table.insert(lines, "")

        -- Matrix name
        local matrix_idx = 1
        for i, v in ipairs(DynamicLists.Matrices) do if v == current_state.matrixName then
                matrix_idx = i; break
            end end
        table.insert(lines,
            align_label("Matrix",
                string.format("%s (%d/%d)", current_state.matrixName or "?", matrix_idx, #DynamicLists.Matrices)))

        -- Matrix
        table.insert(lines, align_label("MatrixLayer", fmt_count(current_state.layer, DynamicLists.Layers)))

        -- Pet Matrix
        local petMatrixDisplay = (current_state.petMatrixCombo and current_state.petMatrixCombo ~= '' and current_state.petMatrixCombo ~= 'None')
            and current_state.petMatrixCombo
            or 'None'
        table.insert(lines, align_label("PetMatrix", petMatrixDisplay))

        local petMatrixLayerDisplay = 'None'
        if petMatrixDisplay ~= 'None' and DynamicLists.PetMatrixLayers and #DynamicLists.PetMatrixLayers > 0 then
            petMatrixLayerDisplay = fmt_count(current_state.petMatrixLayer, DynamicLists.PetMatrixLayers)
        end
        table.insert(lines, align_label("PetMatrixLayer", petMatrixLayerDisplay))

        -- Custom Layer
        local customDisplay = (current_state.customLayer and current_state.customLayer ~= 'Off')
            and current_state.customLayer or 'None'


        table.insert(lines, align_label("CustomLayer", customDisplay))
        table.insert(lines, align_label("Player", current_state.playerStatus))
        table.insert(lines, align_label("Pet", current_state.petStatus))
        table.insert(lines, align_label("AutoDeploy", current_state.autoDeploy and 'On' or 'Off'))
        table.insert(lines, align_label("Debug", current_state.debugMode and 'On' or 'Off'))
        table.insert(lines, align_label("AutoManeuver", current_state.autoManeuver and 'On' or 'Off'))
        table.insert(lines, align_label("WeaponLock", current_state.weaponLock and 'On' or 'Off'))

        local threshold = tonumber(current_state.autoRepairThreshold) or 0
        local arText = (threshold == 0) and 'Off' or (string.format("%d%%", threshold))
        table.insert(lines, align_label("AutoRepair", arText))


        -- Set breakdown (bottom of full HUD) -- TODO: Make a util
        if current_state.activeSetName and current_state.activeSetName ~= 'None' then
            local setLines = {}
            for segment in current_state.activeSetName:gmatch("[^+]+") do
                segment = segment:gsub("^%s+", ""):gsub("%s+$", "")
                table.insert(setLines, "  " .. segment)
            end
            if #setLines > 0 then
                table.insert(lines, "")
                table.insert(lines, "Sets:")
                for _, v in ipairs(setLines) do table.insert(lines, v) end
            end
        end
    end

    hud:text(table.concat(lines, '\n'))
    hud:show()
end


-----------------------------------------
-- AutoRepair
-----------------------------------------
local function check_auto_repair() -- TODO: Oil check is broken, JA block need correct IDs for debuffs
    local th = tonumber(current_state.autoRepairThreshold) or 0
    if th == 0 then return end
    if not (pet and pet.isvalid and (current_state.petHP or 0) > 0) then return end

    local hp = tonumber(current_state.petHP) or tonumber(pet.hpp) or 100
    if hp > th then return end

    -- spam guard
    local now = os.clock()
    if now - (current_state.lastRepairAttempt or 0) < AUTOREPAIR_SPAM_GUARD then return end
    current_state.lastRepairAttempt = now

    -- Cooldown check --
    local cd = get_repair_cooldown()
    local now = os.clock()
    local elapsed = now - (current_state.lastRepairUsed or 0)
    if elapsed < cd then
        debug_chat(string.format("[AutoRepair] Cooldown active (%.1fs / %.1fs)", elapsed, cd))
        return
    end

    -- ✅ Check if player has oil first
    --if not has_oil() then
    -- windower.add_to_chat(167, '[AutoRepair] No Automaton Oil +3 found! AutoRepair disabled.')
    -- current_state.autoRepairThreshold = 0
    --  hud_update()
    --  return
    --end

    -- ✅ Check distance to pet
    local pet_mob = windower.ffxi.get_mob_by_target('pet')
    if not pet_mob or not pet_mob.valid_target then return end
    local distance = math.sqrt(pet_mob.distance or 0)
    if distance > REPAIR_RANGE_YALMS then
        debug_chat(string.format('[AutoRepair] Pet too far (%.1f yalms). Skipping Repair.', distance))
        return
    end

    -- ✅ Check for JA blocking debuffs
    --if player_has_blocking_debuff() then
    -- debug_chat("[AutoRepair] Player incapacitated. Holding repair attempts.")
    -- return
    --end

    debug_chat(string.format('[AutoRepair] Repair triggered (HP %.1f%% <= %d%%, %.1f yalms)', hp, th, distance))
    current_state.lastRepairUsed = now
    windower.chat.input('/ja "Repair" <me>')
end

-----------------------------------------
-- AutoDeploy
-----------------------------------------
local function has_valid_target()
    local mob = windower.ffxi.get_mob_by_target and windower.ffxi.get_mob_by_target('t')
    return mob and mob.valid and (mob.hpp or 100) > 0
end

function auto_deploy()
    if not current_state.autoDeploy then return end
    if player.status ~= 'Engaged' or not (pet and pet.isvalid) then return end
    local now = os.time()
    if now - current_state.last_deploy_time < DEPLOY_DEBOUNCE then return end
    local target = windower.ffxi.get_mob_by_target('t')
    if not (target and target.id) then return end
    if target.id == current_state.last_engaged_target_id then return end

    current_state.last_engaged_target_id = target.id
    current_state.last_deploy_time = now + DEPLOY_DELAY

    --if player_has_blocking_debuff() then
    --debug_chat("[AutoManeuver] Player incapacitated. Skipping Auto Deploy.")
    -- return
    --end

    -- Skip if puppet is already engaged
    if puppet_is_engaged() then
        debug_chat('[AutoDeploy] Puppet already engaged. Skipping.')
        return
    end

    send_command('@wait ' .. tostring(DEPLOY_DELAY) .. '; gs c __auto_deploy_fire')
    debug_chat(string.format('[AutoDeploy] Triggered for new target (delay %.1f sec)', DEPLOY_DELAY))
end

-----------------------------------------
-- Auto-Maneuver System
-----------------------------------------

local function is_maneuver_buff(name)
    return MANEUVER_MAP[name]
end

local function enqueue_maneuver(element)
    if not element then return end
    -- Keep a single-slot queue. Any new request replaces the previous.
    automan.queue = { element }
    debug_chat(string.format("[AutoManeuver] Queued %s maneuver for reapply", element))
end

local function dequeue_maneuver(element)
    if not element then return end
    for i, e in ipairs(automan.queue) do
        if e == element then
            table.remove(automan.queue, i)
            return
        end
    end
end

local function can_attempt_maneuver()
    if automan.pending then return false end
    local now = os.time()
    if (now - automan.last_use) < automan.cooldown then return false end
    -- Ensure player is alive and pet is active
    if not player or player.status == 'Dead' then return false end
    if not pet or not pet.isvalid then return false end

    -- ✅ Check for JA blocking debuffs
    --if player_has_blocking_debuff() then
    --debug_chat("[AutoManeuver] Player incapacitated. Holding maneuver attempts.")
    --return
    --end

    return true
end


local function try_cast_next_maneuver()
    if #automan.queue == 0 or not can_attempt_maneuver() then return end

    local element = automan.queue[1]
    automan.pending = { element = element, issued_at = os.time() }
    automan.last_use = os.time()

    windower.send_command('input /ja "' .. element .. ' Maneuver" <me>')
    debug_chat(string.format("[AutoManeuver] Attempting %s Maneuver", element))
end

-- Called every frame by prerender (see hook above)
function auto_maneuver_tick()
    -- Abort entirely if puppet is not active
    if not (pet and pet.isvalid and pet.hpp > 0) then
        if #automan.queue > 0 or automan.pending then
            debug_chat("[AutoManeuver] Puppet inactive — clearing queue/pending")
        end
        automan.queue = {}
        automan.pending = nil
        automan.retry_counts = {}
        return
    end

    -- If we have a pending attempt, check for timeout
    if automan.pending then
        local now = os.time()

        if now - automan.pending.issued_at > automan.pending_to then
            local el = automan.pending.element
            automan.pending = nil

            -- increment failure count
            local count = (automan.retry_counts[el] or 0) + 1
            automan.retry_counts[el] = count

            if count >= automan.max_retries then
                debug_chat(string.format("[AutoManeuver] %s failed %d times - giving up.", el, count))
                automan.queue = {}
                automan.retry_counts[el] = nil
            else
                debug_chat(string.format("[AutoManeuver] %s timeout (attempt %d/%d) - requeueing",
                    el, count, automan.max_retries))
                automan.last_use = os.time() - automan.cooldown + automan.retry_delay
                enqueue_maneuver(el)
            end
        end
        return
    end

    -- No pending: try next from queue
    try_cast_next_maneuver()
end

-----------------------------------------
-- Dynamic Builders
-----------------------------------------

-- Build list of matrix names from global `matrices` (tables only)
local function build_matrices()
    local list = {}
    if type(matrices) == 'table' then
        for key, val in pairs(matrices) do
            if type(val) == 'table' then
                list[#list + 1] = key
            end
        end
    end
    table.sort(list)
    if #list == 0 then list = { 'gear_matrix' } end -- fallback name
    DynamicLists.Matrices = list

    -- Validate/adjust current matrixName
    local found = false
    for _, v in ipairs(list) do if v == current_state.matrixName then
            found = true
            break
        end end
    if not found then current_state.matrixName = list[1] end
end

-- Collect layer keys from an active matrix (engaged/idle → master/pet/masterPet → {layers})
local function collect_matrix_layers_from(groupNode, collector)
    if type(groupNode) ~= 'table' then return end
    for _, subTbl in pairs(groupNode) do
        if type(subTbl) == 'table' then
            for layerKey, maybeSet in pairs(subTbl) do
                if type(maybeSet) == 'table' then collector[layerKey] = true end
            end
        end
    end
end

local function build_layers()
    local fallback = { 'Normal', 'Acc', 'TP', 'Regen', 'Ranged' }
    local layersSet = {}
    local gm = safe_get(_G, 'matrices', current_state.matrixName)
    if gm then
        collect_matrix_layers_from(gm.engaged, layersSet)
        collect_matrix_layers_from(gm.idle, layersSet)
    end
    local layers = ordered_keys(layersSet)
    DynamicLists.Layers = (#layers > 0) and layers or fallback

    -- Ensure current layer is valid
    local valid = false
    for _, v in ipairs(DynamicLists.Layers) do if v == current_state.layer then
            valid = true
            break
        end end
    if not valid then current_state.layer = DynamicLists.Layers[1] end
end

-- Build PetMatrix combos/layers from the active matrix
local function build_pet_matrix_lists()
    DynamicLists.PetMatrixCombos = { 'None' }
    DynamicLists.PetMatrixComboMap = {}
    DynamicLists.PetMatrixLayers = { 'Normal' }

    local gm = safe_get(_G, 'matrices', current_state.matrixName)
    local pm = gm and gm.petMatrix or nil
    if not pm then return end

    local combosSet = {}
    for _, statusNode in pairs({ pm.idle, pm.engaged }) do
        if type(statusNode) == 'table' then
            for combo, layerTable in pairs(statusNode) do
                combosSet[combo] = true
                local layerKeys = {}
                if type(layerTable) == 'table' then
                    for layerKey, maybeSet in pairs(layerTable) do
                        if type(maybeSet) == 'table' then
                            layerKeys[#layerKeys + 1] = layerKey
                        end
                    end
                end
                table.sort(layerKeys)
                DynamicLists.PetMatrixComboMap[combo] = (#layerKeys > 0) and layerKeys or { 'Normal' }
            end
        end
    end

    local combos = ordered_keys(combosSet)
    if #combos > 0 then DynamicLists.PetMatrixCombos = combos end

    -- Update current combo's layers
    local layers = DynamicLists.PetMatrixComboMap[current_state.petMatrixCombo] or { 'Normal' }
    DynamicLists.PetMatrixLayers = layers
    local ok = false
    for _, v in ipairs(layers) do if v == current_state.petMatrixLayer then
            ok = true
            break
        end end
    if not ok then current_state.petMatrixLayer = layers[1] end
end

local function update_pet_matrix_layers_for_combo(combo)
    local layers = DynamicLists.PetMatrixComboMap[combo] or { 'Normal' }
    DynamicLists.PetMatrixLayers = layers
    local found = false
    for _, v in ipairs(layers) do if v == current_state.petMatrixLayer then
            found = true
            break
        end end
    if not found then current_state.petMatrixLayer = layers[1] end
end

local function build_custom_layers()
    local list = { 'Off' }
    if sets and sets.layers and sets.layers.CustomLayers then
        for _, k in ipairs(ordered_keys(sets.layers.CustomLayers)) do list[#list + 1] = k end
    end
    DynamicLists.CustomLayers = list
    -- Validate current
    local ok = false
    for _, v in ipairs(list) do if v == current_state.customLayer then
            ok = true
            break
        end end
    if not ok then current_state.customLayer = 'Off' end
end

-----------------------------------------
-- Gear Resolver -- TODO: Handle Maneuver, ability, and spell gearswaps here as well so layer names happen in hud
-----------------------------------------
local function resolve_gear(state)
    local set = sets.base or {}
    local name = 'base'
    local now = os.time()

    -- Select active matrix table
    local gm = safe_get(_G, 'matrices', state.matrixName)
    if not gm then
        debug_chat('[GS] - Active matrix "' .. tostring(state.matrixName) .. '" not found.')
    end

    -------------------------------------------------
    -- PRIMARY MATRIX (master/masterPet/pet per status)
    -------------------------------------------------
    if gm then
        local layer = state.layer or 'Normal'
        local zoneGroup = (state.playerStatus == 'Engaged') and 'engaged' or 'idle'

        if state.playerStatus == 'Engaged' and state.petStatus == 'Engaged' then
            set = combine_safe(set,
                safe_get(gm, zoneGroup, 'masterPet', layer) or safe_get(gm, zoneGroup, 'masterPet', 'Normal'))
            name = ':' .. state.matrixName .. '.' .. zoneGroup .. '.masterPet.' .. layer
        elseif state.playerStatus == 'Engaged' then
            set = combine_safe(set,
                safe_get(gm, zoneGroup, 'master', layer) or safe_get(gm, zoneGroup, 'master', 'Normal'))
            name = ':' .. state.matrixName .. '.' .. zoneGroup .. '.master.' .. layer
        elseif state.petStatus == 'Engaged' then
            set = combine_safe(set, safe_get(gm, zoneGroup, 'pet', layer) or safe_get(gm, zoneGroup, 'pet', 'Normal'))
            name = ':' .. state.matrixName .. '.' .. zoneGroup .. '.pet.' .. layer
        else
            set = combine_safe(set,
                safe_get(gm, zoneGroup, 'master', layer) or safe_get(gm, zoneGroup, 'master', 'Normal'))
            name = ':' .. state.matrixName .. '.' .. zoneGroup .. '.master.' .. layer
        end
    end

    -------------------------------------------------
    -- PET MATRIX (combo/layer per active matrix)
    -------------------------------------------------
    local pm = gm and gm.petMatrix or nil
    if pm and state.petMatrixCombo and state.petMatrixCombo ~= 'None' then
        local zoneGroup = (state.playerStatus == 'Engaged') and 'engaged' or 'idle'
        local combo = state.petMatrixCombo
        local layer = state.petMatrixLayer or 'Normal'

        local pmSet = safe_get(pm, zoneGroup, combo, layer) or safe_get(pm, zoneGroup, combo, 'Normal')
        if pmSet then
            set = combine_safe(set, pmSet)
            name = name ..
            '+petMatrix.' ..
            zoneGroup .. '.' .. combo .. '.' .. (pmSet == safe_get(pm, zoneGroup, combo, layer) and layer or 'Normal')
            debug_chat('[GS] Applied PetMatrix: ' .. state.matrixName .. '/' .. zoneGroup .. '/' .. combo .. '/' .. layer)
        end
    end

    -------------------------------------------------
    -- CUSTOM LAYER (Optional)
    -------------------------------------------------
    if sets.layers and sets.layers.CustomLayers and state.customLayer ~= 'Off' then
        local custom = sets.layers.CustomLayers[state.customLayer]
        if custom then
            set = combine_safe(set, custom)
            name = name .. '+custom.' .. state.customLayer
        end
    end


    -------------------------------------------------
    -- TOWN SET (Optional) -- TODO: Enhance to support sets based on town ID
    -------------------------------------------------
    if Towns[state.currentZoneId] and sets and sets.town then
        set = combine_safe(set, sets.town)
        name = name .. '+ sets.town'
    end

    -------------------------------------------------
    -- PET ENMITY SET
    -------------------------------------------------
    if auto_enmity_state.active then
        set = combine_safe(set, sets.pet.enmity)
        name = name .. '+ sets.pet.enmity'
    end

    -------------------------------------------------
    -- PET WS SWAP SET -- TODO: Make responsive to pet, or make a cycleable layer?
    -------------------------------------------------
    if current_state.autoPetWSToggle and current_state.autoPetWS and current_state.autoPetWS.active then
        set = combine_safe(set, sets.pet.weaponskill)
        name = name .. '+ sets.pet.weaponskill'
    end


    debug_chat('[PUPTRix Gear] Set: ' .. name .. '')
    return set, name
end

-----------------------------------------
-- Equip & Event Handling
-----------------------------------------
local function equip_and_update()
    local set, name = resolve_gear(current_state)
    current_state.activeSetName = name
    equip(set)
    hud_update()
end

function status_change(new, old)
    current_state.playerStatus = new
    set_opacity(new == 'Engaged')

    if new == 'Engaged' and current_state.autoDeploy then auto_deploy() end
    if new == 'Engaged' then equip_and_update() end
    if new == 'Idle' then equip_and_update() end
end

function job_status_change(new, old)
    status_change(new, old)
end

function pet_status_change(new, old)
    if not pet or not pet.isvalid then
        current_state.petStatus = 'None'
    else
        current_state.petStatus = new
    end
    equip_and_update()
end

function pet_change(p, gain)
    if gain then
        current_state.petStatus = p and p.status or 'Idle'
    else
        current_state.petStatus = 'None'

        -- Clear automaneuver queue when puppet deactivated/dies
        if #automan.queue > 0 or automan.pending then
            debug_chat("[AutoManeuver] Puppet lost — clearing queue and pending")
        end
        automan.queue = {}
        automan.pending = nil
        automan.retry_counts = {}
    end
    equip_and_update()
end

function precast(spell, action, spellMap, eventArgs)
    if not spell or not spell.english then return end

    local name = spell.english
    local skill = spell.skill or ''

    ------------------------------------------------------------
    -- Item Use (Only items used by /item command will be detected. Item use from menu will not gearswap)
    ------------------------------------------------------------
    if spell.prefix == '/item' then
        local item_name = spell.english
        if sets and sets.precast.items and sets.precast.items[item_name] then
            debug_chat(string.format("[PUPTrix] %s set ", item_name))
            equip(sets.precast.items[item_name])
            return
        end
    end

    ------------------------------------------------------------
    -- Maneuvers
    ------------------------------------------------------------
    local isManeuver = name:find("Maneuver")
    if isManeuver then
        if sets and sets.precast and sets.precast.JA and sets.precast.JA.Maneuver then
            equip(sets.precast.JA.Maneuver)
        end

        -- AutoManeuver/manual sync handling
        local now                     = os.time()
        automan.last_use              = now
        automan.pending               = nil
        automan.queue                 = {}
        automan.manual_suppress_until = now + automan.manual_suppress_window
        debug_chat(string.format(
            "[PUPTrix AutoManeuver] %s detected",
            name, automan.manual_suppress_window
        ))

        return
    end

    ------------------------------------------------------------
    -- JAs
    ------------------------------------------------------------
    if sets and sets.precast and sets.precast.JA and sets.precast.JA[name] then
        equip(sets.precast.JA[name])
        return
    end

    ------------------------------------------------------------
    -- Weaponskills
    ------------------------------------------------------------
    if sets and sets.precast and sets.precast.WS and sets.precast.WS[name] then
        equip(sets.precast.WS[name])
        return
    end

    ------------------------------------------------------------
    -- Casting
    ------------------------------------------------------------
    if spell.action_type == 'Magic' or spell.type == 'WhiteMagic'
        or spell.type == 'BlackMagic' or spell.type == 'BlueMagic'
        or spell.type == 'Trust' then
        -- Base Fast Cast
        if sets and sets.precast and sets.precast.FC then
            equip(sets.precast.FC)
        end

        -- Skill-specific (e.g. sets.precast['Healing Magic'])
        if sets and sets.precast and sets.precast[skill] then
            equip(sets.precast[skill])
        end

        -- Spell-specific sets (e.g. Cure IV, Utsusemi: Ichi)
        if sets and sets.precast then
            -- Exact spell match
            if sets.precast[name] then
                equip(sets.precast[name])
            else
                -- Try “family” matches like Cure, Banish, Utsusemi, etc.
                for setName, _ in pairs(sets.precast) do
                    if type(setName) == 'string' and starts_with(name, setName) then
                        equip(sets.precast[setName])
                        break
                    end
                end
            end
        end

        return
    end
end

function midcast(spell, action, spellMap, eventArgs)
    if not spell or not spell.english then return end

    local name  = spell.english
    local skill = spell.skill or ''

    ------------------------------------------------------------
    -- Magic Midcast Handling
    ------------------------------------------------------------
    if spell.action_type == 'Magic' or spell.type == 'WhiteMagic'
        or spell.type == 'BlackMagic' or spell.type == 'BlueMagic'
        or spell.type == 'Trust' then
        -- Base midcast set
        if sets and sets.midcast then
            equip(sets.midcast)
        end

        -- Skill-based midcast sets (e.g. Healing Magic, Enhancing Magic)
        if sets and sets.midcast and sets.midcast[skill] then
            equip(sets.midcast[skill])
        end

        -- Spell-specific midcast sets (e.g. Cure IV, Utsusemi: Ichi)
        if sets and sets.midcast then
            -- Exact spell match
            if sets.midcast[name] then
                equip(sets.midcast[name])
            else
                -- Try “family” matches like Cure, Banish, Utsusemi, etc.
                for setName, _ in pairs(sets.midcast) do
                    if type(setName) == 'string' and starts_with(name, setName) then
                        equip(sets.midcast[setName])
                        break
                    end
                end
            end
        end

        return
    end
end

function aftercast(spell)
    -- If maneuver was interrupted, re-queue with debounce
    if spell and spell.english and MANEUVER_MAP[spell.english] then
        local el = MANEUVER_MAP[spell.english]
        if spell.interrupted then
            enqueue_maneuver(el)
            automan.last_use = os.time() - automan.cooldown + automan.retry_delay
            debug_chat('[AutoManeuver] Interrupted; re-queue ' .. el)
            automan.pending = nil
        else
            -- successful attempt; pending will be cleared on buff gain (buff_change)
            automan.last_use = os.time()
        end
    end

    -- Reapply gear
    equip_and_update()
end

function buff_change(name, gained, details)
    local el = is_maneuver_buff(name)
    if not el then return end

    local now = os.time()

    if gained then
        -- If we were waiting on this element, clear pending & queue.
        if automan.pending and automan.pending.element == el then
            debug_chat(string.format("[AutoManeuver] %s buff regained (cleared pending)", el))
            automan.pending          = nil
            automan.queue            = {}
            automan.retry_counts[el] = nil
        end
        return
    end

    -- LOST a maneuver stack
    -- If this loss happened right after a manual JA, treat it as intentional; don't queue.
    if now < (automan.manual_suppress_until or 0) then
        debug_chat(string.format("[AutoManeuver] Ignoring loss of %s (within manual suppress window)", el))
        return
    end

    -- Only queue if AutoManeuver is enabled: treat as a natural expiration / failed buff
    if current_state.autoManeuver then
        debug_chat(string.format("[AutoManeuver] %s maneuver expired/removed - queueing refresh", el))
        enqueue_maneuver(el)
    end
end

function target_change(new_id)
    if player.status ~= 'Engaged' then return end
    if not current_state.autoDeploy then return end

    -- tiny debounce to avoid spam on rapid target swaps
    local now = os.clock()
    if now - current_state.last_deploy_time < DEPLOY_COOLDOWN then return end
    current_state.last_deploy_time = now

    -- Skip if puppet is already engaged
    if puppet_is_engaged() then
        debug_chat('[AutoDeploy] Puppet already engaged. Skipping.')
        return
    end

    debug_chat('[AutoDeploy] Deploying on new target...')
    auto_deploy()
end

-----------------------------------------
-- Init
-----------------------------------------
function lib_init()
    if not hud then
        hud = texts.new(hud_settings)
        hud:bg_visible(true)
        hud:bg_color(30, 30, 30)
        hud:bg_alpha(HUD_BG_ALPHA)
        hud:stroke_color(200, 200, 200, HUD_BORDER_ALPHA)
        hud:color(255, 255, 255, 255)
    end

    -- Build dynamic lists
    build_matrices()
    build_layers()
    build_pet_matrix_lists()
    build_custom_layers()

    -- Weaponlock
    if current_state.weaponLock then
        disable('main', 'sub')
    end

    hud_update()
end

-----------------------------------------
-- Pre-render Hook
-----------------------------------------
if not prerender_registered and windower and windower.register_event then
    prerender_registered = true
    windower.register_event('prerender', function()
        local now = os.time()

        -- Auto-Maneuver scheduler tick
        if current_state.autoManeuver then
            auto_maneuver_tick()
        end

        if current_state.autoRepairThreshold ~= 0 then
            update_pet_hp()
            check_auto_repair()
        end

        -- Pet JA Tracking
        if Strobe_Recast > 0 then Strobe_Recast = Strobe_Timer - (now - Strobe_Time) end
        if Flashbulb_Recast > 0 then Flashbulb_Recast = Flashbulb_Timer - (now - Flashbulb_Time) end


        -- Auto Pet Enmity Set Logic
        if pet and pet.isvalid and player.hpp > 0 and puppet_is_engaged() and current_state.autoEnmity then
            if not auto_enmity_state.active then
                if buffactive["Fire Maneuver"] and (pet.attachments.strobe or pet.attachments["strobe II"]) and Strobe_Recast <= 0.5 then
                    auto_enmity_state.active = true
                    auto_enmity_state.ability = "Strobe"
                    auto_enmity_state.timer = os.time() + PET_ENMITY_WINDOW
                    debug_chat("[AutoEnmity] Strobe - Enmity Gear Window Open")
                    equip_and_update()
                elseif buffactive["Light Maneuver"] and pet.attachments.flashbulb and Flashbulb_Recast <= 0.5 then
                    auto_enmity_state.active = true
                    auto_enmity_state.ability = "Flashbulb"
                    auto_enmity_state.timer = os.time() + PET_ENMITY_WINDOW
                    debug_chat("[AutoEnmity] Flashbulb - Enmity Gear Window Open")
                    equip_and_update()
                end
            else
                -- expiration
                if os.time() > auto_enmity_state.timer then
                    debug_chat("[AutoEnmity] Window expired - Enmity Gear Window Closed")
                    auto_enmity_state.active = false
                    auto_enmity_state.ability = nil
                    auto_enmity_state.timer = 0
                    equip_and_update()
                end
            end
        end

        ------------------------------------


        -- Auto Pet WS Set Logic
        if not (pet and pet.isvalid and current_state.autoPetWSToggle) then return end

        local now = os.time()
        local tp = pet.tp or 0

        -- Lockout protection
        -- if now < current_state.autoPetWS.lockout then return end

        -- Enter Pet WS Mode
        if not current_state.autoPetWS.active and tp >= PET_WS_TP_THRESHOLD then
            current_state.autoPetWS.active = true
            current_state.autoPetWS.timer = now + PET_WS_ACTIVE_WINDOW
            debug_chat(string.format("[AutoPetWS] Pet TP %d >= %d, swapping to WS set", tp, PET_WS_TP_THRESHOLD))
            equip_and_update()
            return
        end

        -- Exit after timer or TP drop
        if current_state.autoPetWS.active then
            if tp < PET_WS_TP_THRESHOLD or now > current_state.autoPetWS.timer then
                debug_chat("[AutoPetWS] Pet WS window ended - reverting gear")
                current_state.autoPetWS.active = false
                current_state.autoPetWS.lockout = now + PET_WS_LOCKOUT
                equip_and_update()
            end
        end
    end)
end

-----------------------------------------
-- Auto Deploy / Target Change Hook
-----------------------------------------
if not target_change_event_registered and windower and windower.register_event then
    windower.register_event('target change', function()
        if current_state.autoDeploy and player and player.status == 'Engaged' then auto_deploy() end
    end)
    target_change_event_registered = true
end

-----------------------------------------
-- Zone-Change Hook
-----------------------------------------
if not zone_change_hook_registered and windower and windower.register_event then
    windower.register_event('zone change', function(new_id, old_id)
        current_state.currentZoneId = new_id
        if equip_and_update then
            coroutine.schedule(equip_and_update, 1)
        end
    end)
    zone_change_hook_registered = true
end

-----------------------------------------
-- Incoming Text Hook
-----------------------------------------
if not incoming_text_hook_registered and windower and windower.register_event then
    windower.register_event("incoming text", function(original)
        -- AutoEnmity
        if not current_state.autoEnmity then return end
        if not original or not pet or not pet.isvalid then return end
        if not original:contains(pet.name) then return end

        if original:contains("Provoke") then
            Strobe_Time = os.time()
            Strobe_Recast = Strobe_Timer

            debug_chat("[AutoEnmity] Strobe fired - reverting to normal gear")
            auto_enmity_state.active = false
            auto_enmity_state.ability = nil
            auto_enmity_state.timer = 0

            equip_and_update()
        elseif original:contains("Flashbulb") then
            Flashbulb_Time = os.time()
            Flashbulb_Recast = Flashbulb_Timer


            debug_chat("[AutoEnmity] Flashbulb fired - reverting to normal gear")
            auto_enmity_state.active = false
            auto_enmity_state.ability = nil
            auto_enmity_state.timer = 0
            equip_and_update()
        end
    end)

    incoming_text_hook_registered = true
end

-----------------------------------------
-- Commands
-----------------------------------------
local function cycle(field, list)
    if not list or #list == 0 then return end
    local idx = 1
    for i, v in ipairs(list) do if v == current_state[field] then
            idx = i
            break
        end end
    current_state[field] = list[(idx % #list) + 1]
    debug_chat('[GS] ' .. field .. ' -> ' .. current_state[field])
end

function self_command(cmd)
    local args = {}
    for w in cmd:gmatch("%S+") do args[#args + 1] = w end
    local c = (args[1] or ''):lower()

    if c == 'cycle' then
        local which = (args[2] or ''):lower()
        if which == 'matrix' then
            cycle('matrixName', DynamicLists.Matrices)
            -- Rebuild all lists tied to the active matrix
            build_layers()
            build_pet_matrix_lists()
            windower.add_to_chat(122, string.format('[PUPtrix] Cycling Matrix'))
        elseif which == 'layer' then
            cycle('layer', DynamicLists.Layers)
            windower.add_to_chat(122, string.format('[PUPtrix] Cycling Matrix Layer'))
        elseif which == 'petmatrix' then
            cycle('petMatrixCombo', DynamicLists.PetMatrixCombos)
            update_pet_matrix_layers_for_combo(current_state.petMatrixCombo)
            windower.add_to_chat(122, string.format('[PUPtrix] Cycling PetMatrix'))
        elseif which == 'petmatrixlayer' then
            cycle('petMatrixLayer', DynamicLists.PetMatrixLayers)
            windower.add_to_chat(122, string.format('[PUPtrix] Cycling PetMatrix Layer'))
        elseif which == 'customlayer' then
            cycle('customLayer', DynamicLists.CustomLayers)
            windower.add_to_chat(122, string.format('[PUPtrix] Cycling Custom Layer'))
        elseif which == 'hudview' then
            cycle('hudView', DynamicLists.HudViews)
            hud_update()
            windower.add_to_chat(122, string.format('[PUPtrix] HUD View set to %s', current_state.hudView))
        elseif which == 'autorepair' then
            local thresholds = AUTO_REPAIR_THRESHHOLDS
            local cur = current_state.autoRepairThreshold or 0
            local idx = 1
            for i, v in ipairs(thresholds) do if v == cur then
                    idx = i
                    break
                end end
            current_state.autoRepairThreshold = thresholds[(idx % #thresholds) + 1]

            local disp = (current_state.autoRepairThreshold == 0) and 'Off'
                or (tostring(current_state.autoRepairThreshold) .. '%')

            windower.add_to_chat(122, '[AutoRepair] Threshold: ' .. disp)
            hud_update()
        end
    elseif c == 'toggle' then
        local which = (args[2] or ''):lower()
        if which == 'autodeploy' then
            current_state.autoDeploy = not current_state.autoDeploy
            windower.add_to_chat(122, '[AutoDeploy] ' .. (current_state.autoDeploy and 'On' or 'Off'))
        elseif which == 'autopetenmity' then
            current_state.autoEnmity = not current_state.autoEnmity
            windower.add_to_chat(122, '[AutoEnmity] ' .. (current_state.autoEnmity and 'On' or 'Off'))
        elseif which == 'autopetws' then
            current_state.autoPetWSToggle = not current_state.autoPetWSToggle
            windower.add_to_chat(122, '[AutoPetWS] ' .. (current_state.autoPetWSToggle and 'On' or 'Off'))
        elseif which == 'debug' then
            current_state.debugMode = not current_state.debugMode
            windower.add_to_chat(122, '[Debug] ' .. (current_state.debugMode and 'On' or 'Off'))
        elseif which == 'weaponlock' then
            current_state.weaponLock = not current_state.weaponLock
            if current_state.weaponLock then
                disable('main', 'sub') -- ✅ lock both weapon slots
                windower.add_to_chat(122, '[WeaponLock] ON - Weapon slots locked')
            else
                enable('main', 'sub') -- ✅ unlock them again
                windower.add_to_chat(122, '[WeaponLock] OFF - Weapon slots unlocked')
            end
        elseif which == 'automaneuver' then
            current_state.autoManeuver = not current_state.autoManeuver
            -- Clear any pending when disabling
            if not current_state.autoManeuver then
                automan.queue = {}
                automan.pending = nil
                automan.retry_counts = {}
            end
            windower.add_to_chat(122, '[AutoManeuver] ' .. (current_state.autoManeuver and 'On' or 'Off'))
        end
    elseif c == '__auto_deploy_fire' then
        windower.send_command('input /pet "Deploy" <t>')
    end

    equip_and_update()
end
