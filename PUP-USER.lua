-- PUP-USER.lua
-- User configuration for PUPTrix. Edit the values below to tune default behavior;
-- everything in this file is optional. Any value you delete (or the whole
-- file, if missing) falls back to the built-in default shown here.
--
-- RUNTIME PERSISTENCE: values changed through in-game commands (feature
-- toggles, the AutoRepair threshold, etc) are saved to a per-character
-- overrides file (GearSwap/data/puptrix-user-<CharName>.txt) and re-applied
-- on load ON TOP of this file. So if you toggle AutoDeploy on in-game, it
-- stays on across reloads even though deploy.enabled below says false.
--
-- To make this file source of truth for PUPTrix settings again, clear the overrides with ingame command:
--   gs c user reset
--
-- Settings persisted by commands: 
-- general.debug_mode, general.weapon_lock,
-- maneuver.enabled, deploy.enabled, petws.enabled, enmity.enabled,
-- petcast.enabled, repair.default_threshold.

PUP_USER = {
    -----------------------------------------
    -- General
    -----------------------------------------
    general = {
        debug_mode  = false, -- start with debug chat on (toggle in-game: gs c toggle debug)
        weapon_lock = true,  -- lock main/sub slots on load (toggle: gs c toggle weaponlock)
    },

    -----------------------------------------
    -- Matrix / Layer selection
    -----------------------------------------
    -- default_first_layer: when true for a category, the 'None' option is
    -- moved to the END of that category's cycle list, so the first real
    -- layer is selected by default and equipped immediately on load. None
    -- is still cyclable (at the end). When false, 'None' stays at the front
    -- and is the default 
    matrix = {
        default_first_layer = {
            matrix_layer     = false, -- primary matrix layers (Alt+F9)
            pet_matrix_layer = false, -- pet matrix layers (Alt+F10)
        },
    },

    -----------------------------------------
    -- AutoManeuver: reapplies expired maneuvers
    -----------------------------------------
    maneuver = {
        enabled         = false, -- feature on at load (toggle: gs c toggle automaneuver)
        cooldown        = 11,    -- seconds between maneuver attempts
        retry_delay     = 3,     -- seconds to wait before retrying a failed attempt
        pending_window  = 3,     -- seconds allowed for the buff to appear after issuing
        suppress_window = 3,     -- seconds to ignore buff-loss events after a manual JA
        max_retries     = 3,     -- give up on an element after this many failed attempts
    },

    -----------------------------------------
    -- AutoDeploy: deploys the puppet on new engage targets
    -----------------------------------------
    deploy = {
        enabled       = false, -- feature on at load (toggle: gs c toggle autodeploy)
        cooldown      = 5,     -- seconds between deploys from target changes
        debounce_time = 0.5,   -- seconds to ignore rapid repeat triggers
        deploy_delay  = 3.5,   -- seconds to wait after engage before deploying
    },

    -----------------------------------------
    -- AutoPetWS: swaps to pet WS gear when the automaton reaches TP
    -----------------------------------------
    petws = {
        enabled       = false, -- feature on at load (toggle: gs c toggle autopetws)
        tp_threshold  = 990,   -- pet TP that triggers the WS gear window
        active_window = 4,     -- seconds to stay in WS gear before reverting
    },

    -----------------------------------------
    -- AutoPetEnmity: swaps to pet enmity gear around Strobe/Flashbulb
    -----------------------------------------
    enmity = {
        enabled         = false, -- feature on at load (toggle: gs c toggle autopetenmity)
        window_failsafe = 10,    -- seconds before assuming a missed ability detection
    },

    -----------------------------------------
    -- AutoPetCasting: pet midcast gear for automaton spellcasting & FastCast on Deploy
    -----------------------------------------
    petcast = {
        enabled       = false, -- feature on at load (toggle: gs c toggle autopetcasting)
        cast_failsafe = 10,    -- seconds before assuming a lost pet aftercast (unsticks gear)
    },

    -----------------------------------------
    -- AutoRepair: uses Repair when pet HP drops below the threshold
    -----------------------------------------
    repair = {
        default_threshold  = 0,                     -- HP% threshold at load; 0 = off (cycle: gs c cycle autorepair)
        thresholds         = { 0, 20, 40, 55, 70 }, -- the cycle steps
        cooldown_upgrades  = 5,                     -- job point Repair recast upgrades (0-5)
        range              = 20,                    -- max yalms to the pet to attempt Repair
        spamguard_lockout  = 3.5,                   -- seconds between repair attempts
        hp_update_interval = 1.0,                   -- seconds between pet HP polls
    },

    -----------------------------------------
    -- HUD (consumed by PUP-HUD.lua)
    -----------------------------------------
    hud = {
        default_view      = 'Full',    -- Full, SetsOnly, or Condensed
        default_scheme    = 'Default', -- Default, Dark, Light, HighContrast, Dracula etc
        pos_save_interval = 5,  -- seconds between drag-position autosave checks
        label_width       = 16, -- fixed label column width
        separator_width   = 26, -- width of the ─ rules in Full view
        padding           = 8,  -- background padding around the text
        font              = 'Consolas',
        font_size         = 10,

        -- Show the transient precast/midcast gear sets in the HUD's Sets
        -- breakdown while casting 
        display_precast_sets = true,
        display_midcast_sets = true,

        -- Custom color schemes, auto-registered at HUD init. Anything you
        -- omit (color roles, bg, stroke) inherits from the Default scheme.
        -- Names must be alphanumeric. Example:
        -- hud_schemes = {
        --     Nord = {
        --         bg     = { red = 46, green = 52, blue = 64, alpha = 235 },
        --         colors = {
        --             header = { 136, 192, 208 },
        --             on     = { 163, 190, 140 },
        --             set    = { 129, 161, 193 },
        --         },
        --     },
        -- },
    },
}