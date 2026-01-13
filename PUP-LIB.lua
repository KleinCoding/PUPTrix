-- Puppetmaster helper library

-- Accessing windower data
local res                            = require('resources')

-- Text renderer for HUD
local texts                          = require('texts')

-- Instantiate const for HUD
local hud                            = nil

-----------------------------------------
-- Hook booleans --
-----------------------------------------
local target_change_event_registered = false
local prerender_registered           = false
local zone_change_hook_registered    = false
local incoming_text_hook_registered  = false

-----------------------------------------
-- CONSTS
-----------------------------------------
local Towns                          = {
    [246] = "Ru'Lude Gardens",
    [236] = "Port Bastok",
    [50]  = "Port Jeuno",
    [51]  = "Lower Jeuno",
    [52]  = "Upper Jeuno",
    [53]  = "Rabao",
}

local MANEUVER_MAP                   = {
    ["Fire Maneuver"]    = "Fire",
    ["Water Maneuver"]   = "Water",
    ["Wind Maneuver"]    = "Wind",
    ["Earth Maneuver"]   = "Earth",
    ["Thunder Maneuver"] = "Thunder",
    ["Ice Maneuver"]     = "Ice",
    ["Light Maneuver"]   = "Light",
    ["Dark Maneuver"]    = "Dark",
}

local PUP_HEAD_MAP                   = {
    ["Harlequin Head"]    = "Harle",
    ["Valoredge Head"]    = "Valor",
    ["Sharpshot Head"]    = "Sharp",
    ["Stormwaker Head"]   = "Storm",
    ["Soulsoother Head"]  = "Soul",
    ["Spiritreaver Head"] = "Spirit",
}

local PUP_FRAME_MAP                  = {
    ["Harlequin Frame"]  = "Harle",
    ["Valoredge Frame"]  = "Valor",
    ["Sharpshot Frame"]  = "Sharp",
    ["Stormwaker Frame"] = "Storm",
}

local DynamicLists                   = {
    Matrices               = { 'gear_matrix' },
    MatrixLayers           = { 'None' },
    PetMatrixCombos        = { 'None' },
    PetMatrixLayers        = { 'None' },
    PetMatrixLayersByCombo = { 'None' },
    CustomLayers           = { 'None' },
    HudViews               = { 'Full', 'SetsOnly', 'Condensed' },
}

-- TODO: Weapon Cycle
-- TODO: Animator Cycle
-- TODO: Expand Debug mode. 'Off' 'Light' and 'Full' settings.
-- TODO: Pet Casting Set Support
-- TODO: HUD updates. Mini, Lite, and Full modes. Mini only shows sets and abbreviated modes (if on), Lite shows Matrix/Layers & Sets and shows modes (if on). Full shows all data and shows hotkeys
-- TODO: Commands to alter HUD position/opacity via ingame command
-- TODO: AutoPetWS: If lockout is 0, disable lockout logic/keep set on
-- TODO: Move HUD code to HUD file
-- TODO: Consume varialbes from -VARS file
-- TODO: Kiting Mode
-- TODO: Emergency DT Set Button
-- TODO: Track Flashbulb/Strobe cooldown even when feature is off? Otherwise logic assumes the voke/flash are ready when turned on mid combat

-----------------------------------------
-- State
-----------------------------------------
CURRENT_STATE                        = {
    -- Matrix & Matrix Layers state
    matrixName     = 'gear_matrix', -- the key in global `matrices` to use
    matrixLayer    = 'None',        -- key for active matrix layer

    -- Pet Matrix & Pet Matrix Layers state --
    petMatrixCombo = 'None', -- Key for active pet type to take from Pet Matrix e.g., "Valor_Valor", "Sharp_Sharp", etc.
    petMatrixLayer = 'None', -- key for active pet matrix layer

    -- Custom Layers state
    customLayer    = 'Off', -- active custom set key (sets.layers.CustomLayers.*)

    -- Utility Toggles
    debugMode      = false, --TODO: Derive initial value from VARS

    -- Misc
    currentZoneId  = 'None', -- For managing Town sets
}

PLAYER_STATE                         = {
    ps_player_status = 'Idle', -- Current player state - Idle, Engaged
    ps_pet_status    = 'None', -- Current pet state - None, Idle, Engaged
    ps_pet_type      = '',     -- Current Pet Type - Valor_Valor, Sharp_Valor, Storm_Storm, etc.
    ps_pet_hp        = 0,
}

HUD_STATE                            = { -- TODO: Many of these values should be customizable with VARs file
    hud_view     = 'Full',               -- current HUD layout mode - Full, SetsOnly, Condensed
    hud_set_name = 'None',               -- Text string of current sets, for HUD display
    hud_settings = {                     -- Should probably be separated once HUD is moved to HUD file
        hud_border_alpha      = 175,     -- Border transparency (0–255)
        hud_bg_alpha          = 80,      -- Background transparency (0–255)
        hud_label_width       = 20,      -- Fixed label width for alignment
        hud_text_alpha        = 150,
        hud_text_stroke_alpha = 125,
        pos                   = { x = 2200, y = 700 },
        bg                    = { alpha = 150, red = 20, green = 20, blue = 20 },
        flags                 = { draggable = true },
        text                  = {
            font = 'Consolas',
            size = 10,
            stroke = { width = 1, alpha = 100 },
            red = 255,
            green = 255,
            blue = 255,
            alpha = 150
        },
    }
}

WEAPONCYCLE_STATE                    = {
    wc_weapon_lock   = true, --TODO: Derive initial value from VARS
    wc_weapon_list   = Weapons,
    wc_animator_list = Animators,
}

