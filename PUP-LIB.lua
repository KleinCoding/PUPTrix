-- Puppetmaster helper library

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
local Towns                   = {
    [246] = "Ru'Lude Gardens",
    [236] = "Port Bastok",
    [50]  = "Port Jeuno",
    [51]  = "Lower Jeuno",
    [52]  = "Upper Jeuno",
    [53]  = "Rabao",
}

local MANEUVER_MAP            = {
    ["Fire Maneuver"]    = "Fire",
    ["Water Maneuver"]   = "Water",
    ["Wind Maneuver"]    = "Wind",
    ["Earth Maneuver"]   = "Earth",
    ["Thunder Maneuver"] = "Thunder",
    ["Ice Maneuver"]     = "Ice",
    ["Light Maneuver"]   = "Light",
    ["Dark Maneuver"]    = "Dark",
}

local PUP_HEAD_MAP            = {
    ["Harlequin Head"]    = "Harle",
    ["Valoredge Head"]    = "Valor",
    ["Sharpshot Head"]    = "Sharp",
    ["Stormwaker Head"]   = "Storm",
    ["Soulsoother Head"]  = "Soul",
    ["Spiritreaver Head"] = "Spirit",
}

local PUP_FRAME_MAP           = {
    ["Harlequin Frame"]  = "Harle",
    ["Valoredge Frame"]  = "Valor",
    ["Sharpshot Frame"]  = "Sharp",
    ["Stormwaker Frame"] = "Storm",
}

-- TODO: Remove old logic for dynamic HUD opacity
-- HUD Values
HUD_OPACITY_ACTIVE            = 0.7 -- Full visibility when active
HUD_OPACITY_IDLE              = 0.2 -- Dimmed opacity when idle/in town
HUD_FADE_SPEED                = 1   -- How quickly opacity transitions (lower = slower) -- TODO : Not working
HUD_BORDER_ALPHA              = 175 -- Border transparency (0–255)
HUD_BG_ALPHA                  = 80  -- Background transparency (0–255)
HUD_LABEL_WIDTH               = 20  -- Fixed label width for alignment
HUD_TEXT_ALPHA                = 150
HUD_TEXT_STROKE_ALPHA         = 125
local current_opacity         = HUD_OPACITY_ACTIVE
local opacity_target          = HUD_OPACITY_ACTIVE

-- AutoRepair values
local PET_HP_UPDATE_INTERVAL  = 1.0                   -- once per second
local AUTO_REPAIR_THRESHHOLDS = { 0, 20, 40, 55, 70 } -- TODO: move to VARs
local BASE_REPAIR_COOLDOWN    = 90                    -- seconds
local UPGRADE_REDUCTION       = 3                     -- seconds per upgrade level
local MAX_UPGRADE_LEVEL       = 5
local REPAIR_RANGE_YALMS      = 20
local AUTOREPAIR_SPAM_GUARD   = 3.5 -- seconds TODO: Move to VARs

-- AutoDeploy values
local DEPLOY_COOLDOWN         = 5
local DEPLOY_DEBOUNCE         = 0.5
local DEPLOY_DELAY            = 2.5



------------------------------------------------------------
-- Pet Enmity Auto Swap State Tracking
------------------------------------------------------------
--// Need to track Flashbulb/Strobe cooldown even when feature is off? Otherwise logic assumes the voke/flash are ready when turned on mid combat
local Flashbulb_Timer = 45
local Strobe_Timer = 30
local Flashbulb_Recast = 0
local Strobe_Recast = 0
local Flashbulb_Time = 0
local Strobe_Time = 0
local PET_ENMITY_WINDOW = 3 -- seconds to hold enmity gear TODO: Move to -VARS file

local auto_enmity_state = {
    active = false,
    ability = nil, -- 'Strobe' or 'Flashbulb'
    timer = 0      -- expiration timestamp
}

-----------------------------------------
-- Pet Weaponskill AutoSwap State Tracking
-----------------------------------------
local PET_WS_TP_THRESHOLD = 990 -- configurable trigger TP (e.g. 900/1000) TODO: Move to VARS file
local PET_WS_ACTIVE_WINDOW = 4  -- seconds to stay in WS gear before check TODO: Move to VARS File
local PET_WS_LOCKOUT = 3        -- seconds after WS before allowing reactivation TODO: Move to VARS file
local last_pet_ws_time = 0
local pet_ws_active = false

