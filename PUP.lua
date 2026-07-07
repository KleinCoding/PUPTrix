-- PUP.lua
-- Main job file for Puppetmaster GearSwap

include('PUP-GEAR.lua')
include('PUP-USER.lua')
include('PUP-HUD.lua')
include('PUP-LIB.lua')

-- TODO: Automatic matix selection when changing subjobs

function get_sets()
    -- Core values do not alter --
    matrices = {}     -- Holds your defined matrixes
    sets = {}         -- Holds gearswap sets for abilities, spells, etc
    --
    sets.layers = {}  -- Cyclable override layers (Custom/Defense/Speed) defined below
    --
    sets.precast = {} -- Holds precast sets
    sets.midcast = {} -- Holds midcast sets
    --
    USER_SETS = {}    -- Holds user's custom defined gear sets from PUP-GEAR
    -- Core values do not alter --

    GET_PUP_SETS() -- Imports user defined gear sets from PUP-GEAR

    ------------------------------------------------------------
    -------------------Priority Layer Cycles-----------------------
    ------------------------------------------------------------
    -- Selectable in the PUPtrix HUD; overrides the gear matrix. Alt+C to cycle.
    sets.layers.CustomLayers = {
        { 'Malignance',    USER_SETS.malignance },
        { 'MasterDTDEF',   USER_SETS.masterDTDEF },
        { 'PetMACC',       USER_SETS.petMACC },
        { 'OverdriveVE',   USER_SETS.overdriveVEVE },
        { 'OverdriveVEDT', USER_SETS.valorODDT },
        { 'OverdriveSS',   USER_SETS.overdriveSSSS },
    }

    -- Defense Layers: emergency DT / high-priority defense. Alt+F11 to cycle.
    -- Applied after Custom layers (higher priority). Same { 'Name', set } format.
    sets.layers.DefenseLayers = {
        { 'Counter', USER_SETS.tanking },
    }

    -- Speed Layers: high-priority movement. Alt+F12 to cycle. Applied last
    -- (highest priority, overrides Custom and Defense). Same format.
    sets.layers.SpeedLayers = {
        { 'Sandals', { feet = "Hermes' Sandals" } },
    }

    ------------------------------------------------------------
    -------------------Matrices---------------------------------
    ------------------------------------------------------------

    -------------------Matrix 1---------------------------------
    matrices.gear_matrix = {}                     -- Names can be customized ex: 'gear_matrix', 'healing_matrix', "mygear" etc
    matrices.gear_matrix.petMatrix = {}           -- Do not change
    matrices.gear_matrix.baseSet = USER_SETS.base -- Base gear layer that other layers stack on top of

    -- Layer names Acc, TP, Regen etc are an example, layers can be uniquely named
    -- Passing priority = true will cause that matrixLayer to overwrite an active petMatrixLayer - use for DT sets or other priority gear
    matrices.gear_matrix.idle = {                                           -- Master & Pet both idle
        masterPet = { DT = { head = "Herculean Helm" } }                    -- Master & Pet are Idle -- Master & Pet are Idle
    }
    matrices.gear_matrix.engaged = {                                        -- Master OR Pet are engaged                                                           -- If Priority value is TRUE, the layer will take priority over petmatrix layers
        master = { TP = USER_SETS.tp_storetp, TPACC = USER_SETS.tp_acc },   -- Master is Engaged, pet is Idle
        pet = { TP = USER_SETS.tp_storetp, TPACC = USER_SETS.tp_acc },      -- Master is idle, pet is engaged
        masterPet = { TP = USER_SETS.tp_storetp, TPACC = USER_SETS.tp_acc } -- Master & Pet are engaged
    }

    -- If a petMatrix is supplied, additional pet specific layers can be applied on top of the matrix layers
    -- Can define unique layer names, these names are an example
    -- Pet names must match 'HEAD_BODY' syntax ex: 'Valor_Valor', "Spirit_Storm"
    matrices.gear_matrix.petMatrix.idle = { -- Pet is Idle
        Valor_Valor = { Tank = {}, DD = {}, TurtleTank = {} },
        Valor_Sharp = { Tank = {}, DD = {}, RangedDD = {} },
        Valor_Harle = { Tank = {}, DD = {}, Heal = {} },
        Sharp_Sharp = { Ranged = {} },
        Soul_Storm = { SoloSupport = {}, Heal = {} },
        Spirit_Storm = { BLM = {} },
        Storm_Storm = { RDMSupport = {} },
    }

    matrices.gear_matrix.petMatrix.engaged = { -- Pet is Engaged
        Valor_Valor = { Tank = {}, DD = {}, TurtleTank = {} },
        Valor_Sharp = { Tank = {}, DD = {}, RangedDD = {} },
        Valor_Harle = { Tank = {}, DD = {}, Heal = {} },
        Sharp_Sharp = { Ranged = {} },
        Soul_Storm = { SoloSupport = {}, Heal = {} },
        Spirit_Storm = { BLM = {} },
        Storm_Storm = { RDMSupport = {} },
    }

    matrices.gear_matrix.petMatrix.weaponskills = { -- If a WS set is provided and autoPetWS toggle is on, WS set will be determined by active puppet type
        Valor_Valor = {},
        Valor_Sharp = USER_SETS.rangerPetWS,
        Valor_Harle = {},
        Sharp_Sharp = USER_SETS.rangerPetWS,
        Soul_Storm = {},
        Spirit_Storm = {},
        Storm_Storm = {},
    }

    -------------------Matrix 2---------------------------------
    matrices.overdrive_matrix = {}
    matrices.overdrive_matrix.petMatrix = {}
    matrices.overdrive_matrix.baseSet = USER_SETS.base

    matrices.overdrive_matrix.idle = { -- Master & Pet both idle
        masterPet = {}                 -- Master & Pet are Idle
    }

    matrices.overdrive_matrix.engaged = { -- Master OR Pet are engaged
        master = {},                      -- Master is Engaged, pet is Idle
        pet = {},                         -- Master is idle, pet is engaged
        masterPet = {}                    -- Master & Pet are engaged
    }

    matrices.overdrive_matrix.petMatrix.idle = { -- Pet is Idle
        Valor_Valor = { Overdrive = USER_SETS.overdriveVEVE },
        Sharp_Sharp = { Overdrive = USER_SETS.overdriveSSSS },
        Storm_Storm = {}
    }

    matrices.overdrive_matrix.petMatrix.engaged = { -- Pet is Engaged
        Valor_Valor = { Overdrive = USER_SETS.overdriveVEVE },
        Sharp_Sharp = { Overdrive = USER_SETS.overdriveSSSS },
        Storm_Storm = { Overdrive = USER_SETS.petMACC }
    }

    matrices.overdrive_matrix.petMatrix.weaponskills = { -- If a WS set is provided and autoPetWS toggle is on, WS set will be determined by active puppet type
        Valor_Valor = USER_SETS.valoredgeWS,
        Valor_Sharp = USER_SETS.rangerPetWS,
        Sharp_Sharp = USER_SETS.rangerPetWS,
    }

    ------------------------------------------------------------
    -------------------Zone / City Sets-------------------------
    ------------------------------------------------------------
    sets.zones = {
        Bastok = { body = "Republic Aketon" },
        -- Windurst      = { body = "Federation Aketon" },
        -- ["San d'Oria"] = { body = "Kingdom Aketon" },
        Adoulin = { body = "Councilor's Garb" }
    }

    ------------------------------------------------------------
    -------------------Precast Sets-----------------------------
    ------------------------------------------------------------

    ------------------- Job Abilities / JAs --------------------
    sets.precast.JA = {}
    sets.precast.JA["Tactical Switch"] = { feet = Empy_Karagoz.Feet_Tatical }
    sets.precast.JA["Ventriloquy"] = { legs = Relic_Pitre.Legs_PMagic }
    sets.precast.JA["Role Reversal"] = { feet = Relic_Pitre.Feet_PMagic }
    sets.precast.JA["Overdrive"] = { body = Relic_Pitre.Body_PTP }
    sets.precast.JA["Repair"] = {
        ammo = "Automat. Oil +3",
        feet = Artifact_Foire.Feet_Repair_PMagic,
        left_ear = "Guignol earring"
    }
    sets.precast.JA["Maintenance"] = set_combine(sets.precast.JA["Repair"], {})
    sets.precast.JA.Maneuver = {
        main = "Kenkonken",
        neck = "Buffoon's Collar",
        body = Empy_Karagoz.Body_Overload,
        hands = Artifact_Foire.Hands_Mane_Overload,
        left_ear = "Burana Earring"
    }

    sets.precast.JA["Activate"] = {}
    sets.precast.JA["Deus Ex Automata"] = sets.precast.JA["Activate"]
    sets.precast.JA["Provoke"] = USER_SETS.enmity

    sets.precast.Waltz = {}
    sets.precast.Waltz["Healing Waltz"] = {}

    ------------------- Weapon Skills / WS ---------------------
    sets.precast.WS = {}
    sets.precast.WS["Stringing Pummel"] = set_combine(USER_SETS.baseWS, USER_SETS.stringing_pummel)
    sets.precast.WS["Victory Smite"] = set_combine(USER_SETS.baseWS, USER_SETS.victory_smite)
    sets.precast.WS["Shijin Spiral"] = set_combine(USER_SETS.baseWS, {})
    sets.precast.WS["Howling Fist"] = set_combine(USER_SETS.baseWS, USER_SETS.howling_fist)
    sets.precast.WS["Tornado Kick"] = set_combine(USER_SETS.baseWS, USER_SETS.howling_fist)
    sets.precast.WS["Dragon Kick"] = set_combine(USER_SETS.baseWS, USER_SETS.howling_fist)
    sets.precast.WS["Aeolian Edge"] = set_combine(USER_SETS.baseWS, USER_SETS.aeolian_edge)
    sets.precast.WS["Gust Slash"] = set_combine(USER_SETS.baseWS, USER_SETS.aeolian_edge)
    sets.precast.WS["Dragon Blow"] = set_combine(USER_SETS.baseWS, USER_SETS.dragon_blow)

    ------------------- Spells ---------------------------------
    sets.precast.FastCast = USER_SETS.fastCast
    sets.precast["Healing Magic"] = {}
    sets.precast["Enfeebling Magic"] = {}
    sets.precast.Cure = {}
    sets.precast.Stoneskin = {}

    sets.midcast.Utsusemi = { neck = "Magoraga Beads", body = "Passion Jacket" }
    sets.midcast.Regen = USER_SETS.regenPotency
    sets.midcast["Enhancing Magic"] = { waist = "Siegel sash", }
    sets.midcast["Healing Magic"] = USER_SETS.healingPotency
    sets.midcast["Enfeebling Magic"] = USER_SETS.MACC

    ------------------------------------------------------------
    ------------------- Special Pet Layers ---------------------
    ------------------------------------------------------------
    sets.precast.Pet = {}
    sets.precast.Pet.FastCast = {} -- Only applied by Deploy while AutoPetCasting is enabled

    sets.midcast.Pet = {}
    sets.midcast.Pet["Enfeebling Magic"] = USER_SETS.petMACC
    sets.midcast.Pet["Elemental Magic"] = USER_SETS.petMACC
    sets.midcast.Pet["Dark Magic"] = USER_SETS.petMACC

    sets.pet = {}
    sets.pet.enmity = {
        head = "Heyoka Cap",
        body = "Heyoka Harness",
        hands = "Heyoka Mittens",
        feet = "Heyoka Leggings",
        right_ear = "Rimeice Earring",
    }

    ------------------------------------------------------------
    ------------------- Item Layers ----------------------------
    ------------------------------------------------------------
    sets.precast.items = {}
    sets.precast.items["Holy Water"] = {
        neck = "Nicander's Necklace",
        left_ring = "Blenmot's Ring +1",
        right_ring = "Blenmot's Ring +1",
    }


    -- Initialize HUD/state
    lib_init()

    -- Apply keybinds
    user_setup()
