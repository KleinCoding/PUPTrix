-- The % tiers you want to use for Auto Repair.
local AUTO_REPAIR_THRESHHOLDS = { 0, 20, 40, 55, 70 }
-- Minimum amount of time AutoRepair will wait between repair attempts
local AUTOREPAIR_SPAM_GUARD   = 3.5
-- Maximum amount of time to keep pet enmity set equipped in seconds
local PET_ENMITY_WINDOW       = 3
local PET_WS_TP_THRESHOLD     = 990 -- configurable trigger TP (e.g. 900/1000) TODO: Move to VARS file
local PET_WS_ACTIVE_WINDOW    = 4 -- seconds to stay in WS gear before check TODO: Move to VARS File
local PET_WS_LOCKOUT          = 3 -- seconds after WS before allowing reactivation TODO: Move to VARS file
local repairCooldownUpgrades  = 5 -- 0–5; each level reduces cooldown by 3 s -- is in current_state currently
local autoPetWsLockout        = 0

local debugMode               = false    --TODO: Derive initial value from VARS
local weaponLock              = true     --TODO: Derive initial value from VARS
local autoEnmity              = false    --TODO: Derive initial value from VARS