-- TODO: Expand Debug mode. 'Off' 'Light' and 'Full' settings.
-- TODO: Remove HUD opacity change smoothing logic
-- TODO: BLOCKING DEBUFFS. Prevent AutoManeuver, AutoDeploy, AutoRepair when affected by hard CC. Docs say check by name not ID

-- TODO: Pet Casting Set Support

-- TODO: HUD updates. Mini, Lite, and Full modes. Mini only shows sets and abbreviated modes (if on), Lite shows Matrix/Layers & Sets and shows modes (if on). Full shows all data and shows hotkeys
-- Should do Pet Type tracking next. Determine Pet Head/Body and store in state. Incorporate into PetMatrix determination and Pet WS set

-- TODO: For Matrixes, add a flag to gear matrix layers (priority) that when true, ensures that the layer takes precidence over pet matrix layers.
-- This is to ensure DT sets etc ignore active pet layer and get used first. Dalm's idea

-----------------------------------------
-- State
-----------------------------------------
local current_state = {              -- TODO: Break this block into multiple state values. HUD/Player/Pet/Matrix etc
    -- HUD Values
    hudView                = 'Full', -- current HUD layout mode - Full, SetsOnly, Condensed
    activeSetName          = 'None', -- Text string of current sets, for HUD display

    -- Player State
    playerStatus           = 'Idle', -- Current player state - Idle, Engaged
    petStatus              = 'None', -- Current pet state - None, Idle, Engaged
    petType                = '',     -- Current Pet Type - Valor_Valor, Sharp_Valor, Storm_Storm, etc.
    petHP                  = 0,

    -- Matrix & Matrix Layers state
    matrixName             = 'gear_matrix', -- the key in global `matrices` to use
    matrixLayer            = 'None',        -- key for active matrix layer

    -- Pet Matrix & Pet Matrix Layers state --
    petMatrixCombo         = 'None', -- Key for active pet type to take from Pet Matrix e.g., "Valor_Valor", "Sharp_Sharp", etc.
    petMatrixLayer         = 'None', -- key for active pet matrix layer

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
    autoPetWSToggle        = false,
    autoPetWS              = {
        active = false,
        timer = 0,
        lockout = 0 --TODO: make a user config, and add 'overdriveLockout' for OD scenarios TODO: If lockout is 0, disable lockout logic/keep set on
    },

    -- Utility Toggles
    debugMode              = false, --TODO: Derive initial value from VARS
    weaponLock             = true,  --TODO: Derive initial value from VARS
    autoEnmity             = false, --TODO: Derive initial value from VARS

    -- Misc
    currentZoneId          = 'None', -- For managing Town sets
}

-- Auto-maneuver scheduler state
local automan = {
    queue                  = {},  -- FIFO of elements to reapply
    last_use               = 0,   -- os.time() of last attempt (player or script)
    cooldown               = 11,  -- seconds between maneuvers
    retry_delay            = 3,   -- seconds to wait before retrying a failed attempt
    pending                = nil, -- { element="<Elem>", issued_at=timestamp }
    pending_to             = 4,   -- seconds allowed for buff to appear after issuing

    manual_suppress_until  = 0,   -- timestamp; while now < this, ignore buff-loss queues
    manual_suppress_window = 3,   -- seconds to ignore loss events after a manual JA

    retry_counts           = {},  -- { ["Fire"] = 1, ["Water"] = 3, ... }
    max_retries            = 3,
}

-----------------------------------------
-- Utility Functions
-----------------------------------------