AUTOMANEUVER_STATE                   = {
    am_toggle_on       = false,
    am_queue           = {},  -- FIFO of elements to reapply
    am_last_attempt    = 0,   -- os.time() of last attempt (player or script)
    am_cooldown        = 11,  -- seconds between maneuvers
    am_retry_delay     = 3,   -- seconds to wait before retrying a failed attempt
    am_pending         = nil, -- { element="Fire", issued_at=timestamp }
    am_pending_window  = 3,   -- seconds allowed for buff to appear after issuing
    am_suppress_until  = 0,   -- timestamp; while now < this, ignore buff-loss queues
    am_suppress_window = 3,   -- seconds to ignore loss events after a manual JA
    am_retry_counts    = {},  -- { ["Fire"] = 1, ["Water"] = 3, ... }
    am_max_retries     = 3,   -- TODO: Take from VARs
}

AUTODEPLOY_STATE                     = {
    ad_toggle_on              = false,
    ad_last_deploy_timestamp  = 0,
    ad_last_engaged_target_id = 0,
    ad_deploy_cooldown        = 5,   --TODO: VARs
    ad_debounce_time          = 0.5, -- TODO: VARs
    ad_deploy_delay           = 2.5, -- TODO: VARs
}

AUTOENMITY_STATE                     = {
    ae_toggle_on = false,
    ae_window_open = false,
    ae_tracked_ability = nil,    -- 'Strobe' or 'Flashbulb'
    ae_expiration_timestamp = 0, -- expiration timestamp
    ae_flashbulb_cd = 45,
    ae_flashbulb_lockout = 0,
    ae_flashbulb_timestamp = 0,
    ae_strobe_cd = 45,
    ae_strobe_lockout = 0,
    ae_strobe_timestamp = 0,
    ae_equip_window = 3 -- TODO: VARs
}

AUTOREPAIR_STATE                     = {
    ar_active_threshold       = 0,                     -- AUTOREPAIR_STATE.ar_thresholds = {0, 20, 40, 55, 70}
    ar_cooldown_upgrades      = 5,                     -- 0–5; each level reduces cooldown by 3 s -- TODO: Make settings const
    ar_last_attempt           = 0,                     -- timestamp of last repair attempt (whether success or fail)
    ar_last_used              = 0,                     -- timestamp of last successful repair
    ar_pet_hp_timestamp       = 0,                     -- timestamp of last time script updated petHP value
    ar_pet_hp_update_interval = 1.0,                   -- Once per second
    ar_thresholds             = { 0, 20, 40, 55, 70 }, -- TODO: move to VARs
    ar_repair_base_cooldown   = 90,
    ar_upgrade_reduction      = 3,
    ar_max_upgrade_level      = 5,
    ar_repair_range           = 20,
    ar_spamguard_lockout      = 3.5 -- TODO: VARs
}

AUTOPETWS_STATE                      = {
    apw_toggle_on = false,
    apw_set_active = false,
    apw_timer = 0,
    apw_lockout = 0,        --TODO: make a user config, and add 'overdriveLockout' for OD scenarios TODO: If lockout is 0, disable lockout logic/keep set on
    apw_tp_threshold = 990, -- configurable trigger TP (e.g. 900/1000) TODO: Move to VARS file
    apw_active_window = 4,  -- seconds to stay in WS gear before check TODO: Move to VARS File
    apw_lockout_window = 3, -- UNUSED seconds after WS before allowing reactivation TODO: Move to VARS file
    apw_last_ws_time = 0,   -- UNUSED
    apw_ws_window = false,  -- UNUSED
}

-----------------------------------------
-- Utility Functions
-----------------------------------------

