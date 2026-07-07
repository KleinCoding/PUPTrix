-- PUP-GEAR.lua
function GET_PUP_SETS()
    -- JSE gear, change to your gear level
    Artifact_Foire = {}
    Artifact_Foire.Head_PRegen = "Foire Taj +3"
    Artifact_Foire.Body_WSD_PTank = "Foire Tobe +3"
    Artifact_Foire.Hands_Mane_Overload = "Foire Dastanas +3"
    Artifact_Foire.Legs_PCure = "Foire Churidars +3"
    Artifact_Foire.Feet_Repair_PMagic = "Foire Babouches +3"

    Relic_Pitre = {}
    Relic_Pitre.Head_PRegen = "Pitre Taj +2"       --Optimization
    Relic_Pitre.Body_PTP = "Pitre Tobe +4"         --Overdrive
    Relic_Pitre.Hands_WSD = "Pitre Dastanas +4"    --Fine-Tuning
    Relic_Pitre.Legs_PMagic = "Pitre Churidars +3" --Ventriloquy
    Relic_Pitre.Feet_PMagic = "Pitre Babouches +1" --Role Reversal

    Empy_Karagoz = {}
    Empy_Karagoz.Head_PTPBonus = "Kara. Cappello +3"
    Empy_Karagoz.Body_Overload = "Kara. Farsetto +2"
    Empy_Karagoz.Hands_StoreTP = "Karagoz Guanti +3"
    Empy_Karagoz.Legs_Combat = "Kara. Pantaloni +3"
    Empy_Karagoz.Feet_Tatical = "Karagoz Scarpe +3"

    JSE_Capes = {}
    JSE_Capes.TP_DEXSTORETP = { name = "Visucius's Mantle", augments = { 'Pet: Acc.+20 Pet: R.Acc.+20 Pet: Atk.+20 Pet: R.Atk.+20', 'Accuracy+20 Attack+20', 'DEX+10', '"Store TP"+10', 'Damage taken-5%', } }
    JSE_Capes.TP_DA = { name = "Visucius's Mantle", augments = { 'Pet: Acc.+20 Pet: R.Acc.+20 Pet: Atk.+20 Pet: R.Atk.+20', 'Accuracy+20 Attack+20', 'Pet: Attack+10 Pet: Rng.Atk.+10', '"Dbl.Atk."+10', 'Damage taken-5%', } }
    JSE_Capes.WS_STRCRIT = { name = "Visucius's Mantle", augments = { 'STR+20', 'Accuracy+20 Attack+20', 'STR+10', 'Crit.hit rate+10', 'Damage taken-5%', } }
    JSE_Capes.WS_STRDA = { name = "Visucius's Mantle", augments = { 'STR+20', 'Accuracy+20 Attack+20', 'STR+10', '"Dbl.Atk."+10', } }
    JSE_Capes.WS_DEXWSD = { name = "Visucius's Mantle", augments = { 'DEX+20', 'Accuracy+20 Attack+20', 'DEX+10', 'Weapon skill damage +10%', } }
    JSE_Capes.OD_VALOREDGE = { name = "Visucius's Mantle", augments = { 'Pet: Acc.+20 Pet: R.Acc.+20 Pet: Atk.+20 Pet: R.Atk.+20', 'Accuracy+20 Attack+20', 'Pet: Attack+10 Pet: Rng.Atk.+10', 'Pet: Haste+10', 'Pet: Damage taken -5%', } }
    JSE_Capes.OD_SHARPSHOT = { name = "Visucius's Mantle", augments = { 'Pet: Acc.+20 Pet: R.Acc.+20 Pet: Atk.+20 Pet: R.Atk.+20', 'Accuracy+20 Attack+20', 'Pet: Attack+10 Pet: Rng.Atk.+10', 'Pet: Haste+10', 'Pet: Damage taken -5%', } }
    JSE_Capes.WS_INTMAB = { name = "Visucius's Mantle", augments = { 'INT+20', 'Mag. Acc+20 /Mag. Dmg.+20', 'INT+10', 'Weapon skill damage +10%', 'Damage taken-5%', } }
    JSE_Capes.SP_FCSIRD = { name = "Visucius's Mantle", augments = { 'VIT+20', 'Eva.+20 /Mag. Eva.+20', 'Evasion+7', '"Fast Cast"+10', 'Spell interruption rate down-10%', } }
    JSE_Capes.TP_VITDEFENMITY = { name = "Visucius's Mantle", augments = { 'VIT+20', 'Eva.+20 /Mag. Eva.+20', 'VIT+10', 'Enmity+10', 'DEF+50', } }
    JSE_Capes.WS_DISPERSAL = { name = "Dispersal Mantle", augments = { 'STR+2', 'DEX+1', 'Pet: TP Bonus+500', } }
    JSE_Capes.WS_EVISCERATION = { name = "Visucius's Mantle", augments = { 'DEX+20', 'Accuracy+20 Attack+20', 'DEX+9', 'Crit.hit rate+10', 'Damage taken-5%', } }

    ------------------------------------------------------------
    ------------------- USER DEFINED SETS ----------------------
    ------------------------------------------------------------
    -- Define your custom sets here. They are imported into PUP.lua for applying them to matrices or gearswap actions
    USER_SETS.base = {
        main = "Kenkonken",
        range = "Neo Animator",
        head = "Malignance Chapeau",
        body = "Duty Cyclas",
        hands = Empy_Karagoz.Hands_StoreTP,
        legs = "Mpaca's Hose",
        feet = "Malignance Boots",
        neck = "Lissome Necklace",
        waist = "Moonbow Belt +1",
        left_ear = "Schere Earring",
        right_ear = "Dedition Earring",
        left_ring = "Gere Ring",
        right_ring = "Niqmaddu Ring",
        back = JSE_Capes.TP_DEXSTORETP,
    }

    USER_SETS.tp_storetp = {
        main = "Kenkonken",
        range = "Neo Animator",
        head = "Malignance Chapeau",
        body = "Duty Cyclas",
        hands = Empy_Karagoz.Hands_StoreTP,
        legs = "Mpaca's Hose",
        feet = "Malignance Boots",
        neck = "Lissome Necklace",
        waist = "Moonbow Belt +1",
        left_ear = "Schere Earring",
        right_ear = "Dedition Earring",
        left_ring = "Gere Ring",
        right_ring = "Niqmaddu Ring",
        back = JSE_Capes.TP_DEXSTORETP,
    }

    USER_SETS.tp_acc = {
        head = Empy_Karagoz.Head_PTPBonus,
        body = "Duty Cyclas",
        hands = Empy_Karagoz.Hands_StoreTP,
        legs = Empy_Karagoz.Legs_Combat,
        feet = "Malignance Boots",
        neck = "Shulmanu Collar",
        waist = "Moonbow Belt +1",
        left_ear = "Crep. Earring",
        right_ear = "Mache Earring +1",
        left_ring = "Gere Ring",
        right_ring = "Niqmaddu Ring",
        back = JSE_Capes.TP_DEXSTORETP,
    }

    USER_SETS.base_ws = {
        head = "Mpaca's cap",
        body = "Duty Cyclas",
        legs = "Mpaca's hose",
        neck = "Fotia gorget",
        hands = "Nyame Gauntlets",
        feet = "Nyame Sollerets",
        left_ear = "Schere Earring",
        right_ear = "Moonshade Earring",
        left_ring = 'Gere ring',
        right_ring = "Niqmaddu ring",
        back = JSE_Capes.WS_STRDA,
    }

    USER_SETS.victory_smite = {
        head = "Mpaca's cap",
        body = "Mpaca's doublet",
        legs = "Mpaca's hose",
        neck = "Fotia gorget",
        hands = { name = "Ryuo Tekko +1", augments = { 'STR+12', 'DEX+12', 'Accuracy+20', } },
        left_ear = "Schere Earring",
        right_ear = "Moonshade Earring",
        left_ring = 'Gere ring',
        right_ring = "Niqmaddu ring",
        feet = "Mpaca's boots",
        back = JSE_Capes.WS_STRCRIT,
    }

    USER_SETS.stringing_pummel = {
        head = "Mpaca's Cap",
        body = "Mpaca's Doublet",
        hands = { name = "Ryuo Tekko +1", augments = { 'STR+12', 'DEX+12', 'Accuracy+20', } },
        legs = "Mpaca's Hose",
        feet = "Mpaca's Boots",
        neck = "Fotia gorget",
        waist = "Fotia Belt",
        left_ear = "Schere Earring",
        right_ear = "Moonshade Earring",
        left_ring = "Gere Ring",
        right_ring = "Niqmaddu Ring",
        back = JSE_Capes.WS_STRCRIT,
    }

    USER_SETS.howling_fist = {
        head = "Mpaca's Cap",
        body = "Duty Cyclas",
        hands = Relic_Pitre.Hands_WSD,
        legs = "Nyame Flanchard",
        feet = "Nyame Sollerets",
        neck = "Fotia Gorget",
        waist = "Moonbow belt +1",
        left_ear = "Schere Earring",
        right_ear = "Moonshade Earring",
        left_ring = "Gere Ring",
        right_ring = "Niqmaddu Ring",
        back = JSE_Capes.WS_STRDA,
    }

    USER_SETS.dragon_blow = {
        head = Empy_Karagoz.Head_PTPBonus,
        body = "Foire Tobe +3",
        hands = Relic_Pitre.Hands_WSD,
        legs = "Mpaca's Hose",
        feet = "Karagoz Scarpe +2",
        neck = "Shifting Neck. +1",
        waist = "Moonbow Belt",
        left_ear = "Schere Earring",
        right_ear = "Moonshade Earring",
        left_ring = "Ramuh Ring +1",
        right_ring = "Niqmaddu Ring",
        back = JSE_Capes.WS_DEXWSD,
    }

    USER_SETS.master_dt = {
        head = "Nyame Helm",
        body = "Nyame Mail",
        hands = "Nyame Gauntlets",
        legs = "Nyame Flanchard",
        feet = "Nyame Sollerets",
        neck = "Shulmanu Collar",
        waist = "Moonbow Belt +1",
        left_ear = "Brutal earring",
        right_ear = "Alabaster Earring",
        left_ring = "Niqmaddu Ring",
        right_ring = "Gere Ring",
        back = JSE_Capes.TP_DA,
    }

    USER_SETS.overdriveVEVE = {
        main = { name = "Ohrmazd", augments = { 'Pet: Accuracy+20 Pet: Rng. Acc.+20', 'Pet: "Dbl.Atk."+4 Pet: Crit.hit rate +4', 'Pet: STR+13 Pet: DEX+13 Pet: VIT+13', } },
        ammo = "Automat. Oil +3",
        head = { name = "Taeon Chapeau", augments = { 'Pet: Accuracy+23 Pet: Rng. Acc.+23', 'Pet: "Dbl. Atk."+5', 'Pet: Damage taken -4%', } },
        --body = { name = "Taeon Tabard", augments = { 'Pet: Accuracy+24 Pet: Rng. Acc.+24', 'Pet: "Dbl. Atk."+5', 'Pet: Damage taken -4%', } },
        body = "Duty Cyclas",
        hands = { name = "Taeon Gloves", augments = { 'Pet: Accuracy+25 Pet: Rng. Acc.+25', 'Pet: "Dbl. Atk."+5', 'Pet: Damage taken -4%', } },
        legs = { name = "Taeon Tights", augments = { 'Pet: Accuracy+25 Pet: Rng. Acc.+25', 'Pet: "Dbl. Atk."+5', 'Pet: Damage taken -4%', } },
        feet = { name = "Taeon Boots", augments = { 'Pet: Accuracy+25 Pet: Rng. Acc.+25', 'Pet: "Dbl. Atk."+5', 'Pet: Damage taken -4%', } },
        neck = "Shulmanu Collar",
        waist = "Klouskap Sash +1",
        left_ear = "Rimeice Earring",
        right_ear = "Domes. Earring",
        right_ring = "C. Palug Ring",
        left_ring = "Thurandaut Ring",
        back = JSE_Capes.OD_VALOREDGE,
    }

    USER_SETS.overdriveSSSS = {
        main = { name = "Xiucoatl", augments = { 'Path: C', } },
        ammo = "Automat. Oil +3",
        head = Empy_Karagoz.Head_PTPBonus,
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
        back = JSE_Capes.OD_SHARPSHOT,
    }

    USER_SETS.aeolian_edge = {
        head = "Nyame Helm",
        body = "Nyame Mail",
        hands = "Nyame Gauntlets",
        legs = "Nyame Flanchard",
        feet = "Nyame Sollerets",
        neck = "Fotia Gorget",
        waist = "Fotia Belt",
        left_ear = "Moonshade Earring",
        right_ear = "Friomisi Earring",
        left_ring = "Stikini Ring +1",
        right_ring = "Stikini Ring +1",
        back = JSE_Capes.WS_INTMAB,
    }

    USER_SETS.evisceration = {
        main = "Kenkonken",
        range = "Neo Animator",
        ammo = "Automat. Oil +3",
        head = "Blistering Sallet +1",
        body = "Mpaca's Doublet",
        hands = { name = "Ryuo Tekko +1", augments = { 'STR+12', 'DEX+12', 'Accuracy+20', } },
        legs = "Mpaca's Hose",
        feet = "Mpaca's Boots",
        neck = "Fotia Gorget",
        waist = "Fotia Belt",
        left_ear = "Mache Earring +1",
        right_ear = "Mache Earring +1",
        left_ring = "Ramuh Ring +1",
        right_ring = "Niqmaddu Ring",
        back = JSE_Capes.WS_EVISCERATION,
    }

    USER_SETS.healing = {
        main = "Chatoyant Staff",
        head = "Rawhide mask",
        body = "Vrikodara Jupon",
        hands = "Weath. Cuffs +1",
        legs = "Gyve Trousers",
        feet = "Regal Pumps +1",
        neck = "Voltsurge Torque",
        waist = "Klouskap Sash +1",
        right_ear = "Alabaster Earring",
        left_ear = "Mendi. Earring",
        left_ring = "Stikini Ring +1",
        right_ring = "Stikini Ring +1",
        back = JSE_Capes.SP_FCSIRD,
    }

    USER_SETS.fastCast = {
        head = { name = "Herculean Helm", augments = { 'Mag. Acc.+19', '"Fast Cast"+4', 'MND+2', } },
        body = "Vrikodara Jupon",
        feet = "Regal Pumps +1",
        hands = { name = "Herculean Gloves", augments = { '"Fast Cast"+7', 'INT+10', 'Accuracy+17 Attack+17', 'Mag. Acc.+12 "Mag.Atk.Bns."+12', } },
        legs = { name = "Herculean Trousers", augments = { '"Fast Cast"+5', 'VIT+7', 'Mag. Acc.+4', '"Mag.Atk.Bns."+4', } },
        neck = "Voltsurge Torque",
        waist = "Resolute Belt",
        right_ear = "Mendi. Earring",
        right_ring = "Prolix Ring",
        back = JSE_Capes.SP_FCSIRD,
    }

    USER_SETS.regenPotency = {
        head = { name = "Taeon Chapeau", augments = { 'Mag. Evasion+20', '"Cure" potency +5%', '"Regen" potency+3', } },
        body = { name = "Taeon Tabard", augments = { 'Mag. Evasion+18', 'Potency of "Cure" effect received+7%', '"Regen" potency+3', } },
        hands = { name = "Taeon Gloves", augments = { 'Mag. Evasion+19', 'Potency of "Cure" effect received+7%', '"Regen" potency+3', } },
        legs = { name = "Taeon Tights", augments = { 'Mag. Evasion+19', 'Potency of "Cure" effect received+7%', '"Regen" potency+3', } },
        feet = { name = "Taeon Boots", augments = { 'Mag. Evasion+16', 'Potency of "Cure" effect received+6%', '"Regen" potency+3', } },
        waist = "Siegel Sash",
    }

    USER_SETS.curePotencyRecieved = {
        body = { name = "Taeon Tabard", augments = { 'Mag. Evasion+18', 'Potency of "Cure" effect received+7%', '"Regen" potency+3', } },
        hands = { name = "Taeon Gloves", augments = { 'Mag. Evasion+19', 'Potency of "Cure" effect received+7%', '"Regen" potency+3', } },
        legs = { name = "Taeon Tights", augments = { 'Mag. Evasion+19', 'Potency of "Cure" effect received+7%', '"Regen" potency+3', } },
        feet = { name = "Taeon Boots", augments = { 'Mag. Evasion+16', 'Potency of "Cure" effect received+6%', '"Regen" potency+3', } },
        waist = "Gishdubar Sash"
    }

    USER_SETS.healingPotency = {
        main = "Chatoyant Staff",
        head = { name = "Taeon Chapeau", augments = { 'Mag. Evasion+20', '"Cure" potency +5%', '"Regen" potency+3', } },
        body = "Vrikodara Jupon",
        neck = "Voltsurge Torque",
        hands = "Weath. Cuffs +1",
        legs = "Gyve Trousers",
        left_ear = "Meili Earring",
        right_ear = "Mendi. Earring",
        left_ring = "Sirona's Ring",
        right_ring = "Lebeche Ring",
    }

    USER_SETS.tanking = {
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
        back = JSE_Capes.TP_VITDEFENMITY,
    }

    USER_SETS.rangerPetWS = {
        main = { name = "Xiucoatl", augments = { 'Path: C', } },
        head = Empy_Karagoz.Head_PTPBonus,
        body = "Pitre Tobe +4",
        hands = "Mpaca's Gloves",
        legs = Empy_Karagoz.Legs_Combat,
        feet = { name = "Naga Kyahan", augments = { 'Pet: HP+100', 'Pet: Accuracy+25', 'Pet: Attack+25', } },
        neck = "Shulmanu Collar",
        left_ear = "Burana Earring",
        right_ear = "Kyrene's Earring",
        left_ring = "Thurandaut Ring",
        right_ring = "Overbearing ring",
        back = JSE_Capes.WS_DISPERSAL,
    }

    USER_SETS.malignance = {
        head = "Malignance Chapeau",
        body = "Duty Cyclas",
        hands = "Malignance Gloves",
        legs = "Malignance Tights",
        feet = "Malignance Boots",
        neck = "Lissome Necklace",
        waist = "Moonbow Belt +1",
        left_ear = "Schere Earring",
        right_ear = "Dedition Earring",
        left_ring = "Murky Ring",
        right_ring = "Niqmaddu Ring",
        back = JSE_Capes.TP_DEXSTORETP,
    }

    USER_SETS.masterDTDEF = {
        head = "Malignance Chapeau",
        body = "Malignance Tabard",
        hands = "Nyame Gauntlets",
        legs = "Nyame Flanchard",
        feet = "Nyame Sollerets",
        neck = "Loricate Torque +1",
        waist = "Moonbow Belt +1",
        left_ear = "Alabaster Earring",
        right_ear = "Brutal earring",
        left_ring = "Gere Ring",
        right_ring = "Niqmaddu Ring",
        back = JSE_Capes.TP_VITDEFENMITY,
    }

    USER_SETS.valorODDT = {
        range = "Neo Animator",
        ammo = "Automat. Oil +3",
        head = "Nyame Helm",
        body = "Nyame Mail",
        hands = "Nyame Gauntlets",
        legs = "Nyame Flanchard",
        feet = "Nyame Sollerets",
        neck = "Shulmanu Collar",
        waist = "Klouskap Sash +1",
        left_ear = "Alabaster Earring",
        right_ear = "Rimeice Earring",
        left_ring = "C. Palug Ring",
        right_ring = "Thurandaut Ring",
        back = JSE_Capes.TP_DA,
    }

    USER_SETS.enmity = {
        neck = "Atzintli Necklace",
        right_ear = "Friomisi Earring",
        left_ring = "Provocare Ring",
        right_ring = "Vexer Ring",
        back = JSE_Capes.TP_VITDEFENMITY,
    }

    USER_SETS.valoredgeWS = {
        range = "Animator P + 1",
        body = "Duty Cyclas",
        left_ear = "Kyrene's Earring",
    }

    USER_SETS.petMACC = {
        main = "Sakpata's Fists",
        range = "Animator P +1",
        head = "Kara. Cappello +3",
        body = "Nyame Mail",
        hands = "Karagoz Guanti +3",
        legs = "Kara. Pantaloni +3",
        feet = "Karagoz Scarpe +3",
        neck = { name = "Pup. Collar +2", augments = { 'Path: A', } },
        left_ear = "Kyrene's Earring",
        right_ear = "Alabaster Earring",
        left_ring = "C. Palug Ring",
        right_ring = "Murky Ring",
    }

    USER_SETS.MACC = {
        main = "Tauret",
        range = "Neo Animator",
        ammo = "Automat. Oil +3",
        head = "Nyame Helm",
        body = "Nyame Mail",
        hands = "Nyame Gauntlets",
        legs = "Nyame Flanchard",
        feet = "Nyame Sollerets",
        neck = "Voltsurge Torque",
        waist = "Null Belt",
        left_ear = "Crep. Earring",
        right_ear = { name = "Karagoz Earring", augments = { 'System: 1 ID: 1676 Val: 0', 'Accuracy+7', 'Mag. Acc.+7', } },
        left_ring = "Stikini Ring +1",
        right_ring = "Stikini Ring +1",
        back = { name = "Visucius's Mantle", augments = { 'VIT+20', 'Eva.+20 /Mag. Eva.+20', 'Evasion+7', '"Fast Cast"+10', 'Spell interruption rate down-10%', } },
    }

    USER_SETS.phalanxRec = {
        body = { name = "Herculean Vest", augments = { '"Cure" potency +6%', 'DEX+3', 'Phalanx +2', 'Accuracy+4 Attack+4', } },
        feet = { name = "Herculean Boots", augments = { '"Conserve MP"+3', 'Enmity-1', 'Phalanx +5', 'Accuracy+13 Attack+13', } },
    }
end