end

-- KEYBINDS HERE
function user_setup()
    send_command('alias puptrix gs c')
    send_command('alias pup gs c')

    send_command('bind ^f9 gs c cycle Matrix')          -- Ctrl+F9 - Cycle active matrix
    send_command('bind !f9 gs c cycle matrixLayer')     -- Alt+F9 - Cycle active matrix layer
    send_command('bind ^f10 gs c cycle PetMatrix')      -- Ctrl+F10 - Cycle active Pet Matrix
    send_command('bind !f10 gs c cycle PetMatrixLayer') -- Alt+F10 - Cycle Active Pet Matrix Layer

    send_command('bind !c gs c cycle customlayer')      -- Alt+C - Cycle Custom Later
    send_command('bind !f11 gs c cycle defenselayer')   -- Alt+F11 Cycle Defense Later
    send_command('bind !f12 gs c cycle speedlayer')     -- Alt+F12 Speed Defense Later

    send_command('bind !e gs c toggle automaneuver')    -- Alt+E - Toggle autoManeuver
    send_command('bind !d gs c toggle AutoDeploy')      -- Alt+D - Toggle AutoDeploy
    send_command('bind !` gs c toggle WeaponLock')      -- Alt+` - Toggle Weapon Lock
end

function file_unload(file_name)
    send_command('unbind ^f9')
    send_command('unbind !f9')
    send_command('unbind ^f10')
    send_command('unbind !f10')
    send_command('unbind !d')
    send_command('unbind !e')
    send_command('unbind !c')
    send_command('unbind !`')
end