local function starts_with(str, start) -- check if a string starts with another string
    return str and start and str:sub(1, #start) == start
end

local function debug_chat(msg) -- Sends messages to chat based on debug toggle status
    -- TODO: Expand debug chat options from on/off to Off, Full, and Light
    if CURRENT_STATE.debugMode then windower.add_to_chat(122, msg) end
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
    local lvl = math.min(AUTOREPAIR_STATE.ar_cooldown_upgrades or 0, AUTOREPAIR_STATE.ar_max_upgrade_level)
    return AUTOREPAIR_STATE.ar_repair_base_cooldown - (lvl * AUTOREPAIR_STATE.ar_upgrade_reduction)
end

local function update_pet_hp() -- Updates pet HP to state
    local now = os.clock()
    if now - AUTOREPAIR_STATE.ar_pet_hp_timestamp < AUTOREPAIR_STATE.ar_pet_hp_update_interval then return end
    AUTOREPAIR_STATE.ar_pet_hp_timestamp = now

    local pet_mob = windower.ffxi.get_mob_by_target('pet')
    if pet_mob and pet_mob.hpp then
        PLAYER_STATE.ps_pet_hp = pet_mob.hpp
    elseif pet and pet.hpp then
        PLAYER_STATE.ps_pet_hp = pet.hpp
    else
        PLAYER_STATE.ps_pet_hp = 0
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
    local currentMatrix = safe_get(_G, 'matrices', CURRENT_STATE.matrixName)
    if not currentMatrix or not currentMatrix.petMatrix or not currentMatrix.petMatrix.weaponskills then
        return nil
    end
    return currentMatrix.petMatrix.weaponskills[PLAYER_STATE.ps_pet_type]
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

-----------------------------------------
-- HUD Renderer
-----------------------------------------

local function align_label(label, value) -- Label alignment
    return string.format("%-" .. HUD_STATE.hud_settings.hud_label_width .. "s %s", label .. ":", value or "")
end

local function hud_update()
    if not hud then return end
    local lines = {}

    -------------------------------------------------
    -- Sets Only HUD
    -------------------------------------------------
    if HUD_STATE.hud_view == 'SetsOnly' then
        -- Compact one-line display
        if HUD_STATE.hud_set_name and HUD_STATE.hud_set_name ~= 'None' then
            local combined = HUD_STATE.hud_set_name:gsub("%+", "  ➜  ")
            table.insert(lines, "Sets: " .. combined)
        else
            table.insert(lines, "Sets: None")
        end

        -------------------------------------------------
        -- Condensed HUD
        -------------------------------------------------
    elseif HUD_STATE.hud_view == 'Condensed' then
        table.insert(lines,
            align_label("MatrixLayer", format_count_of_choices(CURRENT_STATE.matrixLayer, DynamicLists.MatrixLayers)))
        table.insert(lines,
            align_label("PetMatrixLayer",
                format_count_of_choices(CURRENT_STATE.petMatrixLayer, DynamicLists.PetMatrixLayers)))
        table.insert(lines, align_label("AutoDeploy", AUTODEPLOY_STATE.ad_toggle_on and 'On' or 'Off'))

        -- Only show AutoManeuver in Condensed view if it's enabled
        if AUTOMANEUVER_STATE.am_toggle_on then
            table.insert(lines, align_label("AutoManeuver", "On"))
        end

        -- Only show AutoDeploy in Condensed view if it's enabled
        if AUTODEPLOY_STATE.ad_toggle_on then
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
        for i, matrixName in ipairs(DynamicLists.Matrices) do
            if matrixName == CURRENT_STATE.matrixName then
                matrix_idx = i; break
            end
        end
        table.insert(lines,
            align_label("Matrix",
                string.format("%s (%d/%d)", CURRENT_STATE.matrixName or "?", matrix_idx, #DynamicLists.Matrices)))

        -- Matrix
        table.insert(lines,
            align_label("MatrixLayer", format_count_of_choices(CURRENT_STATE.matrixLayer, DynamicLists.MatrixLayers)))

        -- Pet Matrix
        local petMatrixDisplay =
            (CURRENT_STATE.petMatrixCombo and CURRENT_STATE.petMatrixCombo ~= '' and CURRENT_STATE.petMatrixCombo) or
            'None'

        table.insert(lines, align_label(
            "PetMatrix",
            format_count_of_choices(petMatrixDisplay, DynamicLists.PetMatrixCombos)
        ))

        -- Pet Matrix Layer
        local petMatrixLayerDisplay = 'None'
        if petMatrixDisplay ~= 'None' and DynamicLists.PetMatrixLayers and #DynamicLists.PetMatrixLayers > 0 then
            petMatrixLayerDisplay = format_count_of_choices(CURRENT_STATE.petMatrixLayer, DynamicLists.PetMatrixLayers)
        end
        table.insert(lines, align_label("PetMatrixLayer", petMatrixLayerDisplay))

        -- Custom Layer
        local customDisplay = (CURRENT_STATE.customLayer and CURRENT_STATE.customLayer ~= 'Off')
            and CURRENT_STATE.customLayer or 'None'


        table.insert(lines, align_label("CustomLayer", customDisplay))
        table.insert(lines, align_label("Player", PLAYER_STATE.ps_player_status))
        table.insert(lines, align_label("Pet", PLAYER_STATE.ps_pet_status))
        table.insert(lines, align_label("AutoDeploy", AUTODEPLOY_STATE.ad_toggle_on and 'On' or 'Off'))
        table.insert(lines, align_label("Debug", CURRENT_STATE.debugMode and 'On' or 'Off'))
        table.insert(lines, align_label("AutoManeuver", AUTOMANEUVER_STATE.am_toggle_on and 'On' or 'Off'))
        table.insert(lines, align_label("WeaponLock", WEAPONCYCLE_STATE.wc_weapon_lock and 'On' or 'Off'))

        local threshold = tonumber(AUTOREPAIR_STATE.ar_active_threshold) or 0
        local arText = (threshold == 0) and 'Off' or (string.format("%d%%", threshold))
        table.insert(lines, align_label("AutoRepair", arText))


        -- Set breakdown (bottom of full HUD) -- TODO: Make a util
        if HUD_STATE.hud_set_name and HUD_STATE.hud_set_name ~= 'None' then
            local setLines = {}
            for segment in HUD_STATE.hud_set_name:gmatch("[^+]+") do
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
    local th = tonumber(AUTOREPAIR_STATE.ar_active_threshold) or 0
    if th == 0 then return end
    if not (pet and pet.isvalid and (PLAYER_STATE.ps_pet_hp or 0) > 0) then return end

    local hp = tonumber(PLAYER_STATE.ps_pet_hp) or tonumber(pet.hpp) or 100
    if hp > th then return end

    -- spam guard
    local now = os.time()
    if now - (AUTOREPAIR_STATE.ar_last_attempt or 0) < AUTOREPAIR_STATE.ar_spamguard_lockout then return end

    -- Cooldown check --
    local cd = get_repair_cooldown()
    local elapsed = now - (AUTOREPAIR_STATE.ar_last_used or 0)
    if elapsed < cd then
        return
    end

    -- Check if player has oil first
    --if not has_oil() then
    -- windower.add_to_chat(167, '[AutoRepair] No Automaton Oil +3 found! AutoRepair disabled.')
    -- AUTOREPAIR_STATE.ar_active_threshold= 0
    --  hud_update()
    --  return
    --end

    -- Check distance to pet
    local pet_mob = windower.ffxi.get_mob_by_target('pet')
    if not pet_mob or not pet_mob.valid_target then return end
    local distance = math.sqrt(pet_mob.distance or 0)
    if distance > AUTOREPAIR_STATE.ar_repair_range then
        debug_chat(string.format('[AutoRepair] Pet too far (%.1f yalms). Skipping Repair.', distance))
        return
    end

    if not can_player_act() then
        debug_chat('[AutoRepair] Player Unable To Act')
        return
    end

    debug_chat(string.format('[AutoRepair] Repair triggered (HP %.1f%% <= %d%%, %.1f yalms)', hp, th, distance))
    AUTOREPAIR_STATE.ar_last_attempt = now
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
    if not AUTODEPLOY_STATE.ad_toggle_on then return end
    if player.status ~= 'Engaged' or not (pet and pet.isvalid) then return end

    local now = os.time()
    if now - AUTODEPLOY_STATE.ad_last_deploy_timestamp < AUTODEPLOY_STATE.ad_debounce_time then return end

    local target = windower.ffxi.get_mob_by_target('t')
    if not (target and target.id) then return end

    if target.id == AUTODEPLOY_STATE.ad_last_engaged_target_id then return end

    AUTODEPLOY_STATE.ad_last_engaged_target_id = target.id
    AUTODEPLOY_STATE.ad_last_deploy_timestamp = now + AUTODEPLOY_STATE.ad_deploy_delay

    if not can_player_act then
        debug_chat("[AutoManeuver] Player incapacitated. Skipping Auto Deploy.")
        return
    end

    if puppet_is_engaged() then
        debug_chat('[AutoDeploy] Puppet already engaged. Skipping.')
        return
    end

    send_command('@wait ' .. tostring(AUTODEPLOY_STATE.ad_deploy_delay) .. '; gs c __auto_deploy_fire')
    debug_chat(string.format('[AutoDeploy] Triggered for new target (delay %.1f sec)', AUTODEPLOY_STATE.ad_deploy_delay))
end

-----------------------------------------
-- Auto-Maneuver System
-----------------------------------------

local function is_maneuver_buff(name)
    return MANEUVER_MAP[name]
end

local function enqueue_maneuver(element)
    if not element then return end

    AUTOMANEUVER_STATE.am_queue[#AUTOMANEUVER_STATE.am_queue + 1] = element
    debug_chat(string.format("[AutoManeuver] Queued %s maneuver for reapply", element))
end

local function dequeue_maneuver(element)
    if not element then return end
    for i, e in ipairs(AUTOMANEUVER_STATE.am_queue) do
        if e == element then
            table.remove(AUTOMANEUVER_STATE.am_queue, i)
            return
        end
    end
end

local function can_attempt_maneuver()
    if AUTOMANEUVER_STATE.am_pending then return false end
    local now = os.time()
    if (now - AUTOMANEUVER_STATE.am_last_attempt) < AUTOMANEUVER_STATE.am_cooldown then return false end

    -- Ensure player is alive and pet is active
    if not player or player.status == 'Dead' then return false end
    if not pet or not pet.isvalid then return false end

    return true
end


local function try_cast_next_maneuver()
    if #AUTOMANEUVER_STATE.am_queue == 0 or not can_attempt_maneuver() then return end

    local element = AUTOMANEUVER_STATE.am_queue[1]
    AUTOMANEUVER_STATE.am_pending = { element = element, issued_at = os.time() }
    AUTOMANEUVER_STATE.am_last_attempt = os.time()

    windower.send_command('input /ja "' .. element .. ' Maneuver" <me>')
    debug_chat(string.format("[AutoManeuver] Attempting %s Maneuver", element))
end

-- Called every frame by prerender hook
local function auto_maneuver_tick()
    if not AUTOMANEUVER_STATE.am_pending and #AUTOMANEUVER_STATE.am_queue == 0 then return end

    if not (pet and pet.isvalid and pet.hpp > 0) then
        if #AUTOMANEUVER_STATE.am_queue > 0 or AUTOMANEUVER_STATE.am_pending then
            debug_chat("[AutoManeuver] Puppet inactive — clearing queue/pending")
        end
        AUTOMANEUVER_STATE.am_queue = {}
        AUTOMANEUVER_STATE.am_pending = nil
        AUTOMANEUVER_STATE.am_retry_counts = {}
        return
    end

    if not can_player_act() then
        return
    end

    -- Handle pending attempt
    if AUTOMANEUVER_STATE.am_pending then
        local now = os.time()

        if now - AUTOMANEUVER_STATE.am_pending.issued_at > AUTOMANEUVER_STATE.am_pending_window then
            local el = AUTOMANEUVER_STATE.am_pending.element

            local count = (AUTOMANEUVER_STATE.am_retry_counts[el] or 0) + 1
            AUTOMANEUVER_STATE.am_retry_counts[el] = count

            if count >= AUTOMANEUVER_STATE.am_max_retries then
                debug_chat(string.format("[AutoManeuver] %s failed %d times - giving up.", el, count))
                dequeue_maneuver(el)
                AUTOMANEUVER_STATE.am_retry_counts[el] = nil
            else
                debug_chat(string.format("[AutoManeuver] %s timeout (attempt %d/%d) - requeueing",
                    el, count, AUTOMANEUVER_STATE.am_max_retries))
                AUTOMANEUVER_STATE.am_last_attempt = os.time() - AUTOMANEUVER_STATE.am_cooldown +
                    AUTOMANEUVER_STATE.am_retry_delay
                enqueue_maneuver(el)
            end
        end

        return
    end

    -- No pending: try next from queue
    try_cast_next_maneuver()
end

-----------------------------------------
-- Dynamic Builders -- TODO: Make utils easier to read, maybe make some utils to replicate javascript array methods
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
    for _, matrixName in ipairs(list) do
        if matrixName == CURRENT_STATE.matrixName then
            found = true
            break
        end
    end
    if not found then CURRENT_STATE.matrixName = list[1] end
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
    local currentMatrix = safe_get(_G, 'matrices', CURRENT_STATE.matrixName)

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
        if key == CURRENT_STATE.matrixLayer then
            valid = true
            break
        end
    end

    if not valid then CURRENT_STATE.matrixLayer = 'None' end
end

-- Build PetMatrix combos/layers from the active matrix
local function build_pet_matrix_lists()
    DynamicLists.PetMatrixCombos = { 'None' }
    DynamicLists.PetMatrixLayers = { 'None' }
    DynamicLists.PetMatrixLayersByCombo = {}

    local currentMatrix = safe_get(_G, 'matrices', CURRENT_STATE.matrixName)
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
        if key ~= 'None' then
            DynamicLists.PetMatrixCombos[#DynamicLists.PetMatrixCombos + 1] = key
        end
    end

    -- Validate current selection (so state doesn't get stuck on an invalid value)
    local comboOk = false
    for _, key in ipairs(DynamicLists.PetMatrixCombos) do
        if key == CURRENT_STATE.petMatrixCombo then
            comboOk = true; break
        end
    end

    if not comboOk then CURRENT_STATE.petMatrixCombo = 'None' end

    -- Update current combo's layers
    local layers = DynamicLists.PetMatrixLayersByCombo[CURRENT_STATE.petMatrixCombo] or { 'None' }
    DynamicLists.PetMatrixLayers = layers

    local layerOk = false
    for _, v in ipairs(layers) do
        if v == CURRENT_STATE.petMatrixLayer then
            layerOk = true
            break
        end
    end

    if not layerOk then CURRENT_STATE.petMatrixLayer = 'None' end
end

local function update_pet_matrix_layers_for_combo(combo)
    local layers = DynamicLists.PetMatrixLayersByCombo[combo] or { 'None' }
    DynamicLists.PetMatrixLayers = layers

    local found = false
    for _, layerName in ipairs(layers) do
        if layerName == CURRENT_STATE.petMatrixLayer then
            found = true
            break
        end
    end

    if not found then CURRENT_STATE.petMatrixLayer = 'None' end
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
        if layerName == CURRENT_STATE.customLayer then
            ok = true
            break
        end
    end

    if not ok then CURRENT_STATE.customLayer = 'None' end
end

-----------------------------------------
-- Gear Resolver -- TODO: State value for Pre/postcast to get setnames for JAs, spells, etc displayed in the HUD
-----------------------------------------
local function resolve_gear(state)
    local set = {}
    local setName = ''
    local priorityLayer = nil

    local playerEngaged = PLAYER_STATE.ps_player_status == 'Engaged'
    local petEngaged = PLAYER_STATE.ps_pet_status == 'Engaged'
    local engageStatus = (playerEngaged or petEngaged) and 'engaged' or 'idle'

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
    if currentMatrix then -- TODO: Make a util to format all these strings for the HUD sets display
        local layer = state.matrixLayer or 'None'

        if layer ~= 'None' then
            if playerEngaged and petEngaged then -- Both engaged
                local newSet = safe_get(currentMatrix, engageStatus, 'masterPet', layer) or {}
                if newSet.priority then
                    priorityLayer = newSet
                end

                set = combine_safe(set, newSet)
                setName = ':' .. state.matrixName .. '.' .. engageStatus .. '.masterPet.' .. layer
            elseif playerEngaged and not petEngaged then -- Player Engaged, Pet Idle
                local newSet = safe_get(currentMatrix, engageStatus, 'master', layer) or {}
                if newSet.priority then
                    priorityLayer = newSet
                end

                set = combine_safe(set, newSet)
                setName = ':' .. state.matrixName .. '.' .. engageStatus .. '.master.' .. layer
            elseif not playerEngaged and petEngaged then -- Player Idle, Pet Engaged
                local newSet = safe_get(currentMatrix, engageStatus, 'pet', layer) or {}
                if newSet.priority then
                    priorityLayer = newSet
                end

                set = combine_safe(set, newSet)
                setName = ':' .. state.matrixName .. '.' .. engageStatus .. '.pet.' .. layer
            elseif not playerEngaged and not petEngaged then -- Both Idle
                local newSet = safe_get(currentMatrix, engageStatus, 'masterPet', layer) or {}
                if newSet.priority then
                    priorityLayer = newSet
                end

                set = combine_safe(set, newSet)
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
        local pmLayer = state.petMatrixLayer or 'None'

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
    -- PRIORITY MATRIX LAYER
    -------------------------------------------------
    if priorityLayer then
        set = combine_safe(set, priorityLayer)
        priorityLayer = nil
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
    if AUTOENMITY_STATE.ae_window_open and (petEngaged or playerEngaged) then
        set = combine_safe(set, sets.pet.enmity)
        setName = setName .. '+ sets.pet.enmity'
    end

    -------------------------------------------------
    -- PET WS SWAP SET (Taken from active matrix)
    -------------------------------------------------
    if AUTOPETWS_STATE.apw_toggle_on and AUTOPETWS_STATE.apw_set_active and currentMatrix then
        local petWSSet = currentMatrix.petMatrix.weaponskills[PLAYER_STATE.ps_pet_type]
        if petWSSet then
            set = combine_safe(set, petWSSet)
            setName = setName .. '+ sets.petMatrix.weaponskills.' .. PLAYER_STATE.ps_pet_type
        elseif not petWSSet then
            debug_chat('[PUPTrix AutoPetWS]: No matching set found in petmatrix.weaponskills for' ..
                PLAYER_STATE.ps_pet_type)

        elseif not PLAYER_STATE.ps_pet_type then
            debug_chat('[PUPTrix AutoPetWS]: Pet Type not set. Activate or Deploy to set.' ..
                PLAYER_STATE.ps_pet_type)
        end
    end


    debug_chat('[PUPTRix Gear] Set: ' .. setName .. '')
    return set, setName
end

-----------------------------------------
-- Equip & Event Handling
-----------------------------------------
local function equip_and_update()
    local set, setName = resolve_gear(CURRENT_STATE)
    HUD_STATE.hud_set_name = setName
    equip(set)
    hud_update()
end

function status_change(new, old)
    PLAYER_STATE.ps_player_status = new

    if new == 'Engaged' and AUTODEPLOY_STATE.ad_toggle_on then auto_deploy() end
    if new == 'Engaged' then equip_and_update() end
    if new == 'Idle' then equip_and_update() end
end

function job_status_change(new, old)
    status_change(new, old)
end

function pet_status_change(new, old)
    if not pet or not pet.isvalid then
        PLAYER_STATE.ps_pet_status = 'None'
    else
        PLAYER_STATE.ps_pet_status = new
    end

    -- TODO: This logic can be moved to utility function, it is repeated in pet_change
    local petHead = pet.head
    local petFrame = pet.frame
    local shorthandHead = PUP_HEAD_MAP[petHead]
    local shorthandFrame = PUP_FRAME_MAP[petFrame]

    if shorthandHead and shorthandFrame then
        PLAYER_STATE.ps_pet_type = shorthandHead .. "_" .. shorthandFrame
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

            PLAYER_STATE.ps_pet_status = p and p.status or 'Idle'

            if shorthandHead and shorthandFrame then
                local debugmsg = "[PUPTrix] - Pet Changed: " .. petTypeCombo
                debug_chat(debugmsg)
                PLAYER_STATE.ps_pet_type = petTypeCombo
                CURRENT_STATE.petMatrixCombo = petTypeCombo
                update_pet_matrix_layers_for_combo(petTypeCombo)
            end
        else -- Pet is lost/deactivated
            PLAYER_STATE.ps_pet_status = 'None'
            PLAYER_STATE.ps_pet_type = ''
            debug_chat("[PUPTrix] - Pet Lost!")

            -- Clear automaneuver queue when puppet deactivated/dies
            if #AUTOMANEUVER_STATE.am_queue > 0 or AUTOMANEUVER_STATE.am_pending then
                debug_chat("[AutoManeuver] Puppet Lost Clearing Maneuver Queue")
                AUTOMANEUVER_STATE.am_queue = {}
                AUTOMANEUVER_STATE.am_pending = nil
                AUTOMANEUVER_STATE.am_retry_counts = {}
            end

            -- Clear auto enmity set statuses when puppet deactivated/dies
            if AUTOENMITY_STATE.ae_window_open then
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

        if AUTOMANEUVER_STATE and AUTOMANEUVER_STATE.am_pending and AUTOMANEUVER_STATE.am_pending.element then
            dequeue_maneuver(AUTOMANEUVER_STATE.am_pending.element)
        end

        AUTOMANEUVER_STATE.am_last_attempt   = now
        AUTOMANEUVER_STATE.am_pending        = nil
        AUTOMANEUVER_STATE.am_suppress_until = now + AUTOMANEUVER_STATE.am_suppress_window
        debug_chat(string.format(
            "[PUPTrix AutoManeuver] %s detected",
            name, AUTOMANEUVER_STATE.am_suppress_window
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
    -- AutoPetWS
    ------------------------------------------------------------
    if spell and spell.english == 'Deploy' then
        local pettp = (pet and pet.isvalid and pet.tp) or 0
        local playertp = (player and player.tp) or 0
        local petInhibitor = pet.attachments.inhibitor or pet.attachments["inhibitor II"]

        if petInhibitor and playertp >= 899
        then
            return
        end

        if AUTOPETWS_STATE.apw_toggle_on and pettp >= AUTOPETWS_STATE.apw_tp_threshold then
            local wsSet = get_pet_ws_set()
            if wsSet then
                -- Equip immediately so gear is on before Deploy executes
                equip(wsSet)

                PLAYER_STATE.ps_pet_status = 'Engaged'
                AUTOPETWS_STATE.apw_set_active = true
                AUTOPETWS_STATE.apw_timer = os.time() + AUTOPETWS_STATE.apw_active_window


                debug_chat(string.format(
                    "[AutoPetWS] Primed on Deploy (TP=%d >= %d). Equipping WS set before Deploy.",
                    pettp, AUTOPETWS_STATE.apw_tp_threshold
                ))
            else
                debug_chat("[AutoPetWS] Deploy prime: no WS set found for petType=" .. tostring(PLAYER_STATE.ps_pet_type))
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
            AUTOREPAIR_STATE.ar_last_used = now
            AUTOREPAIR_STATE.ar_last_attempt = now
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
            AUTOMANEUVER_STATE.am_last_attempt = os.time() - AUTOMANEUVER_STATE.am_cooldown +
                AUTOMANEUVER_STATE.am_retry_delay
            debug_chat('[AutoManeuver] Interrupted; re-queue ' .. el)
            AUTOMANEUVER_STATE.am_pending = nil
        else
            -- successful attempt; pending will be cleared on buff gain (buff_change)
            AUTOMANEUVER_STATE.am_last_attempt = os.time()
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
        if AUTOMANEUVER_STATE.am_pending and AUTOMANEUVER_STATE.am_pending.element == el then
            debug_chat(string.format("[AutoManeuver] %s buff regained (cleared pending)", el))
            AUTOMANEUVER_STATE.am_pending          = nil
            AUTOMANEUVER_STATE.am_queue            = {}
            AUTOMANEUVER_STATE.am_retry_counts[el] = nil
        end
        return
    end

    -- LOST a maneuver stack
    -- If this loss happened right before or after a manual JA, treat it as intentional; don't queue.
    if secondAgo < (AUTOMANEUVER_STATE.am_suppress_until or 0) then
        debug_chat(string.format("[AutoManeuver] Ignoring loss of %s (within manual suppress window)", el))
        return
    end

    -- Only queue if AutoManeuver is enabled: treat as a natural expiration / failed buff
    if AUTOMANEUVER_STATE.am_toggle_on then
        debug_chat(string.format("[AutoManeuver] %s maneuver expired/removed - queueing refresh", el))
        enqueue_maneuver(el)
    end
end

function target_change(new_id)
    if player.status ~= 'Engaged' then return end
    if not AUTODEPLOY_STATE.ad_toggle_on then return end

    -- tiny debounce to avoid spam on rapid target swaps
    local now = os.clock()
    if now - AUTODEPLOY_STATE.ad_last_deploy_timestamp < AUTODEPLOY_STATE.ad_deploy_cooldown then return end
    AUTODEPLOY_STATE.ad_last_deploy_timestamp = now

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
        hud = texts.new(HUD_STATE.hud_settings)
        hud:bg_visible(true)
        hud:bg_color(30, 30, 30)
        hud:bg_alpha(HUD_STATE.hud_settings.hud_bg_alpha)
        hud:stroke_color(200, 200, 200, HUD_STATE.hud_settings.hud_border_alpha)
        hud:color(255, 255, 255, 255)
    end

    -- Build dynamic lists
    build_matrices()
    build_layers()
    build_pet_matrix_lists()
    build_custom_layers()

    -- Weaponlock
    if WEAPONCYCLE_STATE.wc_weapon_lock then
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
        if AUTOMANEUVER_STATE.am_toggle_on then
            auto_maneuver_tick()
        end

        if AUTOREPAIR_STATE.ar_active_threshold ~= 0 then
            update_pet_hp()
            check_auto_repair()
        end

        -- Pet JA Tracking
        if AUTOENMITY_STATE.ae_strobe_lockout > 0 then
            AUTOENMITY_STATE.ae_strobe_lockout = AUTOENMITY_STATE
                .ae_strobe_cd - (now - AUTOENMITY_STATE.ae_strobe_timestamp)
        end
        if AUTOENMITY_STATE.ae_flashbulb_lockout > 0 then
            AUTOENMITY_STATE.ae_flashbulb_lockout = AUTOENMITY_STATE
                .ae_flashbulb_cd - (now - AUTOENMITY_STATE.ae_flashbulb_timestamp)
        end


        -- Auto Pet Enmity Set Logic
        if pet and pet.isvalid and player.hpp > 0 and puppet_is_engaged() and AUTOENMITY_STATE.ae_toggle_on then
            if not AUTOENMITY_STATE.ae_window_open then
                if buffactive["Fire Maneuver"] and (pet.attachments.strobe or pet.attachments["strobe II"]) and AUTOENMITY_STATE.ae_strobe_lockout <= 1 then
                    AUTOENMITY_STATE.ae_window_open = true
                    AUTOENMITY_STATE.ae_tracked_ability = "Strobe"
                    AUTOENMITY_STATE.ae_expiration_timestamp = os.time() + AUTOENMITY_STATE.ae_equip_window
                    debug_chat("[AutoEnmity] Strobe - Enmity Gear Window Open")
                    equip_and_update()
                elseif buffactive["Light Maneuver"] and pet.attachments.flashbulb and AUTOENMITY_STATE.ae_flashbulb_lockout <= 1 then
                    AUTOENMITY_STATE.ae_window_open = true
                    AUTOENMITY_STATE.ae_tracked_ability = "Flashbulb"
                    AUTOENMITY_STATE.ae_expiration_timestamp = os.time() + AUTOENMITY_STATE.ae_equip_window
                    debug_chat("[AutoEnmity] Flashbulb - Enmity Gear Window Open")
                    equip_and_update()
                end
            else
                -- expiration
                if os.time() > AUTOENMITY_STATE.ae_expiration_timestamp then
                    debug_chat("[AutoEnmity] Window expired - Enmity Gear Window Closed")
                    AUTOENMITY_STATE.ae_window_open = false
                    AUTOENMITY_STATE.ae_tracked_ability = nil
                    AUTOENMITY_STATE.ae_expiration_timestamp = 0
                    equip_and_update()
                end
            end
        elseif AUTOENMITY_STATE.ae_toggle_on
            and (player.hpp <= 0 or not pet or not pet.isvalid) then
            debug_chat("[AutoEnmity] Player / Pet dead or invalid - Enmity Gear Window Closed")
            AUTOENMITY_STATE.ae_window_open = false
            AUTOENMITY_STATE.ae_tracked_ability = nil
            AUTOENMITY_STATE.ae_expiration_timestamp = 0
            equip_and_update()
        end

        ------------------------------------


        -- Auto Pet WS Set Logic
        if not (pet and pet.isvalid and AUTOPETWS_STATE.apw_toggle_on) then return end
        local petInhibitor = pet.attachments.inhibitor or pet.attachments["inhibitor II"]
        local pettp = pet.tp or 0
        local playertp = player.tp or 0

        -- Lockout protection -- TODO: Not sure if needed, lockout hurts more than helps
        -- if now < AUTOPETWS_STATE.apw_lockout then return end

        -- Enter Pet WS Mode
        if not AUTOPETWS_STATE.apw_set_active and pettp >= AUTOPETWS_STATE.apw_tp_threshold and puppet_is_engaged() then
            if petInhibitor and playertp >= 899 then
                -- When Inhibitors are equipped puppet will not WS if player has > 899 TP, so we do not equip the pet WS set
                return
            end

            AUTOPETWS_STATE.apw_set_active = true
            AUTOPETWS_STATE.apw_timer = now + AUTOPETWS_STATE.apw_active_window
            debug_chat(string.format("[AutoPetWS] Pet TP %d >= %d, swapping to WS set", pettp,
                AUTOPETWS_STATE.apw_tp_threshold))
            equip_and_update()
            return
        end

        -- Exit after timer or TP drop or pet leaving combat
        if AUTOPETWS_STATE.apw_set_active and (pettp < AUTOPETWS_STATE.apw_tp_threshold or now > AUTOPETWS_STATE.apw_timer) then
            debug_chat("[AutoPetWS] Pet WS window ended - reverting gear")
            AUTOPETWS_STATE.apw_set_active = false
            AUTOPETWS_STATE.apw_lockout = now -- No lockout time applied in this scenario
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
        if AUTODEPLOY_STATE.ad_toggle_on and player and player.status == 'Engaged' and pet.isvalid and not puppet_is_engaged then
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
        CURRENT_STATE.currentZoneId = new_id
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
        if not AUTOENMITY_STATE.ae_toggle_on then return end
        if not original or not pet or not pet.isvalid then return end
        if not original:contains(pet.name) then return end

        if original:contains("Provoke") then
            AUTOENMITY_STATE.ae_strobe_timestamp = os.time()
            AUTOENMITY_STATE.ae_strobe_lockout = AUTOENMITY_STATE.ae_strobe_cd

            debug_chat("[AutoEnmity] Strobe fired - Enmity Set Removed!")
            AUTOENMITY_STATE.ae_window_open = false
            AUTOENMITY_STATE.ae_tracked_ability = nil
            AUTOENMITY_STATE.ae_expiration_timestamp = 0

            equip_and_update()
        elseif original:contains("Flashbulb") then
            AUTOENMITY_STATE.ae_flashbulb_timestamp = os.time()
            AUTOENMITY_STATE.ae_flashbulb_lockout = AUTOENMITY_STATE.ae_flashbulb_cd


            debug_chat("[AutoEnmity] Flashbulb fired - Enmity Set Removed!")
            AUTOENMITY_STATE.ae_window_open = false
            AUTOENMITY_STATE.ae_tracked_ability = nil
            AUTOENMITY_STATE.ae_expiration_timestamp = 0
            equip_and_update()
        end
    end)

    incoming_text_hook_registered = true
end

-----------------------------------------
-- User Commands
-----------------------------------------
-- Used to cycle cyclable commands - autoRepair, matrices, layers etc
local function cycle(field, list)
    if not list or #list == 0 then return end
    local idx = 1
    for i, v in ipairs(list) do
        if v == CURRENT_STATE[field] then
            idx = i
            break
        end
    end
    CURRENT_STATE[field] = list[(idx % #list) + 1]
    debug_chat('[GS] ' .. field .. ' -> ' .. CURRENT_STATE[field])
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
            update_pet_matrix_layers_for_combo(CURRENT_STATE.petMatrixCombo)
            windower.add_to_chat(122, string.format('[PUPtrix] Cycling PetMatrix'))
        elseif which == 'petmatrixlayer' then
            cycle('petMatrixLayer', DynamicLists.PetMatrixLayers)
            windower.add_to_chat(122, string.format('[PUPtrix] Cycling PetMatrix Layer'))
        elseif which == 'customlayer' then
            cycle('customLayer', DynamicLists.CustomLayers)
            windower.add_to_chat(122, string.format('[PUPtrix] Cycling Custom Layer'))
        elseif which == 'hudview' then
            cycle('hudView', DynamicLists.hud_views)
            hud_update()
            windower.add_to_chat(122, string.format('[PUPtrix] HUD View set to %s', HUD_STATE.hud_view))
        elseif which == 'autorepair' then
            local thresholds = AUTOREPAIR_STATE.ar_thresholds
            local cur = AUTOREPAIR_STATE.ar_active_threshold or 0
            local idx = 1
            for i, v in ipairs(thresholds) do
                if v == cur then
                    idx = i
                    break
                end
            end
            AUTOREPAIR_STATE.ar_active_threshold = thresholds[(idx % #thresholds) + 1]

            local disp = (AUTOREPAIR_STATE.ar_active_threshold == 0) and 'Off'
                or (tostring(AUTOREPAIR_STATE.ar_active_threshold) .. '%')

            windower.add_to_chat(122, '[AutoRepair] Threshold: ' .. disp)
            hud_update()
        end
    elseif c == 'toggle' then
        local which = (args[2] or ''):lower()
        if which == 'autodeploy' then
            AUTODEPLOY_STATE.ad_toggle_on = not AUTODEPLOY_STATE.ad_toggle_on
            windower.add_to_chat(122, '[AutoDeploy] ' .. (AUTODEPLOY_STATE.ad_toggle_on and 'On' or 'Off'))
        elseif which == 'autopetenmity' then
            AUTOENMITY_STATE.ae_toggle_on = not AUTOENMITY_STATE.ae_toggle_on
            windower.add_to_chat(122,
                '[AutoPetEnmity] ' .. (AUTOENMITY_STATE.ae_toggle_on and 'On' or 'Off'))

            -- Clear any pending when disabling
            if not AUTOENMITY_STATE.ae_toggle_on then
                auto_enmity_state = {
                    active = false,
                    ability = nil,
                    timer = 0
                }
            end
        elseif which == 'autopetws' then
            AUTOPETWS_STATE.apw_toggle_on = not AUTOPETWS_STATE.apw_toggle_on
            windower.add_to_chat(122, '[AutoPetWS] ' .. (AUTOPETWS_STATE.apw_toggle_on and 'On' or 'Off'))
            -- Clear any pending when disabling
            if not AUTOPETWS_STATE.apw_toggle_on then
                autoPetWS = {
                    active = false,
                    timer = 0,
                    lockout = 0
                }
            end
        elseif which == 'debug' then
            CURRENT_STATE.debugMode = not CURRENT_STATE.debugMode
            windower.add_to_chat(122, '[Debug] ' .. (CURRENT_STATE.debugMode and 'On' or 'Off'))
        elseif which == 'weaponlock' then
            WEAPONCYCLE_STATE.wc_weapon_lock = not WEAPONCYCLE_STATE.wc_weapon_lock
            if WEAPONCYCLE_STATE.wc_weapon_lock then
                disable('main', 'sub')
                windower.add_to_chat(122, '[WeaponLock] ON - Weapon slots locked')
            else
                enable('main', 'sub')
                windower.add_to_chat(122, '[WeaponLock] OFF - Weapon slots unlocked')
            end
        elseif which == 'automaneuver' then
            AUTOMANEUVER_STATE.am_toggle_on = not AUTOMANEUVER_STATE.am_toggle_on
            windower.add_to_chat(122, '[AutoManeuver] ' .. (AUTOMANEUVER_STATE.am_toggle_on and 'On' or 'Off'))
            -- Clear any pending when disabling
            if not AUTOMANEUVER_STATE.am_toggle_on then
                AUTOMANEUVER_STATE.am_queue = {}
                AUTOMANEUVER_STATE.am_pending = nil
                AUTOMANEUVER_STATE.am_retry_counts = {}
            end
        end
    elseif c == '__auto_deploy_fire' then
        windower.send_command('input /pet "Deploy" <t>')
    end

    equip_and_update()
end
