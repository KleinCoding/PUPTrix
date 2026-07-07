-- Puppetmaster helper library

-- Accessing windower data
local res = require('resources')

-- HUD code lives in PUP-HUD.lua (include it before this file); all access
-- goes through the PUP_HUD table.
if not PUP_HUD then
    windower.add_to_chat(167, '[PUPTrix] PUP-HUD.lua is not loaded! include(\'PUP-HUD.lua\') before PUP-LIB.')
end

-- User-tunable values live in PUP-USER.lua (include it FIRST); command
-- changes persist via the User Settings section below.
if not PUP_USER then
    windower.add_to_chat(122, '[PUPTrix] PUP-USER.lua not loaded - using built-in defaults.')
end

-- File IO for the user-settings overrides file
local files = require('files')

-- PUP_USER lookup with fallback; runs at state-table construction time
local function user_var(section, key, default)
    if type(PUP_USER) == 'table' then
        local sect = PUP_USER[section]
        if type(sect) == 'table' and sect[key] ~= nil then
            return sect[key]
        end
    end
    return default
end

-----------------------------------------
-- Hook booleans --
-----------------------------------------
local target_change_event_registered = false
local prerender_registered           = false
local zone_change_hook_registered    = false
local incoming_text_hook_registered  = false
local pet_action_event_registered    = false

-----------------------------------------
-- CONSTS
-----------------------------------------
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
    Matrices                      = { 'gear_matrix' },
    MatrixLayersIdle              = { 'None' },
    MatrixLayersEngaged           = { 'None' },
    PetMatrixCombos               = { 'None' },
    PetMatrixLayersIdle           = { 'None' },
    PetMatrixLayersEngaged        = { 'None' },
    PetMatrixLayersByComboIdle    = { 'None' },
    PetMatrixLayersByComboEngaged = { 'None' },
    CustomLayers                  = { 'None' },
    DefenseLayers                 = { 'None' },
    SpeedLayers                   = { 'None' },
}

-- TODO: Expand Debug mode. 'Off' 'Light' and 'Full' settings.

-----------------------------------------
-- State
-----------------------------------------
MATRIX_STATE                         = {
    -- Matrix & Matrix Layers state
    matrixName            = 'gear_matrix', -- the key in global `matrices` to use
    matrixLayerIdle       = nil,           -- selected layer for the idle tree
    matrixLayerEngaged    = nil,           -- selected layer for the engaged tree

    -- Pet Matrix & Pet Matrix Layers state --
    petMatrixCombo        = 'None', -- active pet type combo; driven by pet_change (never first-layer defaulted)
    petMatrixLayerIdle    = nil,    -- selected pet layer for the idle tree
    petMatrixLayerEngaged = nil,    -- selected pet layer for the engaged tree

    -- Custom Layers state
    customLayer           = 'Off', -- active custom set key (sets.layers.CustomLayers.*)
    defenseLayer          = 'Off', -- active defense set key (sets.layers.DefenseLayers.*) - emergency DT
    speedLayer            = 'Off', -- active speed set key (sets.layers.SpeedLayers.*) - movement

    -- Utility Toggles
    debugMode             = user_var('general', 'debug_mode', false),

    -- Misc
    currentZoneId         = 'None', -- Raw zone ID (from zone change event)
    currentZoneName       = '',     -- Resolved zone name (res.zones), for zone-based sets
}

PLAYER_STATE                         = {
    ps_player_status = 'Idle', -- Current player state - Idle, Engaged
    ps_pet_status    = 'None', -- Current pet state - None, Idle, Engaged
    ps_pet_type      = '',     -- Current Pet Type - Valor_Valor, Sharp_Valor, Storm_Storm, etc.
    ps_pet_hp        = 0,
}

WEAPONCYCLE_STATE                    = { -- TODO: future feature
    wc_weapon_lock = user_var('general', 'weapon_lock', true),
    --wc_weapon_list   = user_var('general', 'weapons', Weapons),
    --wc_animator_list = user_var('general', 'animators', Animators),
}

AUTOMANEUVER_STATE                   = {
    am_toggle_on       = user_var('maneuver', 'enabled', false),
    am_queue           = {},                                         -- FIFO of elements to reapply
    am_last_attempt    = 0,                                          -- os.time() of last attempt (player or script)
    am_cooldown        = user_var('maneuver', 'cooldown', 11),       -- seconds between maneuvers
    am_retry_delay     = user_var('maneuver', 'retry_delay', 3),     -- seconds to wait before retrying a failed attempt
    am_pending         = nil,                                        -- { element="Fire", issued_at=timestamp }
    am_pending_window  = user_var('maneuver', 'pending_window', 3),  -- seconds allowed for buff to appear after issuing
    am_suppress_until  = 0,                                          -- timestamp; while now < this, ignore buff-loss queues
    am_suppress_window = user_var('maneuver', 'suppress_window', 3), -- seconds to ignore loss events after a manual JA
    am_retry_counts    = {},                                         -- { ["Fire"] = 1, ["Water"] = 3, ... }
    am_max_retries     = user_var('maneuver', 'max_retries', 3),
}

AUTODEPLOY_STATE                     = {
    ad_toggle_on              = user_var('deploy', 'enabled', false),
    ad_deploy_cooldown        = user_var('deploy', 'cooldown', 5),
    ad_debounce_time          = user_var('deploy', 'debounce_time', 0.5),
    ad_deploy_delay           = user_var('deploy', 'deploy_delay', 3.5),
    ad_last_deploy_timestamp  = 0,
    ad_last_engaged_target_id = 0,
}

-- Enmity window model: an ability is "pending" (window open, enmity set
-- worn) while engaged + attachment + maneuver buff + cooldown ready.
AUTOENMITY_STATE                     = {
    ae_toggle_on = user_var('enmity', 'enabled', false),
    ae_window_failsafe = user_var('enmity', 'window_failsafe', 10), -- seconds before assuming a missed detection
    ae_window_open = false,                                         -- true while the enmity set should be worn

    -- Strobe (Provoke): 30s cooldown
    ae_strobe_cd = 30,
    ae_strobe_pending = false,
    ae_strobe_pending_since = 0,
    ae_strobe_last_used = nil, -- os.clock(); nil = unknown, assumed ready

    -- Flashbulb (Flash): 45s cooldown
    ae_flashbulb_cd = 45,
    ae_flashbulb_pending = false,
    ae_flashbulb_pending_since = 0,
    ae_flashbulb_last_used = nil,
}

AUTOREPAIR_STATE                     = {
    ar_active_threshold       = user_var('repair', 'default_threshold', 0), -- 0 = off; cycled via gs c cycle autorepair
    ar_cooldown_upgrades      = user_var('repair', 'cooldown_upgrades', 5), -- 0-5; each level reduces cooldown by 3 s
    ar_pet_hp_update_interval = user_var('repair', 'hp_update_interval', 1.0),
    ar_thresholds             = user_var('repair', 'thresholds', { 0, 20, 40, 55, 70 }),
    ar_repair_range           = user_var('repair', 'range', 20),
    ar_oil_item_id            = user_var('repair', 'oil_item_id', ''), -- oil check item (feature currently disabled)
    ar_spamguard_lockout      = user_var('repair', 'spamguard_lockout', 3.5),
    ar_last_attempt           = 0,                                     -- timestamp of last repair attempt (whether success or fail)
    ar_last_used              = 0,                                     -- timestamp of last successful repair
    ar_pet_hp_timestamp       = 0,                                     -- timestamp of last time script updated petHP value
    ar_repair_base_cooldown   = 90,
    ar_upgrade_reduction      = 3,
    ar_max_upgrade_level      = 5,
}

AUTOPETWS_STATE                      = {                       -- TODO: add 'overdriveLockout' for OD scenarios
    apw_toggle_on = user_var('petws', 'enabled', false),       -- TODO: If lockout is 0, disable lockout logic/keep set on
    apw_tp_threshold = user_var('petws', 'tp_threshold', 990), -- pet TP that triggers the WS gear window
    apw_active_window = user_var('petws', 'active_window', 4), -- seconds to stay in WS gear before check
    apw_set_active = false,
    apw_timer = 0,
    apw_lockout = 0,
}