local function starts_with(str, start) -- check if a string starts with another string
    return str and start and str:sub(1, #start) == start
end

local function debug_chat(msg) -- Sends messages to chat based on debug toggle status
    -- TODO: Expand debug chat options from on/off to Off, Full, and Light
    if current_state.debugMode then windower.add_to_chat(122, msg) end
end

local function ordered_keys(tbl) -- Helper for matrix/set names
    local t = {}
    for k, _ in pairs(tbl or {}) do t[#t + 1] = k end
    table.sort(t)
    return t
end

local function combine_safe(a, b) -- Combines sets safely
    if not a then return b end
    if not b then return a end
    return set_combine(a, b)
end

local function safe_get(tbl, ...) -- Gets data from a table safely
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

local function puppet_is_engaged() -- Returns true if the automaton is already engaged
    local puppet = windower.ffxi.get_mob_by_target('pet')
    if not puppet or not puppet.valid_target then return false end

    -- Assuming Status 1+ => engaged
    if puppet.status and puppet.status >= 1 then
        return true
    end

    return false
end

local function get_pet_ws_set()
    local currentMatrix = safe_get(_G, 'matrices', current_state.matrixName)
    if not currentMatrix or not currentMatrix.petMatrix or not currentMatrix.petMatrix.weaponskills then
        return nil
    end
    return currentMatrix.petMatrix.weaponskills[current_state.petType]
end

local function can_player_act()
    if midaction() then return false end

    if not player or player.hpp == 0 then return false end

    if buffactive['Stun'] or buffactive['Sleep'] or buffactive['Petrification']
        or buffactive['Terror'] or buffactive['Charm'] or buffactive['Amnesia'] or buffactive['Invisible'] then
        return false
    end

    return true
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
    Matrices               = { 'gear_matrix' },
    MatrixLayers           = { 'None' }, -- MatrixLayer list includes None
    PetMatrixCombos        = { 'None' },
    PetMatrixLayers        = { 'None' }, -- PetMatrixLayer list includes None
    PetMatrixLayersByCombo = {},
    CustomLayers           = { 'None' },
    HudViews               = { 'Full', 'SetsOnly', 'Condensed' },
}

local function format_count_of_choices(cur, list)
    if not list or #list == 0 then
        return tostring(cur or "?")
    end

    local realTotal = #list - 1
    if realTotal <= 0 then
        return string.format("%s (0/0)", tostring(cur or "None"))
    end

    -- Find real index
    local idx = nil
    for i, v in ipairs(list) do
        if v == cur then
            idx = i
            break
        end
    end

    -- Not found or explicitly None
    if not idx or cur == 'None' then
        return string.format("None (0/%d)", realTotal)
    end

    -- Shift down because index 1 is None
    local displayIdx = idx - 1
    return string.format("%s (%d/%d)", cur, displayIdx, realTotal)
end


local function align_label(label, value) -- Label alignment
    return string.format("%-" .. HUD_LABEL_WIDTH .. "s %s", label .. ":", value or "")
end


local function set_opacity(active) -- Opacity helpers -- TODO: Opacity not working as expected, probably bets to remove
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
        table.insert(lines,
            align_label("MatrixLayer", format_count_of_choices(current_state.matrixLayer, DynamicLists.MatrixLayers)))
        table.insert(lines,
            align_label("PetMatrixLayer",
                format_count_of_choices(current_state.petMatrixLayer, DynamicLists.PetMatrixLayers)))
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
        for i, v in ipairs(DynamicLists.Matrices) do
            if v == current_state.matrixName then
                matrix_idx = i; break
            end
        end
        table.insert(lines,
            align_label("Matrix",
                string.format("%s (%d/%d)", current_state.matrixName or "?", matrix_idx, #DynamicLists.Matrices)))

        -- Matrix
        table.insert(lines,
            align_label("MatrixLayer", format_count_of_choices(current_state.matrixLayer, DynamicLists.MatrixLayers)))

        -- Pet Matrix
        local petMatrixDisplay =
            (current_state.petMatrixCombo and current_state.petMatrixCombo ~= '' and current_state.petMatrixCombo) or
            'None'

        table.insert(lines, align_label(
            "PetMatrix",
            format_count_of_choices(petMatrixDisplay, DynamicLists.PetMatrixCombos)
        ))

        -- Pet Matrix Layer
        local petMatrixLayerDisplay = 'None'
        if petMatrixDisplay ~= 'None' and DynamicLists.PetMatrixLayers and #DynamicLists.PetMatrixLayers > 0 then
            petMatrixLayerDisplay = format_count_of_choices(current_state.petMatrixLayer, DynamicLists.PetMatrixLayers)
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
-- AutoRepair ---------------------------
-----------------------------------------

local function check_auto_repair() -- TODO: Oil check is broken
    local th = tonumber(current_state.autoRepairThreshold) or 0
    if th == 0 then return end
    if not (pet and pet.isvalid and (current_state.petHP or 0) > 0) then return end

    local hp = tonumber(current_state.petHP) or tonumber(pet.hpp) or 100
    if hp > th then return end

    -- spam guard
    local now = os.time()
    if now - (current_state.lastRepairAttempt or 0) < AUTOREPAIR_SPAM_GUARD then return end

    -- Cooldown check --
    local cd = get_repair_cooldown()
    local elapsed = now - (current_state.lastRepairUsed or 0)
    if elapsed < cd then
        debug_chat(string.format("[AutoRepair] Cooldown active (%.1fs / %.1fs)", elapsed, cd))
        return
    end

    -- Check if player has oil first
    --if not has_oil() then
    -- windower.add_to_chat(167, '[AutoRepair] No Automaton Oil +3 found! AutoRepair disabled.')
    -- current_state.autoRepairThreshold = 0
    --  hud_update()
    --  return
    --end

    -- Check distance to pet
    local pet_mob = windower.ffxi.get_mob_by_target('pet')
    if not pet_mob or not pet_mob.valid_target then return end
    local distance = math.sqrt(pet_mob.distance or 0)
    if distance > REPAIR_RANGE_YALMS then
        debug_chat(string.format('[AutoRepair] Pet too far (%.1f yalms). Skipping Repair.', distance))
        return
    end

    if not can_player_act() then
        debug_chat('[AutoRepair] Player Unable To Act')
        return
    end

    debug_chat(string.format('[AutoRepair] Repair triggered (HP %.1f%% <= %d%%, %.1f yalms)', hp, th, distance))
    current_state.lastRepairAttempt = now
    windower.chat.input('/ja "Repair" <me>')
end

-----------------------------------------
-- AutoDeploy
-----------------------------------------

local function has_valid_target() --- TODO: Forgot why this is unused, did it work? Test it
    local mob = windower.ffxi.get_mob_by_target and windower.ffxi.get_mob_by_target('t')
    return mob and mob.valid and (mob.hpp or 100) > 0
end

local function auto_deploy()
    if not current_state.autoDeploy then return end
    if player.status ~= 'Engaged' or not (pet and pet.isvalid) then return end

    local now = os.time()
    if now - current_state.last_deploy_time < DEPLOY_DEBOUNCE then return end

    local target = windower.ffxi.get_mob_by_target('t')
    if not (target and target.id) then return end

    if target.id == current_state.last_engaged_target_id then return end

    current_state.last_engaged_target_id = target.id
    current_state.last_deploy_time = now + DEPLOY_DELAY

    if not can_player_act then
        debug_chat("[AutoManeuver] Player incapacitated. Skipping Auto Deploy.")
        return
    end

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

    automan.queue[#automan.queue + 1] = element
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
local function auto_maneuver_tick()
    if not automan.pending and #automan.queue == 0 then return end

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

    -- Abort if player can't act
    if not can_player_act() then
        return
    end

    -- Handle pending attempt
    if automan.pending then
        local now = os.time()

        if now - automan.pending.issued_at > automan.pending_to then
            local el = automan.pending.element

            local count = (automan.retry_counts[el] or 0) + 1
            automan.retry_counts[el] = count

            if count >= automan.max_retries then
                debug_chat(string.format("[AutoManeuver] %s failed %d times - giving up.", el, count))
                dequeue_maneuver(el)
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
    for _, v in ipairs(list) do
        if v == current_state.matrixName then
            found = true
            break
        end
    end
    if not found then current_state.matrixName = list[1] end
end

-- Collect layer keys from an active matrix (engaged/idle → master/pet/masterPet → {layers})
local function collect_matrix_layers_from(groupNode, collector)
    if type(groupNode) ~= 'table' then return end
    for _, subTable in pairs(groupNode) do
        if type(subTable) == 'table' then
            for layerKey, maybeSet in pairs(subTable) do
                if type(maybeSet) == 'table' then collector[layerKey] = true end
            end
        end
    end
end

local function build_layers()
    local layersSet = {}
    local currentMatrix = safe_get(_G, 'matrices', current_state.matrixName)

    if currentMatrix then
        collect_matrix_layers_from(currentMatrix.engaged, layersSet)
        collect_matrix_layers_from(currentMatrix.idle, layersSet)
    end

    local layers = ordered_keys(layersSet)

    -- Add default "None" at the top
    DynamicLists.MatrixLayers = { 'None' }
    for _, key in ipairs(layers) do
        DynamicLists.MatrixLayers[#DynamicLists.MatrixLayers + 1] = key
    end

    -- Validate current selection
    local valid = false
    for _, key in ipairs(DynamicLists.MatrixLayers) do
        if key == current_state.matrixLayer then
            valid = true
            break
        end
    end

    if not valid then current_state.matrixLayer = 'None' end
end

-- Build PetMatrix combos/layers from the active matrix
local function build_pet_matrix_lists()
    DynamicLists.PetMatrixCombos = { 'None' }
    DynamicLists.PetMatrixLayers = { 'None' }
    DynamicLists.PetMatrixLayersByCombo = {}

    local currentMatrix = safe_get(_G, 'matrices', current_state.matrixName)
    local petMatrix = currentMatrix and currentMatrix.petMatrix or nil
    if not petMatrix then return end

    local combosSet = {}
    for _, statusNode in pairs({ petMatrix.idle, petMatrix.engaged }) do
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

                -- Always include None for each combo
                local finalLayers = { 'None' }
                for _, lk in ipairs(layerKeys) do
                    finalLayers[#finalLayers + 1] = lk
                end

                DynamicLists.PetMatrixLayersByCombo[combo] = finalLayers
            end
        end
    end

    local combos = ordered_keys(combosSet)

    -- Add default "None" at the top
    for _, key in ipairs(combos) do
        if v ~= 'None' then
            DynamicLists.PetMatrixCombos[#DynamicLists.PetMatrixCombos + 1] = key
        end
    end

    -- Validate current selection (so state doesn't get stuck on an invalid value)
    local comboOk = false
    for _, key in ipairs(DynamicLists.PetMatrixCombos) do
        if key == current_state.petMatrixCombo then
            comboOk = true; break
        end
    end

    if not comboOk then current_state.petMatrixCombo = 'None' end

    -- Update current combo's layers
    local layers = DynamicLists.PetMatrixLayersByCombo[current_state.petMatrixCombo] or { 'None' }
    DynamicLists.PetMatrixLayers = layers

    local layerOk = false
    for _, v in ipairs(layers) do
        if v == current_state.petMatrixLayer then
            layerOk = true
            break
        end
    end

    if not layerOk then current_state.petMatrixLayer = 'None' end
end

local function update_pet_matrix_layers_for_combo(combo)
    local layers = DynamicLists.PetMatrixLayersByCombo[combo] or { 'None' }
    DynamicLists.PetMatrixLayers = layers

    local found = false
    for _, layerName in ipairs(layers) do
        if layerName == current_state.petMatrixLayer then
            found = true
            break
        end
    end

    if not found then current_state.petMatrixLayer = 'None' end
end

local function build_custom_layers() -- TODO: Order of custom layers is alphabetical but would prefer they be ordered the same as they are entered in PUP-LIB
    local list = { 'None' }
    if sets and sets.layers and sets.layers.CustomLayers then
        for _, layerName in ipairs(ordered_keys(sets.layers.CustomLayers)) do list[#list + 1] = layerName end
    end

    DynamicLists.CustomLayers = list

    -- Validate current
    local ok = false
    for _, layerName in ipairs(list) do
        if layerName == current_state.customLayer then
            ok = true
            break
        end
    end

    if not ok then current_state.customLayer = 'None' end
end

-----------------------------------------
-- Gear Resolver -- TODO: State value for Pre/postcast to get setnames for JAs, spells, etc displayed in the HUD
-----------------------------------------
local function resolve_gear(state)
    local set = {}
    local setName = ''

    local playerStatus = state.playerStatus
    local petStatus = state.petStatus
    local playerEngaged = playerStatus == 'Engaged'
    local petEngaged = petStatus == 'Engaged'
    local engageStatus = (playerEngaged or petEngaged) and 'engaged' or 'idle'

    -- Select active matrix table
    local currentMatrix = safe_get(_G, 'matrices', state.matrixName)
    if not currentMatrix then
        debug_chat('[GS] - Active matrix "' .. tostring(state.matrixName) .. '" not found.')
    end


    -------------------------------------------------
    -- BASE SET (Taken From Active Matrix)
    -------------------------------------------------
    if currentMatrix then
        set = currentMatrix.baseSet
        setName = state.matrixName .. '.baseSet'
    end

    -------------------------------------------------
    -- PRIMARY MATRIX LAYER
    -------------------------------------------------
    if currentMatrix then
        local layer = state.matrixLayer or 'None'

        if layer ~= 'None' then
            if playerEngaged and petEngaged then -- Both engaged
                set = combine_safe(set,
                    safe_get(currentMatrix, engageStatus, 'masterPet', layer))
                setName = ':' .. state.matrixName .. '.' .. engageStatus .. '.masterPet.' .. layer
            elseif playerEngaged and not petEngaged then -- Player Engaged, Pet Idle
                set = combine_safe(set,
                    safe_get(currentMatrix, engageStatus, 'master', layer))
                setName = ':' .. state.matrixName .. '.' .. engageStatus .. '.master.' .. layer
            elseif not playerEngaged and petEngaged then -- Player Idle, Pet Engaged
                set = combine_safe(set,
                    safe_get(currentMatrix, engageStatus, 'pet', layer))
                setName = ':' .. state.matrixName .. '.' .. engageStatus .. '.pet.' .. layer
            end
        end
    end

    -------------------------------------------------
    -- PET MATRIX LAYER
    -------------------------------------------------
    local petMatrix = currentMatrix and currentMatrix.petMatrix or nil
    if petMatrix and state.petMatrixCombo and state.petMatrixCombo ~= 'None' then
        local petCombo = state.petMatrixCombo
        local pmLayer = state.petMatrixLayer or 'Normal'

        local pmSet = safe_get(petMatrix, engageStatus, petCombo, pmLayer)
        if pmSet and pmSet ~= 'None' then
            set = combine_safe(set, pmSet)
            setName = setName ..
                '+petMatrix.' ..
                engageStatus ..
                '.' .. petCombo .. '.' .. (pmSet == safe_get(petMatrix, engageStatus, petCombo, pmLayer) and pmLayer)
        end
    end

    -------------------------------------------------
    -- CUSTOM LAYER
    -------------------------------------------------
    if sets.layers and sets.layers.CustomLayers and state.customLayer ~= 'Off' then
        local custom = sets.layers.CustomLayers[state.customLayer]
        if custom then
            set = combine_safe(set, custom)
            setName = setName .. '+custom.' .. state.customLayer
        end
    end


    -------------------------------------------------
    -- TOWN SET -- TODO: Current list of town IDs is incomplete with some incorrect IDs. Maybe check zone name instead of ID
    -------------------------------------------------
    if Towns[state.currentZoneId] and sets and sets.town then
        set = combine_safe(set, sets.town)
        setName = setName .. '+ sets.town'
    end

    -------------------------------------------------
    -- PET ENMITY SET
    -------------------------------------------------
    if auto_enmity_state.active and (petEngaged or playerEngaged) then
        set = combine_safe(set, sets.pet.enmity)
        setName = setName .. '+ sets.pet.enmity'
    end

    -------------------------------------------------
    -- PET WS SWAP SET (Taken from active matrix)
    -------------------------------------------------
    if current_state.autoPetWSToggle and current_state.autoPetWS and current_state.autoPetWS.active and currentMatrix then
        local petWSSet = currentMatrix.petMatrix.weaponskills[current_state.petType]
        if petWSSet then
            set = combine_safe(set, petWSSet)
            setName = setName .. '+ sets.petMatrix.weaponskills.' .. current_state.petType
        elseif not petWSSet then
            debug_chat('[PUPTrix AutoPetWS]: No matching set found in petmatrix.weaponskills for' ..
                current_state.petType)
        end
    end


    debug_chat('[PUPTRix Gear] Set: ' .. setName .. '')
    return set, setName
end

-----------------------------------------
-- Equip & Event Handling
-----------------------------------------
local function equip_and_update()
    local set, setName = resolve_gear(current_state)
    current_state.activeSetName = setName
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

    -- TODO: This logic can be moved to utility function, it is repeated in pet_change
    local petHead = pet.head
    local petFrame = pet.frame
    local shorthandHead = PUP_HEAD_MAP[petHead]
    local shorthandFrame = PUP_FRAME_MAP[petFrame]

    if shorthandHead and shorthandFrame then
        current_state.petType = shorthandHead .. "_" .. shorthandFrame
        local debugmsg = "[PUPTrix] - Pet Status Changed: " ..
            shorthandHead .. "_" .. shorthandFrame .. " - Status: " .. new
        debug_chat(debugmsg)
    end

    equip_and_update()
end

function pet_change(p, gain)
    if p then
        if gain then -- New pet activated
            local petHead = p.head
            local petFrame = p.frame
            local shorthandHead = PUP_HEAD_MAP[petHead]
            local shorthandFrame = PUP_FRAME_MAP[petFrame]
            local petTypeCombo = shorthandHead .. "_" .. shorthandFrame

            current_state.petStatus = p and p.status or 'Idle'

            if shorthandHead and shorthandFrame then
                local debugmsg = "[PUPTrix] - Pet Changed: " .. petTypeCombo
                debug_chat(debugmsg)
                current_state.petType = petTypeCombo
                current_state.petMatrixCombo = petTypeCombo
                update_pet_matrix_layers_for_combo(petTypeCombo)
            end
        else -- Pet is lost/deactivated
            current_state.petStatus = 'None'
            current_state.petType = ''
            debug_chat("[PUPTrix] - Pet Lost!")

            -- Clear automaneuver queue when puppet deactivated/dies
            if #automan.queue > 0 or automan.pending then
                debug_chat("[AutoManeuver] Puppet Lost Clearing Maneuver Queue")
                automan.queue = {}
                automan.pending = nil
                automan.retry_counts = {}
            end

            -- Clear auto enmity set statuses when puppet deactivated/dies
            if auto_enmity_state.active then
                debug_chat("[AutoEnmity] Puppet lost — Resetting Enmity Tracking")

                auto_enmity_state = {
                    active = false,
                    ability = nil,
                    timer = 0
                }
            end
        end
    end

    equip_and_update()
end

function precast(spell, action, spellMap, eventArgs)
    -- TODO: Support PUPPET casting
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
        local now = os.time()
        dequeue_maneuver(automan.pending.element)
        automan.last_use              = now
        automan.pending               = nil
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

    ------------------------------------------------------------
    -- AutoPetWS Edge Case: Prime Pet WS gear before Deploy to avoid race condition with pet status
    ------------------------------------------------------------
    if spell and spell.english == 'Deploy' then
        local pettp = (pet and pet.isvalid and pet.tp) or 0
        local playertp = (player and player.tp) or 0
        local petInhibitor = pet.attachments.inhibitor or pet.attachments["inhibitor II"]

        if petInhibitor and playertp >= 899
        then
            return
        end

        if current_state.autoPetWSToggle and pettp >= PET_WS_TP_THRESHOLD then
            local wsSet = get_pet_ws_set()
            if wsSet then
                -- Equip immediately so gear is on before Deploy executes
                equip(wsSet)

                current_state.petStatus = 'Engaged'
                current_state.autoPetWS.active = true
                current_state.autoPetWS.timer = os.time() + PET_WS_ACTIVE_WINDOW


                debug_chat(string.format(
                    "[AutoPetWS] Primed on Deploy (TP=%d >= %d). Equipping WS set before Deploy.",
                    pettp, PET_WS_TP_THRESHOLD
                ))
            else
                debug_chat("[AutoPetWS] Deploy prime: no WS set found for petType=" .. tostring(current_state.petType))
            end
        end
    end
end

function midcast(spell, action, spellMap, eventArgs)
    --TODO: Support puppet casting
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
    -- Tracking cooldown for Repair & AutoRepair system
    if spell and spell.english == 'Repair' then
        if not spell.interrupted then
            local now = os.time()
            current_state.lastRepairUsed = now
            current_state.lastRepairAttempt = now
            debug_chat(string.format('[AutoRepair] Repair detected. Cooldown synced at %.2f', now))
        else
            debug_chat('[AutoRepair] Repair was interrupted; cooldown NOT updated.')
        end
    end

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
    local secondAgo = os.time() - 1.5

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
    -- If this loss happened right before or after a manual JA, treat it as intentional; don't queue.
    if secondAgo < (automan.manual_suppress_until or 0) then
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
    equip_and_update()
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
                if buffactive["Fire Maneuver"] and (pet.attachments.strobe or pet.attachments["strobe II"]) and Strobe_Recast <= 1 then
                    auto_enmity_state.active = true
                    auto_enmity_state.ability = "Strobe"
                    auto_enmity_state.timer = os.time() + PET_ENMITY_WINDOW
                    debug_chat("[AutoEnmity] Strobe - Enmity Gear Window Open")
                    equip_and_update()
                elseif buffactive["Light Maneuver"] and pet.attachments.flashbulb and Flashbulb_Recast <= 1 then
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
        elseif current_state.autoEnmity
            and (player.hpp <= 0 or not pet or not pet.isvalid) then
            debug_chat("[AutoEnmity] Player / Pet dead or invalid - Enmity Gear Window Closed")
            auto_enmity_state.active = false
            auto_enmity_state.ability = nil
            auto_enmity_state.timer = 0
            equip_and_update()
        end

        ------------------------------------


        -- Auto Pet WS Set Logic
        if not (pet and pet.isvalid and current_state.autoPetWSToggle) then return end
        local petInhibitor = pet.attachments.inhibitor or pet.attachments["inhibitor II"]
        local pettp = pet.tp or 0
        local playertp = player.tp or 0

        -- Lockout protection -- TODO: Not sure if needed, lockout hurts more than helps
        -- if now < current_state.autoPetWS.lockout then return end

        -- Enter Pet WS Mode
        if not current_state.autoPetWS.active and pettp >= PET_WS_TP_THRESHOLD and puppet_is_engaged() then
            if petInhibitor and playertp >= 899 then
                -- When Inhibitors are equipped puppet will not WS if player has > 899 TP, so we do not equip the pet WS set
                return
            end

            current_state.autoPetWS.active = true
            current_state.autoPetWS.timer = now + PET_WS_ACTIVE_WINDOW
            debug_chat(string.format("[AutoPetWS] Pet TP %d >= %d, swapping to WS set", pettp, PET_WS_TP_THRESHOLD))
            equip_and_update()
            return
        end

        -- Exit after timer or TP drop or pet leaving combat
        if current_state.autoPetWS.active and (pettp < PET_WS_TP_THRESHOLD or now > current_state.autoPetWS.timer) then
            debug_chat("[AutoPetWS] Pet WS window ended - reverting gear")
            current_state.autoPetWS.active = false
            current_state.autoPetWS.lockout = now -- No lockout time applied in this scenario
            equip_and_update()
        end
    end)
end

-----------------------------------------
-- Auto Deploy / Target Change Hook
-----------------------------------------
if not target_change_event_registered and windower and windower.register_event then
    windower.register_event('target change', function()
        -- If toggle is on, player exists and is engaged & puppet exists and is not already engaged
        if current_state.autoDeploy and player and player.status == 'Engaged' and pet.isvalid and not puppet_is_engaged then
            auto_deploy()
        end
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
            -- Delay gear swap on zone so that the swap occurs after player has loaded in
            coroutine.schedule(equip_and_update, 3)
        end
    end)
    zone_change_hook_registered = true
end

-----------------------------------------
-- Incoming Text Parsing Hook
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
-- User Commands
-----------------------------------------
-- Used to cycle cyclable commands - autoRepair command
local function cycle(field, list)
    if not list or #list == 0 then return end
    local idx = 1
    for i, v in ipairs(list) do
        if v == current_state[field] then
            idx = i
            break
        end
    end
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
        elseif which == 'matrixlayer' then
            cycle('matrixLayer', DynamicLists.MatrixLayers)
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
            for i, v in ipairs(thresholds) do
                if v == cur then
                    idx = i
                    break
                end
            end
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
            windower.add_to_chat(122, '[AutoPetEnmity] ' .. (current_state.autoEnmity and 'On' or 'Off'))

            -- Clear any pending when disabling
            if not current_state.autoEnmity then
                auto_enmity_state = {
                    active = false,
                    ability = nil,
                    timer = 0
                }
            end
        elseif which == 'autopetws' then
            current_state.autoPetWSToggle = not current_state.autoPetWSToggle
            windower.add_to_chat(122, '[AutoPetWS] ' .. (current_state.autoPetWSToggle and 'On' or 'Off'))
            -- Clear any pending when disabling
            if not current_state.autoPetWSToggle then
                autoPetWS = {
                    active = false,
                    timer = 0,
                    lockout = 0
                }
            end
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
            windower.add_to_chat(122, '[AutoManeuver] ' .. (current_state.autoManeuver and 'On' or 'Off'))
            -- Clear any pending when disabling
            if not current_state.autoManeuver then
                automan.queue = {}
                automan.pending = nil
                automan.retry_counts = {}
            end
        end
        -- TODO: Specific to autoDeploy logic to trigger Deploy action. Probably not necessary, could wrap into autodeploy logic
    elseif c == '__auto_deploy_fire' then
        windower.send_command('input /pet "Deploy" <t>')
    end

    equip_and_update()
end
