-- PUP.lua
-- Main job file for Puppetmaster GearSwap (uses PUP-LIB.lua)

include('PUP-LIB.lua')


-- TODOS: Pet casting set swaps, Pet Action Tracking, Capacity points mode



function get_sets()
    -- Core values do not alter
    matrices = {}
    sets = {}
    customSets = {}

    -- For Animator Cycle
    Animators = {}
    Animators.Range = "Animator P II"
    Animators.Melee = "Neo Animator"

    -- For Weapon Cycle
    Weapons = {}

    -- Additional values for quick reference of common gear, alter to your gear's level
    Artifact_Foire = {}
    Artifact_Foire.Head_PRegen = "Puppetry Taj"
    Artifact_Foire.Body_WSD_PTank = "Foire Tobe +1"
    Artifact_Foire.Hands_Mane_Overload = "Puppetry Dastanas"
    Artifact_Foire.Legs_PCure = "Puppetry Churidars"
    Artifact_Foire.Feet_Repair_PMagic = "Puppetry Babouches"

    Relic_Pitre = {}
    Relic_Pitre.Head_PRegen = "Pitre Taj +2"       --Enhances Optimization
    Relic_Pitre.Body_PTP = "Pitre Tobe +3"         --Enhances Overdrive
    Relic_Pitre.Hands_WSD = "Pitre Dastanas +3"    --Enhances Fine-Tuning
    Relic_Pitre.Legs_PMagic = "Pitre Churidars +2" --Enhances Ventriloquy
    Relic_Pitre.Feet_PMagic = "Pitre Babouches +1" --Role Reversal

    Empy_Karagoz = {}
    Empy_Karagoz.Head_PTPBonus = "Karagoz Capello +2"
    Empy_Karagoz.Body_Overload = "Kara. Farsetto +2"
    Empy_Karagoz.Hands = "Karagoz Guanti"
    Empy_Karagoz.Legs_Combat = "Karagoz Pantaloni"
    Empy_Karagoz.Feet_Tatical = "Karagoz Scarpe"

    ----------------------------- CUSTOM SETS --------------------------------
    customSets.base = {
        main = "Xiucoatl",
        head = "Mpaca's cap",
        neck = "Shulmanu Collar",
        body = "Mpaca's doublet",
        hands = "Mpaca's Gloves",
        legs = "Mpaca's hose",
        feet = "Mpaca's Boots",
        waist = "Moonbow belt +1",
        back = { name = "Visucius's Mantle", augments = { 'Pet: Acc.+20 Pet: R.Acc.+20 Pet: Atk.+20 Pet: R.Atk.+20', 'Accuracy+20 Attack+20', 'Pet: Attack+10 Pet: Rng.Atk.+10', '"Dbl.Atk."+10', 'Damage taken-5%', } },
        ring1 = "Gere ring",
        ring2 = "Niqmaddu ring",
        ear1 = "Brutal earring",
        ear2 = "Cessance earring"
    }

    sets.base_ws = {
        head = "Blistering sallet +1",
        body = "Mpaca's doublet",
        legs = "Mpaca's hose",
        neck = "Fotia gorget",
        hands = { name = "Ryuo Tekko +1", augments = { 'STR+12', 'DEX+12', 'Accuracy+20', } },
        ring1 = 'Gere ring',
        ring2 = "Niqmaddu ring",
        feet = { name = "Herculean Boots", augments = { 'Attack+19', 'Crit. hit damage +2%', 'STR+13', } },
        back = { name = "Visucius's Mantle", augments = { 'STR+20', 'Accuracy+20 Attack+20', 'STR+10', 'Crit.hit rate+10', } },
    }

    customSets.dragon_blow = {
        head = "Kara. Cappello +2",
        body = "Foire Tobe +3",
        hands = "Pitre Dastanas +3",
        legs = "Mpaca's Hose",
        feet = "Karagoz Scarpe +2",
        neck = "Shifting Neck. +1",
        waist = "Moonbow Belt",
        left_ear = "Moonshade Earring",
        right_ear = "Mache Earring +1",
        left_ring = "Ramuh Ring +1",
        right_ring = "Niqmaddu Ring",
        back = { name = "Visucius's Mantle", augments = { 'DEX+20', 'Accuracy+20 Attack+20', 'DEX+10', 'Weapon skill damage +10%', } },
    }

    customSets.master_dt = {
        main = { name = "Xiucoatl", augments = { 'Path: C', } },
        head = "Nyame Helm",
        body = "Nyame Mail",
        hands = "Nyame Gauntlets",
        legs = "Nyame Flanchard",
        feet = "Nyame Sollerets",
        neck = "Shulmanu Collar",
        waist = "Moonbow Belt +1",
        left_ear = "Brutal Earring",
        right_ear = "Alabaster Earring",
        left_ring = "Niqmaddu Ring",
        right_ring = "Gere Ring",
        back = { name = "Visucius's Mantle", augments = { 'Pet: Acc.+20 Pet: R.Acc.+20 Pet: Atk.+20 Pet: R.Atk.+20', 'Accuracy+20 Attack+20', 'Pet: Attack+10 Pet: Rng.Atk.+10', '"Dbl.Atk."+10', 'Damage taken-5%', } },
    }

    customSets.overdrive = {
        main = { name = "Ohrmazd", augments = { 'Pet: Accuracy+20 Pet: Rng. Acc.+20', 'Pet: Phys. dmg. taken -4%', 'Pet: STR+13 Pet: DEX+13 Pet: VIT+13', } },
        ammo = "Automat. Oil +3",
        head = { name = "Taeon Chapeau", augments = { 'Pet: Accuracy+23 Pet: Rng. Acc.+23', 'Pet: "Dbl. Atk."+5', 'Pet: Damage taken -4%', } },
        body = { name = "Taeon Tabard", augments = { 'Pet: Accuracy+24 Pet: Rng. Acc.+24', 'Pet: "Dbl. Atk."+5', 'Pet: Damage taken -4%', } },
        hands = { name = "Taeon Gloves", augments = { 'Pet: Accuracy+25 Pet: Rng. Acc.+25', 'Pet: "Dbl. Atk."+5', 'Pet: Damage taken -4%', } },
        legs = { name = "Taeon Tights", augments = { 'Pet: Accuracy+25 Pet: Rng. Acc.+25', 'Pet: "Dbl. Atk."+5', 'Pet: Damage taken -4%', } },
        feet = { name = "Taeon Boots", augments = { 'Pet: Accuracy+25 Pet: Rng. Acc.+25', 'Pet: "Dbl. Atk."+5', 'Pet: Damage taken -4%', } },
        neck = "Shulmanu Collar",
        waist = "Klouskap Sash +1",
        left_ear = "Rimeice Earring",
        right_ear = "Domes. Earring",
        right_ring = "C. Palug Ring",
        left_ring = "Thurandaut Ring",
        back = { name = "Visucius's Mantle", augments = { 'Pet: Acc.+20 Pet: R.Acc.+20 Pet: Atk.+20 Pet: R.Atk.+20', 'Accuracy+20 Attack+20', 'Pet: Attack+10 Pet: Rng.Atk.+10', 'Pet: Haste+10', 'Pet: Damage taken -5%', } },
    }

    customSets.overdriveSS = {
        main = { name = "Xiucoatl", augments = { 'Path: C', } },
        ammo = "Automat. Oil +3",
        head = "Kara. Cappello +2",
        body = "Pitre Tobe +4",
        hands = "Mpaca's Gloves",
        legs = "Karagoz Pantaloni +2",
        feet = "Naga Kyahan",
        neck = "Shulmanu Collar",
        waist = "Klouskap Sash +1",
        left_ear = "Burana Earring",
        right_ear = "Alabaster earring",
        left_ring = "Varar ring +1",
        right_ring = "Varar ring +1",
        back = { name = "Visucius's Mantle", augments = { 'Pet: Acc.+20 Pet: R.Acc.+20 Pet: Atk.+20 Pet: R.Atk.+20', 'Accuracy+20 Attack+20', 'Pet: Attack+10 Pet: Rng.Atk.+10', 'Pet: Haste+10', 'Pet: Damage taken -5%', } },
    }

    customSets.aeolian_edge = {
        head = { name = "Herculean Helm", augments = { '"Mag.Atk.Bns."+18', '"Fast Cast"+2', 'INT+11', } },
        body = { name = "Herculean Vest", augments = { '"Mag.Atk.Bns."+21', 'Enmity-3', 'INT+11', 'Mag. Acc.+14', } },
        hands = { name = "Herculean Gloves", augments = { 'Mag. Acc.+18 "Mag.Atk.Bns."+18', 'Enmity-1', 'Mag. Acc.+10', '"Mag.Atk.Bns."+11', } },
        legs = { name = "Herculean Trousers", augments = { 'Mag. Acc.+20 "Mag.Atk.Bns."+20', 'STR+6', '"Mag.Atk.Bns."+13', } },
        feet = { name = "Herculean Boots", augments = { 'Mag. Acc.+19 "Mag.Atk.Bns."+19', 'Crit. hit damage +1%', 'Mag. Acc.+2', '"Mag.Atk.Bns."+7', } },
        neck = "Stoicheion Medal",
        left_ear = "Sortiarius Earring",
        right_ear = { name = "Moonshade Earring", augments = { 'Attack+4', 'TP Bonus +250', } },
        right_ring = "Rajas Ring",
        back = { name = "Visucius's Mantle", augments = { 'INT+20', 'Mag. Acc+20 /Mag. Dmg.+20', 'INT+10', 'Pet: Haste+10', 'Damage taken-5%', } },
    }

    customSets.healing = {
        main = "Iridal Staff",
        ammo = "Automat. Oil +3",
        head = "Rawhide mask",
        body = "Vrikodara Jupon",
        hands = "Weath. Cuffs +1",
        legs = "Gyve Trousers",
        feet = "Nyame Sollerets",
        neck = "Voltsurge Torque",
        waist = "Moonbow Belt",
        left_ear = "Alabaster Earring",
        right_ear = "Zedoma's Earring",
        left_ring = "Sirona's Ring",
        right_ring = "Lebeche Ring",
        back = { name = "Visucius's Mantle", augments = { 'Pet: Acc.+20 Pet: R.Acc.+20 Pet: Atk.+20 Pet: R.Atk.+20', 'Accuracy+20 Attack+20', 'Pet: Attack+10 Pet: Rng.Atk.+10', '"Dbl.Atk."+10', 'Damage taken-5%', } },
    }

    customSets.tanking = {
        main = "Jolt Counter",
        ammo = "Automat. Oil +3",
        head = "Nyame Helm",
        body = "Nyame Mail",
        hands = "Nyame Gauntlets",
        legs = "Nyame Flanchard",
        feet = "Nyame Sollerets",
        neck = "Dualism Collar +1",
        waist = "Moonbow Belt +1",
        left_ear = "Alabaster Earring",
        right_ear = "Puissant Pearl",
        left_ring = "Vexer Ring +1",
        right_ring = "C. Palug Ring",
        back = { name = "Visucius's Mantle", augments = { 'VIT+20', 'Eva.+20 /Mag. Eva.+20', 'VIT+10', 'Enmity+10', 'DEF+50', } },
    }

    customSets.rangerPetWS = {
        main = { name = "Xiucoatl", augments = { 'Path: C', } },
        head = "Kara. Cappello +2",
        body = "Pitre Tobe +4",
        hands = "Mpaca's Gloves",
        feet = { name = "Naga Kyahan", augments = { 'Pet: HP+100', 'Pet: Accuracy+25', 'Pet: Attack+25', } },
        neck = "Shulmanu Collar",
        left_ear = "Burana Earring",
        right_ear = "Domes. Earring",
        left_ring = "Varar ring +1",
        right_ring = "Varar ring +1",
        back = { name = "Dispersal Mantle", augments = { 'STR+2', 'DEX+1', 'Pet: TP Bonus+500', } },
    }

    customSets.kyou = {
        main = { name = "Xiucoatl", augments = { 'Path: C', } },
        head = "Malignance Chapeau",
        body = "Malignance Tabard",
        hands = "Nyame Gauntlets",
        legs = "Malignance Tights",
        feet = "Malignance Boots",
        neck = "Shulmanu Collar",
        waist = "Moonbow Belt +1",
        left_ear = "Cessance Earring",
        right_ear = "Brutal Earring",
        left_ring = "Murky Ring",
        right_ring = "Niqmaddu Ring",
        back = { name = "Visucius's Mantle", augments = { 'Pet: Acc.+20 Pet: R.Acc.+20 Pet: Atk.+20 Pet: R.Atk.+20', 'Accuracy+20 Attack+20', 'Pet: Attack+10 Pet: Rng.Atk.+10', '"Dbl.Atk."+10', 'Damage taken-5%', } },
    }

    customSets.masterDTDEF = {
        head = "Malignance Chapeau",
        body = "Malignance Tabard",
        hands = "Nyame Gauntlets",
        legs = "Malignance Tights",
        feet = "Malignance Boots",
        neck = "Loricate Torque +1",
        waist = "Moonbow Belt +1",
        left_ear = "Cessance Earring",
        right_ear = "Brutal Earring",
        left_ring = "Murky Ring",
        right_ring = "Niqmaddu Ring",
        back = { name = "Visucius's Mantle", augments = { 'VIT+20', 'Eva.+20 /Mag. Eva.+20', 'VIT+10', 'Enmity+10', 'DEF+50', } },
    }

    customSets.enmity = {
        main = { name = "Xiucoatl", augments = { 'Path: C', } },
        neck = "Atzintli Necklace",
        right_ear = "Friomisi Earring",
        left_ring = "Provocare Ring",
        right_ring = "Vexer Ring",
        back = { name = "Visucius's Mantle", augments = { 'VIT+20', 'Eva.+20 /Mag. Eva.+20', 'VIT+10', 'Enmity+10', 'DEF+50', } },
    }

    ----------------------------- CUSTOM SETS END --------------------------------

    sets.base = customSets.base
    sets.layers = {}

    ------------------------------------------------------------
    -------------------Matrices---------------------------------
    ------------------------------------------------------------

    matrices.gear_matrix = {}
    matrices.gear_matrix.petMatrix = {}
    matrices.gear_matrix.baseSet = customSets.base

    -- Layer names Acc, TP, Regen etc are an example, layers can be uniquely named.
    -- It is important that both idle and engaged have the same layer options
    matrices.gear_matrix.idle = {
        masterPet = { Acc = {}, TP = {}, Regen = {}, Ranged = {} } -- Master & Pet are Idle
    }
    matrices.gear_matrix.engaged = {                               -- If Priority value is TRUE, the layer will take priority over petmatrix layers
        master = { Acc = {}, TP = {}, Regen = {}, DT = {} },       -- Master is Engaged, pet is Idle
        pet = { Acc = {}, TP = {}, Regen = {}, DT = {} },          -- Master is idle, pet is engaged
        masterPet = { Acc = {}, TP = {}, Regen = {}, DT = {} }     -- Master & Pet are engaged
    }

    -- If a petMatrix is supplied, additional pet specific layers can be applied on top
    -- Can define unique layer names, these names are an example
    -- It is important that both idle and engaged have the same layer options
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
        Valor_Sharp = {},
        Valor_Harle = {},
        Sharp_Sharp = {},
        Soul_Storm = {},
        Spirit_Storm = {},
        Storm_Storm = {},
    }

    ------------------------------------------------------------
    -------------------Custom Layers----------------------------
    ------------------------------------------------------------
    -- Layers defined here are selectable in the PUPtrix HUD and override the gear matrix
    -- Alt + C to cycle
    sets.layers.CustomLayers = {}

    sets.layers.CustomLayers.aMasterDT = customSets.kyou
    sets.layers.CustomLayers.aMasterDTDEF = customSets.masterDTDEF
    sets.layers.CustomLayers.aMasterDTHP = customSets.tanking
    sets.layers.CustomLayers.dHealing = customSets.healing
    sets.layers.CustomLayers.bOverdriveVE = customSets.overdrive
    sets.layers.CustomLayers.cOverdriveSS = customSets.overdriveSS

    ------------------------------------------------------------
    -------------------Town / Cities Sets-----------------------
    ------------------------------------------------------------
    sets.town = {
        feet = "Hermes' sandals"
    }

    ------------------------------------------------------------
    -------------------Precast Sets-----------------------------
    ------------------------------------------------------------
    sets.precast = {}

    -------------------------------------Midcast
    sets.midcast = {}

    -------------------------------------Kiting - TODO create kiting mode. Or make a layer...?
    sets.Kiting = { feet = "Hermes' Sandals" }

    -------------------------------------JA
    sets.precast.JA = {}

    sets.precast.JA["Tactical Switch"] = { feet = Empy_Karagoz.Feet_Tatical }
    sets.precast.JA["Ventriloquy"] = { legs = Relic_Pitre.Legs_PMagic }
    sets.precast.JA["Role Reversal"] = { feet = Relic_Pitre.Feet_PMagic }
    sets.precast.JA["Overdrive"] = { body = Relic_Pitre.Body_PTP }
    sets.precast.JA["Repair"] = {
        ammo = "Automat. Oil +3",
        feet = Artifact_Foire.Feet_Repair_PMagic,
        ear1 = "Guignol earring"
    }
    sets.precast.JA["Maintenance"] = set_combine(sets.precast.JA["Repair"], {})
    sets.precast.JA.Maneuver = {
        neck = "Buffoon's Collar",
        body = Empy_Karagoz.Body_Overload,
        hands = Artifact_Foire.Hands_Mane_Overload,
        ear1 = "Burana Earring"
    }

    sets.precast.JA["Activate"] = {}
    sets.precast.JA["Deus Ex Automata"] = sets.precast.JA["Activate"]
    sets.precast.JA["Provoke"] = customSets.enmity

    sets.precast.Waltz = {}
    sets.precast.Waltz["Healing Waltz"] = {}

    ------------------------------------------------------------
    ------------------- Weapon Skills / WS --------------------- update to use a base layer like fastcast for spells. see puplib
    ------------------------------------------------------------
    sets.precast.WS = sets.base_ws
    sets.precast.WS["Stringing Pummel"] = set_combine(sets.precast.WS, {})
    sets.precast.WS["Victory Smite"] = set_combine(sets.precast.WS, {})
    sets.precast.WS["Shijin Spiral"] = set_combine(sets.precast.WS, {})
    sets.precast.WS["Howling Fist"] = set_combine(sets.precast.WS, {})
    sets.precast.WS["Aeolian Edge"] = set_combine(sets.precast.WS, customSets.aeolian_edge)
    sets.precast.WS["Gust Slash"] = set_combine(sets.precast.WS, customSets.aeolian_edge)
    sets.precast.WS["Dragon Blow"] = set_combine(sets.precast.WS, customSets.dragon_blow)

    ------------------------------------------------------------
    ------------------- Spells ---------------------------------
    ------------------------------------------------------------
    sets.precast.FastCast = { feet = "Rostrum pumps" }
    sets.precast["Healing Magic"] = customSets.healing
    sets.precast["Enhancing Magic"] = { waist = "Siegel sash", }
    sets.precast.Cure = {}
    sets.precast.Stoneskin = {}
    sets.precast.Utsusemi = { neck = "Magoraga Beads", body = "Passion Jacket" }


    ------------------------------------------------------------
    ------------------- Special Pet Layers ---------------------
    ------------------------------------------------------------
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
    send_command('bind ^f9 gs c cycle Matrix')          -- Ctrl+F9 - Cycle active matrix
    send_command('bind !f9 gs c cycle layer')           -- Alt+F9 - Cycle active matrix layer
    send_command('bind ^f10 gs c cycle PetMatrix')      -- Ctrl+F10 - Cycle active Pet Matrix
    send_command('bind !f10 gs c cycle PetMatrixLayer') -- Alt+F10 - Cycle Active Pet Matrix Layer
    send_command('bind !c gs c cycle customlayer')      -- Alt+C - Cycle Custom Later

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