AUTOPETCASTING_STATE                 = {
    apc_toggle_on = user_var('petcast', 'enabled', false),
    apc_cast_failsafe = user_var('petcast', 'cast_failsafe', 10), -- seconds before assuming a lost pet aftercast
    apc_is_pet_casting = false,
    apc_cast_started = nil
}

-----------------------------------------
-- Utility Functions
-----------------------------------------

local function starts_with(str, start) -- check if a string starts with another string
    return str and start and str:sub(1, #start) == start
end

local function debug_chat(msg) -- Sends messages to chat based on debug toggle status
    if MATRIX_STATE.debugMode then windower.add_to_chat(122, msg) end
end

-- Clears in-flight auto state on player death, zone change, and pet loss.
-- Toggles are preserved. Cooldown timestamps (Repair, Strobe/Flashbulb,
-- maneuver recast gate) are deliberately kept
local function reset_auto_states(reason)
    debug_chat('[PUPTrix] Resetting auto states (' .. tostring(reason) .. ')')

    AUTOMANEUVER_STATE.am_queue = {}
    AUTOMANEUVER_STATE.am_pending = nil
    AUTOMANEUVER_STATE.am_retry_counts = {}

    AUTODEPLOY_STATE.ad_last_engaged_target_id = 0
    AUTODEPLOY_STATE.ad_last_deploy_timestamp = 0

    AUTOPETWS_STATE.apw_set_active = false
    AUTOPETWS_STATE.apw_timer = 0

    AUTOENMITY_STATE.ae_strobe_pending = false
    AUTOENMITY_STATE.ae_flashbulb_pending = false
    AUTOENMITY_STATE.ae_window_open = false

    AUTOPETCASTING_STATE.apc_is_pet_casting = false
    AUTOPETCASTING_STATE.apc_cast_started = nil
end

local function index_of(list, value)
    for i, v in ipairs(list) do
        if v == value then return i end
    end
    return nil
end

local function list_contains(list, value)
    return index_of(list, value) ~= nil
end

-- Maps automaton head/frame names to the "Head_Frame" shorthand combo
local function pet_type_combo(headName, frameName)
    local head = PUP_HEAD_MAP[headName]
    local frame = PUP_FRAME_MAP[frameName]
    if head and frame then return head .. '_' .. frame end
    return nil
end

-- Which matrix group applies for the current engagement states
local function engagement_group(playerEngaged, petEngaged)
    if playerEngaged and petEngaged then return 'masterPet' end
    if playerEngaged then return 'master' end
    if petEngaged then return 'pet' end
    return 'masterPet' -- both idle
end

-- True when the player OR the pet is engaged (the 'engaged' matrix tree).
local function is_engaged()
    return PLAYER_STATE.ps_player_status == 'Engaged'
        or PLAYER_STATE.ps_pet_status == 'Engaged'
end

-- True when the PET specifically is engaged
local function pet_is_engaged()
    return PLAYER_STATE.ps_pet_status == 'Engaged'
end

local function layer_field_for(target)
    if target == 'idle' then return 'matrixLayerIdle' end
    if target == 'engaged' then return 'matrixLayerEngaged' end
    return is_engaged() and 'matrixLayerEngaged' or 'matrixLayerIdle'
end

local function layer_list_for(target)
    local engaged = (target == 'engaged') or (target == nil and is_engaged())
    return engaged and DynamicLists.MatrixLayersEngaged or DynamicLists.MatrixLayersIdle
end

local function pet_layer_field_for(target)
    if target == 'idle' then return 'petMatrixLayerIdle' end
    if target == 'engaged' then return 'petMatrixLayerEngaged' end
    return pet_is_engaged() and 'petMatrixLayerEngaged' or 'petMatrixLayerIdle'
end

local function pet_layer_list_for(target)
    local engaged = (target == 'engaged') or (target == nil and pet_is_engaged())
    return engaged and DynamicLists.PetMatrixLayersEngaged or DynamicLists.PetMatrixLayersIdle
end

local function ordered_keys(tbl) -- Helper for matrix/set names
    local t = {}
    for k, _ in pairs(tbl or {}) do t[#t + 1] = k end
    table.sort(t)
    return t
end

-- Ordered list of layer names for a cyclable-layer array
local function cyclable_layer_names(layerArray)
    local names = {}
    if type(layerArray) == 'table' then
        for _, entry in ipairs(layerArray) do
            if type(entry) == 'table' and entry[1] ~= nil then
                names[#names + 1] = entry[1]
            end
        end
    end
    return names
end

-- Look up a layer set by name in a cyclable-layer array, or nil.
local function cyclable_layer_set(layerArray, name)
    if type(layerArray) == 'table' then
        for _, entry in ipairs(layerArray) do
            if type(entry) == 'table' and entry[1] == name then
                return entry[2]
            end
        end
    end
    return nil
end

-- Builds a cycle list from `entries`, placing the 'None' sentinel per the
-- matrix.default_first_layer[flKey] user setting
local function list_with_none(entries, flKey)
    local firstLayer = flKey and user_var('matrix', 'default_first_layer', {})[flKey] == true
    local list = {}
    if not firstLayer then list[1] = 'None' end
    for _, e in ipairs(entries) do
        if e ~= 'None' then list[#list + 1] = e end
    end
    if firstLayer then list[#list + 1] = 'None' end
    return list
end

local function combine_safe(a, b) -- Combines two sets, tolerating nil operands
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

local function get_repair_cooldown()
    local lvl = math.min(AUTOREPAIR_STATE.ar_cooldown_upgrades or 0, AUTOREPAIR_STATE.ar_max_upgrade_level)
    return AUTOREPAIR_STATE.ar_repair_base_cooldown - (lvl * AUTOREPAIR_STATE.ar_upgrade_reduction)
end

local function update_pet_hp()
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

local function puppet_is_engaged()
    local puppet = windower.ffxi.get_mob_by_target('pet')
    if not puppet or not puppet.valid_target then return false end

    -- Assuming Status 1+ => engaged
    if puppet.status and puppet.status == 1 then
        return true
    end

    return false
end

local function get_pet_ws_set()
    local currentMatrix = safe_get(_G, 'matrices', MATRIX_STATE.matrixName)
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

-----------------------------------------
-- User Settings Handling
-----------------------------------------
-- Command-driven changes save to data/puptrix-user-<char>.txt and apply
-- over PUP-USER on load. Only USER_SETTING_MAP keys persist in .txt file;
-- `gs c user reset` restores the load-time values.

-- key -> { state table, field, load-time default }
local USER_SETTING_MAP = {
    ['general.debug_mode']       = { tbl = MATRIX_STATE, field = 'debugMode', default = MATRIX_STATE.debugMode },
    ['general.weapon_lock']      = { tbl = WEAPONCYCLE_STATE, field = 'wc_weapon_lock', default = WEAPONCYCLE_STATE.wc_weapon_lock },
    ['maneuver.enabled']         = { tbl = AUTOMANEUVER_STATE, field = 'am_toggle_on', default = AUTOMANEUVER_STATE.am_toggle_on },
    ['deploy.enabled']           = { tbl = AUTODEPLOY_STATE, field = 'ad_toggle_on', default = AUTODEPLOY_STATE.ad_toggle_on },
    ['petws.enabled']            = { tbl = AUTOPETWS_STATE, field = 'apw_toggle_on', default = AUTOPETWS_STATE.apw_toggle_on },
    ['enmity.enabled']           = { tbl = AUTOENMITY_STATE, field = 'ae_toggle_on', default = AUTOENMITY_STATE.ae_toggle_on },
    ['petcast.enabled']          = { tbl = AUTOPETCASTING_STATE, field = 'apc_toggle_on', default = AUTOPETCASTING_STATE.apc_toggle_on },
    ['repair.default_threshold'] = { tbl = AUTOREPAIR_STATE, field = 'ar_active_threshold', default = AUTOREPAIR_STATE.ar_active_threshold },
}

local user_overrides = {}       -- ex: { ['deploy.enabled'] = true, ... }
local user_overrides_file = nil -- files handle; created in load_user_overrides

-- Writes all overrides, one "key=value" per line (sorted)
local function write_user_overrides()
    if not user_overrides_file then return end
    local lines = {}
    for k, v in pairs(user_overrides) do
        lines[#lines + 1] = k .. '=' .. tostring(v)
    end
    table.sort(lines)
    user_overrides_file:write(table.concat(lines, '\n'))
end

-- Persists a command-driven change; non-persistable keys are ignored
local function persist_user_setting(key, value)
    if not USER_SETTING_MAP[key] then return end
    user_overrides[key] = value
    write_user_overrides()
    debug_chat(string.format('[PUPTrix Settings] Saved %s = %s', key, tostring(value)))
end

-- Loads and applies overrides; lib_init calls this before acting on settings
local function load_user_overrides()
    local charName = (player and player.name) or 'default'
    user_overrides_file = files.new('data/puptrix-user-' .. charName .. '.txt', true)
    user_overrides = {}

    if user_overrides_file:exists() then
        local content = user_overrides_file:read()
        if content then
            for line in content:gmatch('[^\r\n]+') do
                local k, v = line:match('^([%w%.]+)%s*=%s*(%S+)$')
                if k and USER_SETTING_MAP[k] then
                    if v == 'true' then
                        user_overrides[k] = true
                    elseif v == 'false' then
                        user_overrides[k] = false
                    elseif tonumber(v) then
                        user_overrides[k] = tonumber(v)
                    end
                end
            end
        end
    end

    for k, entry in pairs(USER_SETTING_MAP) do
        if user_overrides[k] ~= nil then
            entry.tbl[entry.field] = user_overrides[k]
            debug_chat(string.format('[PUPTrix Settings] Override %s = %s', k, tostring(user_overrides[k])))
        end
    end
end

-- Clears overrides; load-time PUP-USER/built-in values become authoritative
local function reset_user_settings()
    user_overrides = {}
    write_user_overrides()
    for _, entry in pairs(USER_SETTING_MAP) do
        entry.tbl[entry.field] = entry.default
    end
    if WEAPONCYCLE_STATE.wc_weapon_lock then
        disable('main', 'sub')
    else
        enable('main', 'sub')
    end
end

-----------------------------------------
-- AutoRepair ---------------------------
-----------------------------------------
local function check_auto_repair()
    -- TODO: Spams every frame if not successful need to guard failed attempts
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
-- AutoEnmity ---------------------------
-----------------------------------------
local function enmity_ability_ready(lastKey, cd)
    local last = AUTOENMITY_STATE[lastKey]
    if not last then return true end
    return (os.clock() - last) >= cd
end

-- Records a detected ability use: start cooldown, clear pending
local function record_enmity_ability_use(which, source)
    local cnow = os.clock()
    if which == 'Strobe' then
        AUTOENMITY_STATE.ae_strobe_last_used = cnow
        AUTOENMITY_STATE.ae_strobe_pending = false
    elseif which == 'Flashbulb' then
        AUTOENMITY_STATE.ae_flashbulb_last_used = cnow
        AUTOENMITY_STATE.ae_flashbulb_pending = false
    end
    debug_chat(string.format('[AutoEnmity] %s use detected (%s) - cooldown started', which, source))
end

-- Per-ability window state machine
local function enmity_tick_ability(baseCondition, buffName, pendingKey, sinceKey, lastKey, cd, label)
    local cnow = os.clock()
    local condition = baseCondition and buffactive[buffName]
        and enmity_ability_ready(lastKey, cd)

    if condition then
        if not AUTOENMITY_STATE[pendingKey] then
            AUTOENMITY_STATE[pendingKey] = true
            AUTOENMITY_STATE[sinceKey] = cnow
            debug_chat(string.format('[AutoEnmity] %s ready (%s up) - window pending', label, buffName))
        elseif cnow - (AUTOENMITY_STATE[sinceKey] or cnow) > AUTOENMITY_STATE.ae_window_failsafe then
            -- Missed detection: seeding the cooldown prevents reopen-flap
            AUTOENMITY_STATE[lastKey] = cnow
            AUTOENMITY_STATE[pendingKey] = false
            debug_chat(string.format(
                '[AutoEnmity] %s failsafe (%ds, no use detected) - seeding cooldown and closing',
                label, AUTOENMITY_STATE.ae_window_failsafe))
        end
    elseif AUTOENMITY_STATE[pendingKey] then
        -- Conditions dropped before the ability fired: cancel, no cooldown
        AUTOENMITY_STATE[pendingKey] = false
        debug_chat(string.format('[AutoEnmity] %s window cancelled (conditions no longer met)', label))
    end
end

-- Prerender tick; returns true when the window open/closed state changed
local function auto_enmity_tick()
    local prev = AUTOENMITY_STATE.ae_window_open

    if not AUTOENMITY_STATE.ae_toggle_on then
        AUTOENMITY_STATE.ae_strobe_pending = false
        AUTOENMITY_STATE.ae_flashbulb_pending = false
        AUTOENMITY_STATE.ae_window_open = false
        return prev ~= AUTOENMITY_STATE.ae_window_open
    end

    local petUp = pet and pet.isvalid and player and player.hpp > 0
    local engaged = petUp and puppet_is_engaged()
    local attachments = (petUp and pet.attachments) or nil

    local strobeBase = engaged and attachments
        and (attachments.strobe or attachments["strobe II"]) and true or false
    local flashbulbBase = engaged and attachments
        and attachments.flashbulb and true or false

    enmity_tick_ability(strobeBase, "Fire Maneuver",
        'ae_strobe_pending', 'ae_strobe_pending_since', 'ae_strobe_last_used',
        AUTOENMITY_STATE.ae_strobe_cd, 'Strobe')
    enmity_tick_ability(flashbulbBase, "Light Maneuver",
        'ae_flashbulb_pending', 'ae_flashbulb_pending_since', 'ae_flashbulb_last_used',
        AUTOENMITY_STATE.ae_flashbulb_cd, 'Flashbulb')

    AUTOENMITY_STATE.ae_window_open =
        AUTOENMITY_STATE.ae_strobe_pending or AUTOENMITY_STATE.ae_flashbulb_pending

    if AUTOENMITY_STATE.ae_window_open ~= prev then
        debug_chat('[AutoEnmity] Enmity gear window ' ..
            (AUTOENMITY_STATE.ae_window_open and 'OPEN' or 'CLOSED'))
        return true
    end
    return false
end

-----------------------------------------
-- AutoDeploy
-----------------------------------------
local function auto_deploy()
    if not AUTODEPLOY_STATE.ad_toggle_on then return end
    if player.status ~= 'Engaged' or not (pet and pet.isvalid) then
        debug_chat('[PUPTrix AutoDeploy] - Player not engaged / Pet not valid. Skipping.')
        return
    end

    local now = os.time()
    if now - AUTODEPLOY_STATE.ad_last_deploy_timestamp < AUTODEPLOY_STATE.ad_debounce_time then
        debug_chat('[AutoDeploy] Debounce Window. Skipping.')
        return
    end

    local target = windower.ffxi.get_mob_by_target('t')
    if not (target and target.id) then
        debug_chat('[AutoDeploy] No Target!. Skipping.')
        return
    end

    if target.id == AUTODEPLOY_STATE.ad_last_engaged_target_id then
        debug_chat('[AutoDeploy] Target hasnt changed. Skipping.')
        return
    end

    if not can_player_act then
        debug_chat("[AutoManeuver] Player incapacitated. Skipping.")
        return
    end

    if puppet_is_engaged() then
        debug_chat('[AutoDeploy] Puppet already engaged. Skipping.')
        return
    end

    send_command('@wait ' .. tostring(AUTODEPLOY_STATE.ad_deploy_delay) .. '; gs c __auto_deploy_fire')

    AUTODEPLOY_STATE.ad_last_engaged_target_id = target.id
    AUTODEPLOY_STATE.ad_last_deploy_timestamp = now + AUTODEPLOY_STATE.ad_deploy_delay
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
-- Dynamic Builders --
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

    if not list_contains(list, MATRIX_STATE.matrixName) then
        MATRIX_STATE.matrixName = list[1]
    end
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
    local currentMatrix = safe_get(_G, 'matrices', MATRIX_STATE.matrixName)

    -- Idle and engaged lists are built independently from their own trees, so
    -- divergent layer names between the two states are fully supported.
    local idleSet, engagedSet = {}, {}
    if currentMatrix then
        collect_matrix_layers_from(currentMatrix.idle, idleSet)
        collect_matrix_layers_from(currentMatrix.engaged, engagedSet)
    end

    DynamicLists.MatrixLayersIdle    = list_with_none(ordered_keys(idleSet), 'matrix_layer')
    DynamicLists.MatrixLayersEngaged = list_with_none(ordered_keys(engagedSet), 'matrix_layer')

    -- Validate each selection against its own list (nil -> defaults to list[1])
    if not list_contains(DynamicLists.MatrixLayersIdle, MATRIX_STATE.matrixLayerIdle) then
        MATRIX_STATE.matrixLayerIdle = DynamicLists.MatrixLayersIdle[1]
    end
    if not list_contains(DynamicLists.MatrixLayersEngaged, MATRIX_STATE.matrixLayerEngaged) then
        MATRIX_STATE.matrixLayerEngaged = DynamicLists.MatrixLayersEngaged[1]
    end
end

-- Build PetMatrix combos/layers from the active matrix
local function build_pet_matrix_lists()
    DynamicLists.PetMatrixCombos = { 'None' }
    DynamicLists.PetMatrixLayersIdle = { 'None' }
    DynamicLists.PetMatrixLayersEngaged = { 'None' }
    DynamicLists.PetMatrixLayersByComboIdle = {}
    DynamicLists.PetMatrixLayersByComboEngaged = {}

    local currentMatrix = safe_get(_G, 'matrices', MATRIX_STATE.matrixName)
    local petMatrix = currentMatrix and currentMatrix.petMatrix or nil
    if not petMatrix then return end

    -- Collect one combo's layer names from a status node into a sorted,
    -- None-positioned list.
    local function layers_of(statusNode, combo)
        local keys = {}
        local layerTable = type(statusNode) == 'table' and statusNode[combo] or nil
        if type(layerTable) == 'table' then
            for layerKey, maybeSet in pairs(layerTable) do
                if type(maybeSet) == 'table' then keys[#keys + 1] = layerKey end
            end
        end
        table.sort(keys)
        return list_with_none(keys, 'pet_matrix_layer')
    end

    -- Union of combo names across both states (a combo may appear in one
    -- state only; its missing-state layer list is just {None}).
    local combosSet = {}
    for _, statusNode in pairs({ petMatrix.idle, petMatrix.engaged }) do
        if type(statusNode) == 'table' then
            for combo in pairs(statusNode) do combosSet[combo] = true end
        end
    end

    -- Idle and engaged layer lists are built independently per combo, so
    -- divergent layer names between the two states are fully supported.
    for combo in pairs(combosSet) do
        DynamicLists.PetMatrixLayersByComboIdle[combo]    = layers_of(petMatrix.idle, combo)
        DynamicLists.PetMatrixLayersByComboEngaged[combo] = layers_of(petMatrix.engaged, combo)
    end

    -- Combo list is always None-first: the active combo is driven by the
    -- summoned pet (pet_change), so there's no "first layer" to default to.
    DynamicLists.PetMatrixCombos = list_with_none(ordered_keys(combosSet), nil)

    if not list_contains(DynamicLists.PetMatrixCombos, MATRIX_STATE.petMatrixCombo) then
        MATRIX_STATE.petMatrixCombo = 'None'
    end

    -- Point the active per-state lists at the current combo and validate
    -- each state's selection independently.
    local combo = MATRIX_STATE.petMatrixCombo
    DynamicLists.PetMatrixLayersIdle =
        DynamicLists.PetMatrixLayersByComboIdle[combo] or list_with_none({}, 'pet_matrix_layer')
    DynamicLists.PetMatrixLayersEngaged =
        DynamicLists.PetMatrixLayersByComboEngaged[combo] or list_with_none({}, 'pet_matrix_layer')

    if not list_contains(DynamicLists.PetMatrixLayersIdle, MATRIX_STATE.petMatrixLayerIdle) then
        MATRIX_STATE.petMatrixLayerIdle = DynamicLists.PetMatrixLayersIdle[1]
    end
    if not list_contains(DynamicLists.PetMatrixLayersEngaged, MATRIX_STATE.petMatrixLayerEngaged) then
        MATRIX_STATE.petMatrixLayerEngaged = DynamicLists.PetMatrixLayersEngaged[1]
    end
end

local function update_pet_matrix_layers_for_combo(combo)
    DynamicLists.PetMatrixLayersIdle =
        DynamicLists.PetMatrixLayersByComboIdle[combo] or list_with_none({}, 'pet_matrix_layer')
    DynamicLists.PetMatrixLayersEngaged =
        DynamicLists.PetMatrixLayersByComboEngaged[combo] or list_with_none({}, 'pet_matrix_layer')

    if not list_contains(DynamicLists.PetMatrixLayersIdle, MATRIX_STATE.petMatrixLayerIdle) then
        MATRIX_STATE.petMatrixLayerIdle = DynamicLists.PetMatrixLayersIdle[1]
    end
    if not list_contains(DynamicLists.PetMatrixLayersEngaged, MATRIX_STATE.petMatrixLayerEngaged) then
        MATRIX_STATE.petMatrixLayerEngaged = DynamicLists.PetMatrixLayersEngaged[1]
    end
end

-- Sets ps_pet_type + petMatrixCombo and rebuilds the layer list
-- together
local function set_pet_combo(combo)
    combo = combo or 'None'
    local changed = MATRIX_STATE.petMatrixCombo ~= combo
    PLAYER_STATE.ps_pet_type = (combo ~= 'None') and combo or ''
    MATRIX_STATE.petMatrixCombo = combo
    if changed then
        -- Force re-default: a new pet type gets that combo's default layer
        -- in both states
        MATRIX_STATE.petMatrixLayerIdle = nil
        MATRIX_STATE.petMatrixLayerEngaged = nil
    end
    update_pet_matrix_layers_for_combo(combo)
    return changed
end

-- Reads the live pet (if any) and syncs the combo.
local function sync_pet_from_world()
    if pet and pet.isvalid then
        PLAYER_STATE.ps_pet_status = pet.status or 'Idle'
        set_pet_combo(pet_type_combo(pet.head, pet.frame))
    else
        PLAYER_STATE.ps_pet_status = 'None'
        set_pet_combo('None')
    end
end

-- Builds a { 'None', ...sorted keys } cycle list from a sets.layers.<name>
-- table and validates the current selection.
local function build_user_layer_list(setsKey, listKey, stateField)
    local list = { 'None' }
    if sets and sets.layers then
        for _, layerName in ipairs(cyclable_layer_names(sets.layers[setsKey])) do
            list[#list + 1] = layerName
        end
    end

    DynamicLists[listKey] = list

    if not list_contains(list, MATRIX_STATE[stateField]) then
        MATRIX_STATE[stateField] = 'None'
    end
end

local function build_custom_layers()
    build_user_layer_list('CustomLayers', 'CustomLayers', 'customLayer')
    build_user_layer_list('DefenseLayers', 'DefenseLayers', 'defenseLayer')
    build_user_layer_list('SpeedLayers', 'SpeedLayers', 'speedLayer')
end

-----------------------------------------
-- Gear Resolver --
-----------------------------------------
local function resolve_gear()
    local set = {}
    local priorityLayer = nil

    -- The HUD splits the joined set-name on '+'; segments must not contain it
    local nameSegments = {}
    local function add_segment(segment)
        nameSegments[#nameSegments + 1] = segment
    end

    local playerEngaged = PLAYER_STATE.ps_player_status == 'Engaged'
    local petEngaged = PLAYER_STATE.ps_pet_status == 'Engaged'
    local engageStatus = (playerEngaged or petEngaged) and 'engaged' or 'idle'

    local currentMatrix = safe_get(_G, 'matrices', MATRIX_STATE.matrixName)
    if not currentMatrix then
        debug_chat('[GS] - Active matrix "' .. tostring(MATRIX_STATE.matrixName) .. '" not found.')
    end


    -------------------------------------------------
    -- BASE SET (Taken From Active Matrix)
    -------------------------------------------------
    if currentMatrix then
        set = currentMatrix.baseSet
        add_segment(MATRIX_STATE.matrixName .. '.baseSet')
    end

    -------------------------------------------------
    -- PRIMARY MATRIX LAYER
    -------------------------------------------------
    if currentMatrix then
        local layer = MATRIX_STATE[layer_field_for()] or 'None'

        if layer ~= 'None' then
            local group = engagement_group(playerEngaged, petEngaged)
            local newSet = safe_get(currentMatrix, engageStatus, group, layer)
            if newSet then
                if newSet.priority then
                    priorityLayer = newSet
                end

                set = combine_safe(set, newSet)
                add_segment(engageStatus .. '.' .. group .. '.' .. layer)
            end
        end
    end

    -------------------------------------------------
    -- PET MATRIX LAYER
    -------------------------------------------------
    local petMatrix = currentMatrix and currentMatrix.petMatrix or nil
    if petMatrix and MATRIX_STATE.petMatrixCombo and MATRIX_STATE.petMatrixCombo ~= 'None' then
        local petCombo = MATRIX_STATE.petMatrixCombo
        local pmLayer = MATRIX_STATE[pet_layer_field_for()] or 'None'

        -- The pet matrix tree (idle/engaged) follows the PET's status, not
        -- the combined engageStatus - a master-only engage keeps the pet on
        -- its idle petMatrix layer.
        local petStatus = petEngaged and 'engaged' or 'idle'

        local pmSet = safe_get(petMatrix, petStatus, petCombo, pmLayer)
        if pmSet and pmSet ~= 'None' then
            set = combine_safe(set, pmSet)
            add_segment('petMatrix.' .. petStatus .. '.' .. petCombo .. '.' .. pmLayer)
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
    -- ZONE SET
    -- City/region gear (e.g. City Aketons, Counsilor's Garb).
    -------------------------------------------------
    if sets.zones then
        local zoneName = MATRIX_STATE.currentZoneName or ''
        for key, zoneSet in pairs(sets.zones) do
            if type(key) == 'string' and type(zoneSet) == 'table'
                and zoneName ~= '' and zoneName:find(key, 1, true) then
                set = combine_safe(set, zoneSet)
                add_segment('zone.' .. key)
                break
            end
        end
    end

    -------------------------------------------------
    -- USER OVERRIDE LAYERS (custom -> defense -> speed)
    -- Applied last, in ascending priority: defense (emergency DT) overrides
    -- custom, and speed (movement) overrides both.
    -------------------------------------------------
    local function apply_user_layer(setsKey, stateField, segPrefix)
        local sel = MATRIX_STATE[stateField]
        if sets.layers and sel ~= 'Off' and sel ~= 'None' then
            local layerSet = cyclable_layer_set(sets.layers[setsKey], sel)
            if layerSet then
                set = combine_safe(set, layerSet)
                add_segment(segPrefix .. '.' .. sel)
            end
        end
    end

    apply_user_layer('CustomLayers', 'customLayer', 'custom')
    apply_user_layer('DefenseLayers', 'defenseLayer', 'defense')
    apply_user_layer('SpeedLayers', 'speedLayer', 'speed')

    -------------------------------------------------
    -- PET ENMITY SET
    -------------------------------------------------
    if AUTOENMITY_STATE.ae_toggle_on and AUTOENMITY_STATE.ae_window_open
        and (petEngaged or playerEngaged) then
        set = combine_safe(set, safe_get(sets, 'pet', 'enmity'))
        add_segment('pet.enmity')
    end

    -------------------------------------------------
    -- PET WS SWAP SET (Taken from active matrix)
    -------------------------------------------------
    if AUTOPETWS_STATE.apw_toggle_on and AUTOPETWS_STATE.apw_set_active and currentMatrix then
        local petWSSet = safe_get(currentMatrix, 'petMatrix', 'weaponskills', PLAYER_STATE.ps_pet_type)
        if petWSSet then
            set = combine_safe(set, petWSSet)
            add_segment('petWS.' .. PLAYER_STATE.ps_pet_type)
        elseif not PLAYER_STATE.ps_pet_type or PLAYER_STATE.ps_pet_type == '' then
            debug_chat('[PUPTrix AutoPetWS]: Pet Type not set. Activate or Deploy to set.')
        else
            debug_chat('[PUPTrix AutoPetWS]: No matching set found in petmatrix.weaponskills for ' ..
                PLAYER_STATE.ps_pet_type)
        end
    end


    local setName = (#nameSegments > 0) and table.concat(nameSegments, '+') or 'None'
    debug_chat('[PUPTRix Gear] Set: ' .. setName)
    return set, setName
end

-----------------------------------------
-- Equip & Event Handling
-----------------------------------------
local function equip_and_update()
    -- Skip updating equipment if autopetcasting is ON and pet is midcast
    if AUTOPETCASTING_STATE.apc_toggle_on and AUTOPETCASTING_STATE.apc_is_pet_casting then return end

    local set, setName = resolve_gear()
    PUP_HUD.set_set_name(setName)

    equip(set)

    PUP_HUD.update()
end

-- Action-set display for the transient precast/midcast/pet-midcast paths.
local function equip_named(setTable, segName, acc)
    if not setTable then return end
    equip(setTable)
    if acc and segName then acc[#acc + 1] = segName end
end

local function show_action_sets(acc, enabled)
    if not enabled or not acc or #acc == 0 then return end
    PUP_HUD.set_set_name(table.concat(acc, '+'))
    PUP_HUD.update()
end

function status_change(new, old)
    PLAYER_STATE.ps_player_status = new

    -- KO: reset in-flight state; no equip (swaps are blocked while dead)
    if new == 'Dead' or new == 'Engaged dead' then
        reset_auto_states('player KO')
        PUP_HUD.update()
        return
    end

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
        -- pet_change handles the full loss reset; just keep the HUD current
        PUP_HUD.update()
        return
    else
        PLAYER_STATE.ps_pet_status = new
    end

    local petType = pet_type_combo(pet.head, pet.frame)
    if petType then
        set_pet_combo(petType)
        debug_chat("[PUPTrix] - Pet Status Changed: " .. petType .. " - Status: " .. new)
    end

    equip_and_update()
end

function pet_change(p, gain)
    if p then
        if gain then -- New pet activated
            PLAYER_STATE.ps_pet_status = p.status or 'Idle'

            local petType = pet_type_combo(p.head, p.frame)
            if petType then
                debug_chat("[PUPTrix] - Pet Changed: " .. petType)
                set_pet_combo(petType)
            end

            -- Activate / Deus Ex Automata put attachment abilities on full cooldown
            AUTOENMITY_STATE.ae_strobe_last_used = os.clock()
            AUTOENMITY_STATE.ae_flashbulb_last_used = os.clock()
            AUTOENMITY_STATE.ae_strobe_pending = false
            AUTOENMITY_STATE.ae_flashbulb_pending = false
            AUTOENMITY_STATE.ae_window_open = false
            debug_chat("[AutoEnmity] Pet activated - Strobe/Flashbulb cooldowns seeded (30s/45s)")
        else -- Pet is lost: death or Deactivate
            PLAYER_STATE.ps_pet_status = 'None'
            PLAYER_STATE.ps_pet_type = ''
            debug_chat("[PUPTrix] - Pet Lost!")

            -- Toggles persist; enmity cooldowns reseed on the next Activate
            reset_auto_states('pet lost')
        end
    end

    equip_and_update()
end

function precast(spell, action, spellMap, eventArgs)
    if not spell or not spell.english then return end

    local name = spell.english
    local skill = spell.skill or ''
    local actionSets = {} -- semantic names of sets equipped this cast, for the HUD
    local showSets = user_var('hud', 'display_precast_sets', true)

    ------------------------------------------------------------
    -- Item Use (Only items used by /item command will be detected. Item use from menu will not gearswap)
    ------------------------------------------------------------
    if spell.prefix == '/item' then
        local item_name = spell.english
        if sets and sets.precast.items and sets.precast.items[item_name] then
            debug_chat(string.format("[PUPTrix] %s set ", item_name))
            equip_named(sets.precast.items[item_name], 'item.' .. item_name, actionSets)
            show_action_sets(actionSets, showSets)
            return
        end
    end

    ------------------------------------------------------------
    -- Maneuvers
    ------------------------------------------------------------
    local isManeuver = name:find("Maneuver")
    if isManeuver then
        if sets and sets.precast and sets.precast.JA and sets.precast.JA.Maneuver then
            -- Dont let auto-maneuvers remove pet casting set when turned on
            if not AUTOPETCASTING_STATE.apc_is_pet_casting and not AUTOPETCASTING_STATE.apc_toggle_on then
                equip_named(sets.precast.JA.Maneuver, 'JA.' .. name, actionSets)
                show_action_sets(actionSets, showSets)
            end
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
    if sets and sets.precast and sets.precast.JA and sets.precast.JA[name] and not isManeuver then
        equip_named(sets.precast.JA[name], 'JA.' .. name, actionSets)
        show_action_sets(actionSets, showSets)
        return
    end

    ------------------------------------------------------------
    -- Weaponskills
    ------------------------------------------------------------
    if sets and sets.precast and sets.precast.WS and sets.precast.WS[name] then
        equip_named(sets.precast.WS[name], 'WS.' .. name, actionSets)
        show_action_sets(actionSets, showSets)
        return
    end

    ------------------------------------------------------------
    -- Casting
    ------------------------------------------------------------
    if spell.action_type == 'Magic' or spell.type == 'WhiteMagic'
        or spell.type == 'BlackMagic' or spell.type == 'BlueMagic'
        or spell.type == 'Trust' then
        -- Base Fast Cast
        if sets and sets.precast and sets.precast.FastCast then
            equip_named(sets.precast.FastCast, 'FastCast', actionSets)
        end

        -- Skill-specific (e.g. sets.precast['Healing Magic'])
        if sets and sets.precast and sets.precast[skill] then
            equip_named(sets.precast[skill], 'precast.' .. skill, actionSets)
        end

        -- Spell-specific sets (e.g. Cure IV, Utsusemi: Ichi)
        if sets and sets.precast then
            -- Exact spell match
            if sets.precast[name] then
                equip_named(sets.precast[name], 'precast.' .. name, actionSets)
            else
                -- Try “family” matches like Cure, Banish, Utsusemi, etc.
                for setName, _ in pairs(sets.precast) do
                    if type(setName) == 'string' and starts_with(name, setName) then
                        equip_named(sets.precast[setName], 'precast.' .. setName, actionSets)
                        break
                    end
                end
            end
        end

        show_action_sets(actionSets, showSets)
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

        local petwsPrimed = false
        if AUTOPETWS_STATE.apw_toggle_on and pettp >= AUTOPETWS_STATE.apw_tp_threshold then
            local wsSet = get_pet_ws_set()
            if wsSet then
                -- Equip immediately so gear is on before Deploy executes
                equip_named(wsSet, 'petWS.' .. tostring(PLAYER_STATE.ps_pet_type), actionSets)
                show_action_sets(actionSets, showSets)

                PLAYER_STATE.ps_pet_status = 'Engaged'
                AUTOPETWS_STATE.apw_set_active = true
                AUTOPETWS_STATE.apw_timer = os.time() + AUTOPETWS_STATE.apw_active_window
                petwsPrimed = true

                debug_chat(string.format(
                    "[AutoPetWS] Primed on Deploy (TP=%d >= %d). Equipping WS set before Deploy.",
                    pettp, AUTOPETWS_STATE.apw_tp_threshold
                ))
            else
                debug_chat("[AutoPetWS] Deploy prime: no WS set found for petType=" .. tostring(PLAYER_STATE.ps_pet_type))
            end
        end

        ------------------------------------------------------------
        -- AutoPetCasting - Precast Set
        ------------------------------------------------------------
        -- Pet precast (Fast Cast) workaround:
        -- caster puppet begins casting immediately on deploy, so equipping
        -- sets.precast.Pet here
        if not petwsPrimed
            and AUTOPETCASTING_STATE.apc_toggle_on
            and sets.precast and sets.precast.Pet then
            equip_named(sets.precast.Pet, 'petPrecast', actionSets)
            show_action_sets(actionSets, showSets)
            debug_chat("[AutoPetCasting] Deploy detected - equipping pet precast (Fast Cast) set")
        end
    end
end

function midcast(spell, action, spellMap, eventArgs)
    if not spell or not spell.english then return end

    local name       = spell.english or ''
    local skill      = spell.skill or ''
    local actionSets = {}
    local showSets   = user_var('hud', 'display_midcast_sets', true)

    if spell.action_type == 'Magic' then
        if sets.midcast then
            equip_named(sets.midcast, 'midcast', actionSets)

            if sets.midcast[skill] then equip_named(sets.midcast[skill], 'midcast.' .. skill, actionSets) end

            if sets.midcast[name] then
                equip_named(sets.midcast[name], 'midcast.' .. name, actionSets)
            end

            for setName, setTable in pairs(sets.midcast) do
                if type(setName) == 'string' and type(setTable) == 'table'
                    and starts_with(name, setName) then
                    equip_named(setTable, 'midcast.' .. setName, actionSets)
                end
            end

            show_action_sets(actionSets, showSets)
        end
    end
end

function aftercast(spell)
    if not spell or not spell.english then return end
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

    equip_and_update()
end

function pet_midcast(spell)
    if not spell or not spell.english then return end
    if spell.action_type == 'Magic' then
        if not AUTOPETCASTING_STATE.apc_toggle_on then return end

        AUTOPETCASTING_STATE.apc_is_pet_casting = true
        AUTOPETCASTING_STATE.apc_cast_started = os.clock()

        if sets.midcast.Pet then
            local name       = spell.english or ''
            local skill      = spell.skill or ''
            local actionSets = {}
            local showSets   = user_var('hud', 'display_midcast_sets', true)

            equip_named(sets.midcast.Pet, 'petMidcast', actionSets)

            if sets.midcast.Pet[skill] then equip_named(sets.midcast.Pet[skill], 'petMidcast.' .. skill, actionSets) end

            if sets.midcast.Pet[name] then
                equip_named(sets.midcast.Pet[name], 'petMidcast.' .. name, actionSets)
            end

            for setName, setTable in pairs(sets.midcast.Pet) do
                if type(setName) == 'string' and type(setTable) == 'table'
                    and starts_with(name, setName) then
                    equip_named(setTable, 'petMidcast.' .. setName, actionSets)
                end
            end

            show_action_sets(actionSets, showSets)
        end
    end
end

function pet_aftercast(spell)
    if not spell or not spell.english then return end

    AUTOPETCASTING_STATE.apc_is_pet_casting = false

    if not AUTOPETCASTING_STATE.apc_toggle_on then return end

    equip_and_update()
end

function buff_change(name, gained, details)
    local el = is_maneuver_buff(name)
    if not el then return end

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

    -- Lost a maneuver stack. Death strips buffs before status_change can
    -- reset the queue; never queue refreshes for those.
    if not player or player.hpp == 0 then return end

    -- A loss right around a manual JA is intentional; don't queue
    if os.time() - 1.5 < (AUTOMANEUVER_STATE.am_suppress_until or 0) then
        debug_chat(string.format("[AutoManeuver] Ignoring loss of %s (within manual suppress window)", el))
        return
    end

    -- Only queue if AutoManeuver is enabled otherwise treat as a natural expiration / failed buff
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
    -- Overrides must apply before anything acts on the settings below
    load_user_overrides()

    -- Live state references for the HUD renderer
    PUP_HUD.init({
        matrix     = MATRIX_STATE,
        playerInfo = PLAYER_STATE,
        lists      = DynamicLists,
        deploy     = AUTODEPLOY_STATE,
        maneuver   = AUTOMANEUVER_STATE,
        petws      = AUTOPETWS_STATE,
        enmity     = AUTOENMITY_STATE,
        petcast    = AUTOPETCASTING_STATE,
        repair     = AUTOREPAIR_STATE,
        weapons    = WEAPONCYCLE_STATE,
    })

    -- Build dynamic lists
    build_matrices()
    build_layers()
    build_pet_matrix_lists()
    build_custom_layers()

    -- Detect a puppet that already exists at load
    sync_pet_from_world()

    -- Seed the current zone name at load
    if windower.ffxi.get_info then
        local info = windower.ffxi.get_info()
        if info and info.zone then
            MATRIX_STATE.currentZoneId = info.zone
            MATRIX_STATE.currentZoneName = (res.zones[info.zone] and res.zones[info.zone].name) or ''
        end
    end

    -- Weaponlock
    if WEAPONCYCLE_STATE.wc_weapon_lock then
        disable('main', 'sub')
    end

    PUP_HUD.update()
    equip_and_update()
end

-----------------------------------------
-- Pre-render Hook
-----------------------------------------
if not prerender_registered and windower and windower.register_event then
    prerender_registered = true
    windower.register_event('prerender', function()
        local now = os.time()

        -- HUD drag-position autosave (throttled inside PUP_HUD.tick)
        PUP_HUD.tick()

        -- Auto-Maneuver scheduler tick
        if AUTOMANEUVER_STATE.am_toggle_on then
            auto_maneuver_tick()
        end

        if AUTOREPAIR_STATE.ar_active_threshold ~= 0 then
            update_pet_hp()
            check_auto_repair()
        end

        -- Pet Casting Set Failsafe
        if AUTOPETCASTING_STATE.apc_is_pet_casting
            and os.clock() - AUTOPETCASTING_STATE.apc_cast_started > AUTOPETCASTING_STATE.apc_cast_failsafe then
            AUTOPETCASTING_STATE.apc_is_pet_casting = false
            AUTOPETCASTING_STATE.apc_cast_started = nil
            equip_and_update()
        end


        -- Auto Pet Enmity Set Logic (see AUTOENMITY_STATE for the window model)
        if auto_enmity_tick() then
            equip_and_update()
        end

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
-- Pet Action Detection Hook (AutoEnmity primary detection)
-----------------------------------------
-- Detection is always on (independent of the AutoEnmity toggle) so cooldown state stays accurate.
if not pet_action_event_registered and windower and windower.register_event then
    windower.register_event('action', function(act)
        if not act or not act.actor_id then return end
        if not (pet and pet.isvalid and pet.id) then return end
        if act.actor_id ~= pet.id then return end

        local resolved = nil
        if act.category == 11 and res.monster_abilities and res.monster_abilities[act.param] then
            resolved = res.monster_abilities[act.param].en
        end

        -- Validation logging: skip category 1 (melee rounds) to avoid spam
        if act.category ~= 1 then
            debug_chat(string.format('[AutoEnmity][action] Pet action: cat=%s param=%s name=%s',
                tostring(act.category), tostring(act.param), tostring(resolved)))
        end

        if resolved == 'Provoke' then
            record_enmity_ability_use('Strobe', 'action packet')
        elseif resolved == 'Flashbulb' then
            record_enmity_ability_use('Flashbulb', 'action packet')
        end
    end)
    pet_action_event_registered = true
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
        MATRIX_STATE.currentZoneId = new_id

        local zoneName = res.zones[new_id] and res.zones[new_id].name or '?'
        MATRIX_STATE.currentZoneName = zoneName
        debug_chat(string.format('[PUPTrix Zone] id=%s name="%s"', tostring(new_id), zoneName))

        reset_auto_states('zone change')

        if equip_and_update then
            -- Delay gear swap on zone so that the swap occurs after player has loaded in
            coroutine.schedule(equip_and_update, 4)
        end
    end)
    zone_change_hook_registered = true
end

-----------------------------------------
-- Incoming Text Parsing Hook
-----------------------------------------
if not incoming_text_hook_registered and windower and windower.register_event then
    windower.register_event("incoming text", function(original)
        if not original then return end

        --AutoDeploy
        if AUTODEPLOY_STATE.ad_toggle_on and pet then
            if original:contains("Auto") and original:contains("targeting") then
                debug_chat('[PUPTrix Auto Deploy] - Auto-Target swap detected')
                coroutine.schedule(function()
                    auto_deploy()
                end, 1)
            end
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
    local idx = index_of(list, MATRIX_STATE[field]) or 1
    MATRIX_STATE[field] = list[(idx % #list) + 1]
    debug_chat('[GS] ' .. field .. ' -> ' .. MATRIX_STATE[field])
end

-- Map for aliased commands
local COMMAND_SHORTHAND = {
    -- cycles
    matrix         = 'cycle matrix',
    layer          = 'cycle matrixlayer',
    petmatrix      = 'cycle petmatrix',
    petayer        = 'cycle petmatrixlayer',
    customLayer    = 'cycle customlayer',
    defense        = 'cycle defenselayer',
    speed          = 'cycle speedlayer',
    autorepair     = 'cycle autorepair',
    -- toggles
    automaneuver   = 'toggle automaneuver',
    autodeploy     = 'toggle autodeploy',
    autopetws      = 'toggle autopetws',
    autopetenmity  = 'toggle autopetenmity',
    autopetcasting = 'toggle autopetcasting',
    debug          = 'toggle debug',
    weaponlock     = 'toggle weaponlock',
    -- user
    reset          = 'user reset',
    -- hud
    hud            = 'cycle hudview',
    hudtheme       = 'cycle hudscheme',
}

function self_command(cmd)
    local args = {}
    for w in cmd:gmatch("%S+") do args[#args + 1] = w end
    local c = (args[1] or ''):lower()

    -- Expand a bare-target shorthand into its verb form
    if COMMAND_SHORTHAND[c] then
        local rest = {}
        for i = 2, #args do rest[#rest + 1] = args[i] end
        cmd = COMMAND_SHORTHAND[c] .. (#rest > 0 and (' ' .. table.concat(rest, ' ')) or '')
        args = {}
        for w in cmd:gmatch("%S+") do args[#args + 1] = w end
        c = (args[1] or ''):lower()
    end

    if c == 'cycle' then
        local which = (args[2] or ''):lower()
        if which == 'matrix' then
            cycle('matrixName', DynamicLists.Matrices)
            -- Rebuild all lists tied to the active matrix
            build_layers()
            build_pet_matrix_lists()
            -- Re-apply the live pet's combo in case the new matrix defines it
            sync_pet_from_world()
            windower.add_to_chat(122, string.format('[PUPtrix] Cycling Matrix'))
        elseif which == 'matrixlayer' then
            -- Optional target: 'idle' or 'engaged' cycles that state's layer;
            -- omitted cycles whichever state is active now.
            local target = (args[3] or ''):lower()
            if target ~= 'idle' and target ~= 'engaged' then target = nil end
            cycle(layer_field_for(target), layer_list_for(target))
            windower.add_to_chat(122, string.format('[PUPtrix] Cycling %s Matrix Layer',
                target and (target:sub(1, 1):upper() .. target:sub(2)) or 'Active'))
        elseif which == 'petmatrix' then
            cycle('petMatrixCombo', DynamicLists.PetMatrixCombos)
            update_pet_matrix_layers_for_combo(MATRIX_STATE.petMatrixCombo)
            windower.add_to_chat(122, string.format('[PUPtrix] Cycling PetMatrix'))
        elseif which == 'petmatrixlayer' then
            -- Optional target: 'idle'/'engaged' cycles that state's pet layer;
            -- omitted cycles whichever state is active now.
            local target = (args[3] or ''):lower()
            if target ~= 'idle' and target ~= 'engaged' then target = nil end
            cycle(pet_layer_field_for(target), pet_layer_list_for(target))
            windower.add_to_chat(122, string.format('[PUPtrix] Cycling %s PetMatrix Layer',
                target and (target:sub(1, 1):upper() .. target:sub(2)) or 'Active'))
        elseif which == 'customlayer' then
            cycle('customLayer', DynamicLists.CustomLayers)
            windower.add_to_chat(122, string.format('[PUPtrix] Cycling Custom Layer'))
        elseif which == 'defenselayer' then
            cycle('defenseLayer', DynamicLists.DefenseLayers)
            windower.add_to_chat(122, string.format('[PUPtrix] Cycling Defense Layer'))
        elseif which == 'speedlayer' then
            cycle('speedLayer', DynamicLists.SpeedLayers)
            windower.add_to_chat(122, string.format('[PUPtrix] Cycling Speed Layer'))
        elseif which == 'hudview' then
            local newView = PUP_HUD.cycle_view()
            windower.add_to_chat(122, string.format('[PUPtrix] HUD View set to %s', newView))
        elseif which == 'hudscheme' then
            local newScheme = PUP_HUD.cycle_scheme()
            windower.add_to_chat(122, string.format('[PUPtrix] HUD Scheme set to %s', newScheme))
        elseif which == 'autorepair' then
            local thresholds = AUTOREPAIR_STATE.ar_thresholds
            local idx = index_of(thresholds, AUTOREPAIR_STATE.ar_active_threshold or 0) or 1
            AUTOREPAIR_STATE.ar_active_threshold = thresholds[(idx % #thresholds) + 1]

            local disp = (AUTOREPAIR_STATE.ar_active_threshold == 0) and 'Off'
                or (tostring(AUTOREPAIR_STATE.ar_active_threshold) .. '%')

            windower.add_to_chat(122, '[AutoRepair] Threshold: ' .. disp)
            persist_user_setting('repair.default_threshold', AUTOREPAIR_STATE.ar_active_threshold)
            PUP_HUD.update()
        end
    elseif c == 'toggle' then
        local which = (args[2] or ''):lower()
        if which == 'autodeploy' then
            AUTODEPLOY_STATE.ad_toggle_on = not AUTODEPLOY_STATE.ad_toggle_on
            windower.add_to_chat(122, '[AutoDeploy] ' .. (AUTODEPLOY_STATE.ad_toggle_on and 'On' or 'Off'))
            persist_user_setting('deploy.enabled', AUTODEPLOY_STATE.ad_toggle_on)
        elseif which == 'autopetenmity' then
            AUTOENMITY_STATE.ae_toggle_on = not AUTOENMITY_STATE.ae_toggle_on
            windower.add_to_chat(122,
                '[AutoPetEnmity] ' .. (AUTOENMITY_STATE.ae_toggle_on and 'On' or 'Off'))
            persist_user_setting('enmity.enabled', AUTOENMITY_STATE.ae_toggle_on)

            -- Close any open window when disabling
            -- Enmity set is removed by the trailing equip_and_update
            if not AUTOENMITY_STATE.ae_toggle_on then
                AUTOENMITY_STATE.ae_strobe_pending = false
                AUTOENMITY_STATE.ae_flashbulb_pending = false
                AUTOENMITY_STATE.ae_window_open = false
            end
        elseif which == 'autopetws' then
            AUTOPETWS_STATE.apw_toggle_on = not AUTOPETWS_STATE.apw_toggle_on
            windower.add_to_chat(122, '[AutoPetWS] ' .. (AUTOPETWS_STATE.apw_toggle_on and 'On' or 'Off'))
            persist_user_setting('petws.enabled', AUTOPETWS_STATE.apw_toggle_on)
            -- Clear any pending when disabling
            if not AUTOPETWS_STATE.apw_toggle_on then
                AUTOPETWS_STATE.apw_set_active = false
                AUTOPETWS_STATE.apw_timer = 0
                AUTOPETWS_STATE.apw_lockout = 0
            end
        elseif which == 'debug' then
            MATRIX_STATE.debugMode = not MATRIX_STATE.debugMode
            windower.add_to_chat(122, '[Debug] ' .. (MATRIX_STATE.debugMode and 'On' or 'Off'))
            persist_user_setting('general.debug_mode', MATRIX_STATE.debugMode)
        elseif which == 'weaponlock' then
            WEAPONCYCLE_STATE.wc_weapon_lock = not WEAPONCYCLE_STATE.wc_weapon_lock
            persist_user_setting('general.weapon_lock', WEAPONCYCLE_STATE.wc_weapon_lock)
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
            persist_user_setting('maneuver.enabled', AUTOMANEUVER_STATE.am_toggle_on)
            -- Clear any pending when disabling
            if not AUTOMANEUVER_STATE.am_toggle_on then
                AUTOMANEUVER_STATE.am_queue = {}
                AUTOMANEUVER_STATE.am_pending = nil
                AUTOMANEUVER_STATE.am_retry_counts = {}
            end
        elseif which == 'autopetcasting' then
            AUTOPETCASTING_STATE.apc_toggle_on = not AUTOPETCASTING_STATE.apc_toggle_on
            windower.add_to_chat(122,
                '[AutoPetCasting] Pet Casting Sets ' .. (AUTOPETCASTING_STATE.apc_toggle_on and 'On' or 'Off'))
            persist_user_setting('petcast.enabled', AUTOPETCASTING_STATE.apc_toggle_on)
            if not AUTOPETCASTING_STATE.apc_toggle_on then
                AUTOPETCASTING_STATE.apc_toggle_on = false
                AUTOPETCASTING_STATE.apc_is_pet_casting = false
                AUTOPETCASTING_STATE.apc_cast_started = nil
            end
        end
    elseif c == 'hud' then
        local sub = (args[2] or ''):lower()
        if sub == 'resetpos' then
            local dx, dy = PUP_HUD.reset_position()
            windower.add_to_chat(122, string.format('[PUPtrix] HUD position reset to (%d,%d)', dx, dy))
        elseif sub == 'savepos' then
            PUP_HUD.save_position()
            windower.add_to_chat(122, '[PUPtrix] HUD position saved')
        end
    elseif c == 'user' then
        local sub = (args[2] or ''):lower()
        if sub == 'reset' then
            reset_user_settings()
            windower.add_to_chat(122, '[PUPtrix] User setting overrides cleared - PUP-USER values restored')
        end
    elseif c == 'status' then
        -- Manual status set for testing sets swap without a real target
        -- (e.g. in town). Transient: any real status event overwrites it.
        -- The trailing equip_and_update re-resolves gear immediately.
        local target = (args[2] or ''):lower()
        local value = (args[3] or ''):lower()
        if target == 'player' then
            if value == 'engaged' then
                PLAYER_STATE.ps_player_status = 'Engaged'
                windower.add_to_chat(122, '[PUPtrix] Player status -> Engaged (test)')
            elseif value == 'idle' then
                PLAYER_STATE.ps_player_status = 'Idle'
                windower.add_to_chat(122, '[PUPtrix] Player status -> Idle (test)')
            else
                windower.add_to_chat(167, '[PUPtrix] Usage: status player <engaged|idle>')
            end
        elseif target == 'pet' then
            if value == 'engaged' then
                PLAYER_STATE.ps_pet_status = 'Engaged'
                windower.add_to_chat(122, '[PUPtrix] Pet status -> Engaged (test)')
            elseif value == 'idle' then
                PLAYER_STATE.ps_pet_status = 'Idle'
                windower.add_to_chat(122, '[PUPtrix] Pet status -> Idle (test)')
            else
                windower.add_to_chat(167, '[PUPtrix] Usage: status pet <engaged|idle>')
            end
        else
            windower.add_to_chat(167, '[PUPtrix] Usage: status <player|pet> <engaged|idle>')
        end
    elseif c == '__auto_deploy_fire' then
        windower.send_command('input /pet "Deploy" <t>')
    end

    equip_and_update()
end
