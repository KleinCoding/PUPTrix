-- PUP-HUD.lua

-- TODO: Update to save user HUD settings to the user file instead of its own hud file

-- HUD module for PUPTrix. Owns all rendering, color schemes, and position
-- persistence.
--
-- USAGE (include order matters - this file must load before PUP-LIB):
--   include('PUP-HUD.lua')
--   include('PUP-LIB.lua')
--
-- This file defines exactly one global, PUP_HUD, and does nothing at load
-- time except define it. All setup (text object creation, position file
-- IO, scheme restore) happens in PUP_HUD.init(refs), called from lib_init
-- once `player` is available.
--
-- PUBLIC API:
--   PUP_HUD.init(refs)            - create/style the HUD; refs is a table of
--                                   live state-table references (see below)
--   PUP_HUD.update()              - re-render
--   PUP_HUD.set_set_name(name)    - set the resolved gear-set string
--   PUP_HUD.tick()                - throttled drag-position autosave;
--                                   call from prerender
--   PUP_HUD.cycle_view()          - next HUD view; returns new view name
--   PUP_HUD.cycle_scheme()        - next color scheme; returns new name
--   PUP_HUD.save_position()       - force-persist position+scheme
--   PUP_HUD.reset_position()      - recompute default pos; returns x, y
--   PUP_HUD.register_scheme(n, d) - add/replace a color scheme (see below)
--
-- refs table passed to init (all live references; tables are by-reference
-- in Lua so no sync layer is needed):
--   matrix, playerInfo, lists, deploy, maneuver, petws, enmity, petcast,
--   repair, weapons
--
-- USER SCHEMES: register after the include (job lua or VARS file):
--   PUP_HUD.register_scheme('Nord', {
--       bg = { red = 46, green = 52, blue = 64, alpha = 235 },
--       colors = { header = {136,192,208}, on = {163,190,140} },
--   })
-- Missing color roles, bg, or stroke fields inherit from Default. New
-- schemes append to the cycle order; redefining an existing name replaces
-- it in place. If a saved position file references a user scheme that
-- registers after init, it is applied at registration time.
--
--
-- Text renderer for HUD
local texts = require('texts')

-- File IO for HUD position persistence (windower files lib works inside
-- GearSwap's sandbox since require'd libs run with the addon environment)
local files = require('files')

-- The text object; created in init
local hud = nil

-- files handle for the per-character HUD position file; created in init
-- once player.name is available
local hud_pos_file = nil

-- Live references to PUP-LIB state tables, injected via init. The HUD
-- reads these; it never writes them.
local refs = nil

-----------------------------------------
-- HUD State (private to this module)
-----------------------------------------
local HUD_STATE = {
    hud_view             = 'Full',    -- current HUD layout mode - Full, SetsOnly, Condensed
    hud_scheme           = 'Default', -- current color scheme (see HUD_SCHEMES)
    hud_set_name         = 'None',    -- resolved gear-set string, from PUP_HUD.set_set_name
    hud_requested_scheme = nil,       -- scheme name from the position file that wasn't
    -- registered at init time; applied by register_scheme when it appears

    -- HUD position persistence
    hud_pos_save_interval = 5,   -- seconds between drag-position autosave checks 
    hud_pos_last_check    = 0,   -- os.clock() of last autosave check
    hud_last_saved_x      = nil, -- last persisted position (skip writes when unmoved)
    hud_last_saved_y      = nil,

    hud_settings = {
        -- NOTE: background color/alpha and text stroke are owned by the
        -- active color scheme (HUD_SCHEMES), not by these settings
        hud_label_width     = 16, -- Fixed label width for alignment
        hud_separator_width = 26, -- Width of separator rules in Full view
        -- Conservative fallback position, visible on any resolution. The
        -- real first-load default is computed from screen resolution in
        -- init (default_hud_position), and saved positions override it.
        pos                 = { x = 20, y = 100 },
        padding             = 8,
        bg                  = { alpha = 150, red = 20, green = 20, blue = 20 },
        flags               = { draggable = true },
        text                = {
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

-- HUD layout modes, cycled by PUP_HUD.cycle_view
local HUD_VIEWS = { 'Full', 'SetsOnly', 'Condensed' }

-----------------------------------------
-- Color Schemes
-----------------------------------------
-- Each scheme defines the inline text palette plus the HUD background and
-- text stroke, since readability on bright terrain is driven as much by
-- background opacity as by text color.
-- Windower's texts library supports \cs(r,g,b)...\cr escape sequences for
-- per-segment coloring within a single text object.
-- Color roles: header (title), mode (view/scheme tag), label (row labels),
-- value (row values), on/off (toggles), set (gear set names),
-- dim (separators/arrows), alert (attention values e.g. AutoRepair %).
local HUD_SCHEMES = {
    -- The original palette: translucent dark background
    Default = {
        bg     = { red = 20, green = 20, blue = 20, alpha = 80 },
        stroke = { red = 200, green = 200, blue = 200, alpha = 175 },
        colors = {
            header = { 255, 200, 120 },
            mode   = { 170, 150, 110 },
            label  = { 155, 160, 170 },
            value  = { 235, 235, 235 },
            on     = { 130, 220, 130 },
            off    = { 115, 115, 125 },
            set    = { 150, 205, 255 },
            dim    = { 105, 105, 115 },
            alert  = { 255, 160, 120 },
        },
    },

    -- Near-opaque dark background: the fix for bright zones (sand/snow)
    Dark = {
        bg     = { red = 12, green = 12, blue = 16, alpha = 235 },
        stroke = { red = 0, green = 0, blue = 0, alpha = 200 },
        colors = {
            header = { 255, 205, 130 },
            mode   = { 180, 160, 120 },
            label  = { 175, 180, 190 },
            value  = { 245, 245, 245 },
            on     = { 140, 235, 140 },
            off    = { 130, 130, 140 },
            set    = { 160, 215, 255 },
            dim    = { 130, 130, 140 },
            alert  = { 255, 170, 130 },
        },
    },

    -- Light background, dark text
    Light = {
        bg     = { red = 235, green = 235, blue = 240, alpha = 235 },
        stroke = { red = 255, green = 255, blue = 255, alpha = 60 },
        colors = {
            header = { 150, 90, 10 },
            mode   = { 130, 110, 60 },
            label  = { 80, 85, 95 },
            value  = { 25, 25, 30 },
            on     = { 20, 130, 40 },
            off    = { 145, 145, 155 },
            set    = { 20, 90, 170 },
            dim    = { 150, 150, 160 },
            alert  = { 190, 80, 20 },
        },
    },

    -- Maximum readability: opaque black, saturated primaries
    HighContrast = {
        bg     = { red = 0, green = 0, blue = 0, alpha = 255 },
        stroke = { red = 0, green = 0, blue = 0, alpha = 255 },
        colors = {
            header = { 255, 255, 0 },
            mode   = { 210, 210, 0 },
            label  = { 255, 255, 255 },
            value  = { 255, 255, 255 },
            on     = { 0, 255, 0 },
            off    = { 170, 170, 170 },
            set    = { 0, 255, 255 },
            dim    = { 200, 200, 200 },
            alert  = { 255, 128, 0 },
        },
    },

    -- Dracula (draculatheme.com): bg #282a36, fg #f8f8f2, purple #bd93f9,
    -- comment #6272a4, green #50fa7b, cyan #8be9fd, orange #ffb86c
    Dracula = {
        bg     = { red = 40, green = 42, blue = 54, alpha = 235 },
        stroke = { red = 30, green = 31, blue = 41, alpha = 200 },
        colors = {
            header = { 189, 147, 249 }, -- purple
            mode   = { 98, 114, 164 },  -- comment
            label  = { 98, 114, 164 },  -- comment
            value  = { 248, 248, 242 }, -- foreground
            on     = { 80, 250, 123 },  -- green
            off    = { 98, 114, 164 },  -- comment
            set    = { 139, 233, 253 }, -- cyan
            dim    = { 90, 100, 140 },  -- dimmed comment
            alert  = { 255, 184, 108 }, -- orange
        },
    },

    -- Nord (nordtheme.com): arctic blue-greys. Polar Night bg, Snow Storm
    -- text, Frost accents, Aurora green/orange.
    Nord = {
        bg     = { red = 46, green = 52, blue = 64, alpha = 235 },  -- #2e3440
        stroke = { red = 59, green = 66, blue = 82, alpha = 200 },  -- #3b4252
        colors = {
            header = { 136, 192, 208 }, -- frost cyan #88c0d0
            mode   = { 76, 86, 106 },   -- #4c566a
            label  = { 143, 188, 187 }, -- frost teal #8fbcbb
            value  = { 236, 239, 244 }, -- snow #eceff4
            on     = { 163, 190, 140 }, -- aurora green #a3be8c
            off    = { 76, 86, 106 },   -- #4c566a
            set    = { 129, 161, 193 }, -- frost blue #81a1c1
            dim    = { 67, 76, 94 },
            alert  = { 208, 135, 112 }, -- aurora orange #d08770
        },
    },

    -- Gruvbox (dark): warm retro-terminal earth tones on soft dark brown.
    Gruvbox = {
        bg     = { red = 40, green = 40, blue = 40, alpha = 238 },  -- #282828
        stroke = { red = 60, green = 56, blue = 54, alpha = 205 },  -- #3c3836
        colors = {
            header = { 250, 189, 47 },  -- yellow #fabd2f
            mode   = { 168, 153, 132 }, -- gray #a89984
            label  = { 168, 153, 132 }, -- gray
            value  = { 235, 219, 178 }, -- fg #ebdbb2
            on     = { 184, 187, 38 },  -- green #b8bb26
            off    = { 124, 111, 100 }, -- dim gray #7c6f64
            set    = { 131, 165, 152 }, -- aqua #83a598
            dim    = { 102, 92, 84 },
            alert  = { 254, 128, 25 },  -- orange #fe8019
        },
    },

    -- Synthwave: neon magenta/cyan on deep indigo. High-glow retro vibe.
    Synthwave = {
        bg     = { red = 26, green = 11, blue = 46, alpha = 240 },  -- deep indigo #1a0b2e
        stroke = { red = 118, green = 45, blue = 145, alpha = 210 }, -- neon purple edge
        colors = {
            header = { 255, 84, 201 },  -- hot magenta
            mode   = { 150, 90, 200 },  -- muted purple
            label  = { 180, 120, 220 }, -- lavender
            value  = { 245, 230, 255 }, -- near-white violet
            on     = { 54, 249, 206 },  -- neon aqua
            off    = { 110, 80, 140 },  -- dim purple
            set    = { 0, 224, 255 },   -- electric cyan
            dim    = { 90, 60, 120 },
            alert  = { 255, 209, 102 }, -- warm gold
        },
    },

    -- Solarized Dark (ethanschoonover.com/solarized): base03 bg, precise
    -- accent palette engineered for low eye strain.
    Solarized = {
        bg     = { red = 0, green = 43, blue = 54, alpha = 238 },   -- base03 #002b36
        stroke = { red = 7, green = 54, blue = 66, alpha = 205 },   -- base02 #073642
        colors = {
            header = { 181, 137, 0 },   -- yellow #b58900
            mode   = { 88, 110, 117 },  -- base01 #586e75
            label  = { 131, 148, 150 }, -- base0 #839496
            value  = { 147, 161, 161 }, -- base1 #93a1a1
            on     = { 133, 153, 0 },   -- green #859900
            off    = { 88, 110, 117 },  -- base01
            set    = { 38, 139, 210 },  -- blue #268bd2
            dim    = { 60, 80, 88 },
            alert  = { 203, 75, 22 },   -- orange #cb4b16
        },
    },

    -- Matrix: monochrome green-on-black terminal. Everything is a shade of
    -- phosphor green; alert breaks to amber for emphasis.
    Matrix = {
        bg     = { red = 0, green = 8, blue = 0, alpha = 245 },
        stroke = { red = 0, green = 60, blue = 0, alpha = 210 },
        colors = {
            header = { 120, 255, 120 }, -- bright phosphor
            mode   = { 0, 140, 0 },     -- dim green
            label  = { 0, 170, 60 },    -- mid green
            value  = { 130, 245, 130 }, -- light green
            on     = { 80, 255, 80 },   -- vivid green
            off    = { 0, 100, 0 },     -- dark green
            set    = { 150, 255, 180 }, -- pale green
            dim    = { 0, 80, 0 },
            alert  = { 255, 190, 60 },  -- amber break
        },
    },
}

-- Cycle order for PUP_HUD.cycle_scheme; register_scheme appends new names
local HUD_SCHEME_ORDER = { 'Default', 'Dark', 'Light', 'HighContrast', 'Dracula',
    'Nord', 'Gruvbox', 'Synthwave', 'Solarized', 'Matrix' }

-- Active palette; reassigned by apply_hud_scheme. All render helpers read
-- this at call time, so reassignment takes effect on the next update.
local HUD_COLORS = HUD_SCHEMES.Default.colors

-- Debug chat gated on the lib's debug toggle (read through refs)
local function hud_debug(msg)
    if refs and refs.matrix and refs.matrix.debugMode then
        windower.add_to_chat(122, msg)
    end
end

-- Applies a scheme: swaps the active palette and restyles the text
-- object's background/stroke. Falls back to Default for unknown names
-- (e.g. a hand-edited position file). Does NOT re-render - callers call
-- hud_update after applying.
local function apply_hud_scheme(name)
    local scheme = HUD_SCHEMES[name]
    if not scheme then
        name = 'Default'
        scheme = HUD_SCHEMES.Default
    end
    HUD_STATE.hud_scheme = name
    HUD_COLORS = scheme.colors

    if hud then
        hud:bg_color(scheme.bg.red, scheme.bg.green, scheme.bg.blue)
        hud:bg_alpha(scheme.bg.alpha)
        hud:stroke_color(scheme.stroke.red, scheme.stroke.green, scheme.stroke.blue, scheme.stroke.alpha)
    end
end

-----------------------------------------
-- Render Helpers
-----------------------------------------

local function colored(text, c)
    return string.format('\\cs(%d,%d,%d)%s\\cr', c[1], c[2], c[3], tostring(text))
end

-- Number of display columns in a UTF-8 string (counts codepoints, not
-- bytes) for our label glyphs, which are all single-width BMP characters.
local function display_len(s)
    local _, n = s:gsub("[^\128-\191]", "")
    return n
end

-- Pad the label to hud_label_width DISPLAY columns before colorizing.
-- %-Ns counts bytes, so a multi-byte label glyph (e.g. '└') would overflow
-- the pad and break column alignment; pad by codepoints instead.
local function align_label(label, value, valueColor)
    local text = label .. ":"
    local pad = HUD_STATE.hud_settings.hud_label_width - display_len(text)
    if pad > 0 then text = text .. string.rep(" ", pad) end
    return colored(text, HUD_COLORS.label) .. colored(value or "", valueColor or HUD_COLORS.value)
end

local function on_off(flag)
    return flag and colored('On', HUD_COLORS.on) or colored('Off', HUD_COLORS.off)
end

local function hud_separator()
    return colored(string.rep('─', HUD_STATE.hud_settings.hud_separator_width), HUD_COLORS.dim)
end

-- "Current (n/total)" counter for cyclable lists whose first entry is the
-- 'None' sentinel
-- Renders "Current (n/total)" for a cycle list. 'None' (wherever it sits
-- in the list) is the 0/total position; real layers count 1..total by
-- their order among the non-None entries. Works whether None is first,
-- last, or absent.
local function format_count_of_choices(cur, list)
    if not list or #list == 0 then
        return tostring(cur or "?")
    end

    local realTotal, curIndex = 0, nil
    for _, v in ipairs(list) do
        if v ~= 'None' then
            realTotal = realTotal + 1
            if v == cur then curIndex = realTotal end
        end
    end

    if realTotal == 0 then
        return string.format("%s (0/0)", tostring(cur or "None"))
    end

    -- None or an unknown value renders as the 0/total position
    if cur == 'None' or not curIndex then
        return string.format("None (0/%d)", realTotal)
    end

    return string.format("%s (%d/%d)", cur, curIndex, realTotal)
end

-- Normalized display value for a user override layer ('Off' is the pre-init
-- sentinel; treat it the same as 'None' so the counter renders like the
-- other layer rows).
local function user_layer_display(stateField, listKey)
    local cur = refs.matrix[stateField]
    if not cur or cur == 'Off' then cur = 'None' end
    return format_count_of_choices(cur, refs.lists[listKey])
end

-- Player OR pet engaged -> the 'engaged' layer selection is live.
local function hud_is_engaged()
    return refs.playerInfo.ps_player_status == 'Engaged'
        or refs.playerInfo.ps_pet_status == 'Engaged'
end

-- PET-specific engagement, for the pet matrix layer rows: they follow the
-- pet's status, not the master's (matches resolve_gear).
local function hud_pet_is_engaged()
    return refs.playerInfo.ps_pet_status == 'Engaged'
end

-- Split the resolved set-name string into trimmed segments.
-- resolve_gear joins segments with '+'.
local function set_segments()
    local segs = {}
    if HUD_STATE.hud_set_name and HUD_STATE.hud_set_name ~= 'None' then
        for segment in HUD_STATE.hud_set_name:gmatch("[^+]+") do
            segment = segment:gsub("^%s+", ""):gsub("%s+$", "")
            if segment ~= '' then segs[#segs + 1] = segment end
        end
    end
    return segs
end

-- Wrapped set breakdown: a 'Sets:' header line followed by one
-- '  » segment' line per segment, matching the Full view. Returns a list
-- of lines to insert. Used by all three views for a consistent look.
local function set_breakdown_lines()
    local segs = set_segments()
    local out = {}
    if #segs == 0 then
        out[#out + 1] = colored('Sets: ', HUD_COLORS.label) .. colored('None', HUD_COLORS.dim)
        return out
    end
    out[#out + 1] = colored("Sets:", HUD_COLORS.label)
    for _, s in ipairs(segs) do
        out[#out + 1] = colored("  » ", HUD_COLORS.alert) .. colored(s, HUD_COLORS.set)
    end
    return out
end

-- Compact list of enabled automation features, e.g. "Deploy, Maneuver, Repair 40%"
local function active_automation_summary()
    local active = {}
    if refs.deploy.ad_toggle_on then active[#active + 1] = 'Deploy' end
    if refs.maneuver.am_toggle_on then active[#active + 1] = 'Maneuver' end
    if refs.petws.apw_toggle_on then active[#active + 1] = 'PetWS' end
    if refs.enmity.ae_toggle_on then active[#active + 1] = 'Enmity' end
    if refs.petcast.apc_toggle_on then active[#active + 1] = 'PetCast' end
    local th = tonumber(refs.repair.ar_active_threshold) or 0
    if th > 0 then active[#active + 1] = string.format('Repair %d%%', th) end
    return active
end

-----------------------------------------
-- HUD Position Persistence
-----------------------------------------

-- Computes a first-load default that is visible on any screen: right-hand
-- side, one-fifth down, clamped to on-screen. Falls back to top-left if
-- windower settings are unavailable.
local function default_hud_position()
    local ws = windower.get_windower_settings and windower.get_windower_settings()
    if ws and ws.ui_x_res and ws.ui_y_res then
        return math.max(20, ws.ui_x_res - 320), math.max(20, math.floor(ws.ui_y_res * 0.2))
    end
    return 20, 100
end

-- Reads saved HUD settings from the per-character file.
-- Format: "x,y,scheme". Returns nil when no valid saved data exists.
local function load_hud_position()
    if not hud_pos_file or not hud_pos_file:exists() then return nil end
    local content = hud_pos_file:read()
    if not content then return nil end
    local x, y, scheme = content:match('(-?%d+)%s*,%s*(-?%d+)%s*,%s*(%w+)')
    if x and y and scheme then return tonumber(x), tonumber(y), scheme end
    return nil
end

-- Persists the HUD's current position and color scheme. Called from the
-- tick autosave (when a drag is detected), scheme cycling, and the
-- savepos/resetpos commands.
local function save_hud_position()
    if not hud or not hud_pos_file then return end
    local x, y = hud:pos_x(), hud:pos_y()
    if not x or not y then return end
    hud_pos_file:write(string.format('%d,%d,%s', x, y, HUD_STATE.hud_scheme))
    HUD_STATE.hud_last_saved_x = x
    HUD_STATE.hud_last_saved_y = y
    hud_debug(string.format('[PUP-HUD] Saved position (%d,%d) scheme %s', x, y, HUD_STATE.hud_scheme))
end

-----------------------------------------
-- Renderer
-----------------------------------------

local function hud_update()
    if not hud or not refs then return end
    local lines = {}

    -------------------------------------------------
    -- Sets Only HUD
    -------------------------------------------------
    if HUD_STATE.hud_view == 'SetsOnly' then
        for _, l in ipairs(set_breakdown_lines()) do table.insert(lines, l) end

        -------------------------------------------------
        -- Condensed HUD
        -------------------------------------------------
    elseif HUD_STATE.hud_view == 'Condensed' then
        -- Active-state matrix layer only (idle or engaged)
        local mlCur = hud_is_engaged() and refs.matrix.matrixLayerEngaged or refs.matrix.matrixLayerIdle
        local mlList = hud_is_engaged() and refs.lists.MatrixLayersEngaged or refs.lists.MatrixLayersIdle
        table.insert(lines,
            align_label("MatrixLayer", format_count_of_choices(mlCur, mlList)))
        -- Active-state pet matrix layer only
        local pmlCur = hud_pet_is_engaged() and refs.matrix.petMatrixLayerEngaged or refs.matrix.petMatrixLayerIdle
        local pmlList = hud_pet_is_engaged() and refs.lists.PetMatrixLayersEngaged or refs.lists.PetMatrixLayersIdle
        table.insert(lines,
            align_label("PetMatrixLayer", format_count_of_choices(pmlCur, pmlList)))
        table.insert(lines, align_label("CustomLayer", user_layer_display('customLayer', 'CustomLayers')))
        -- Defense/Speed only shown here when active, to keep Condensed compact
        if refs.matrix.defenseLayer and refs.matrix.defenseLayer ~= 'Off' and refs.matrix.defenseLayer ~= 'None' then
            table.insert(lines, align_label("DefenseLayer",
                user_layer_display('defenseLayer', 'DefenseLayers'), HUD_COLORS.alert))
        end
        if refs.matrix.speedLayer and refs.matrix.speedLayer ~= 'Off' and refs.matrix.speedLayer ~= 'None' then
            table.insert(lines, align_label("SpeedLayer",
                user_layer_display('speedLayer', 'SpeedLayers'), HUD_COLORS.alert))
        end

        -- Enabled automation features, one compact line (only shown if any are on)
        local active = active_automation_summary()
        if #active > 0 then
            table.insert(lines, align_label("Auto", table.concat(active, ', '), HUD_COLORS.on))
        end

        for _, l in ipairs(set_breakdown_lines()) do table.insert(lines, l) end
    else
        -------------------------------------------------
        -- Full HUD (default)
        -------------------------------------------------
        table.insert(lines,
            colored('PUPtrix ', HUD_COLORS.header) ..
            colored('[' .. HUD_STATE.hud_view .. '·' .. HUD_STATE.hud_scheme .. ']', HUD_COLORS.mode))
        table.insert(lines, hud_separator())

        -- Matrix name (no 'None' sentinel in this list; format manually)
        local matrix_idx = 1
        for i, matrixName in ipairs(refs.lists.Matrices) do
            if matrixName == refs.matrix.matrixName then
                matrix_idx = i; break
            end
        end
        table.insert(lines,
            align_label("Matrix",
                string.format("%s (%d/%d)", refs.matrix.matrixName or "?", matrix_idx, #refs.lists.Matrices)))

        -- Matrix Layers: idle and engaged are independent (Model A). Shown
        -- as sub-rows under Matrix ('└' connector); the live state is
        -- highlighted, the other dimmed.
        local engaged = hud_is_engaged()
        local idleColor = engaged and HUD_COLORS.off or HUD_COLORS.value
        local engagedColor = engaged and HUD_COLORS.value or HUD_COLORS.off
        local activeMark = colored(' ‹', HUD_COLORS.alert)
        table.insert(lines,
            align_label("└ Idle",
                format_count_of_choices(refs.matrix.matrixLayerIdle, refs.lists.MatrixLayersIdle), idleColor)
            .. (engaged and "" or activeMark))
        table.insert(lines,
            align_label("└ Engaged",
                format_count_of_choices(refs.matrix.matrixLayerEngaged, refs.lists.MatrixLayersEngaged), engagedColor)
            .. (engaged and activeMark or ""))

        -- Pet Matrix
        local petMatrixDisplay =
            (refs.matrix.petMatrixCombo and refs.matrix.petMatrixCombo ~= '' and refs.matrix.petMatrixCombo) or
            'None'

        table.insert(lines, align_label(
            "PetMatrix",
            format_count_of_choices(petMatrixDisplay, refs.lists.PetMatrixCombos)
        ))

        -- Pet Matrix Layers: idle and engaged tracked independently per combo
        -- (Model A). Both shown under PetMatrix; live state highlighted. The
        -- pet rows follow the PET's engagement, not the master's, so they can
        -- differ from the matrix-layer highlight above. While petless (combo
        -- None) there's nothing meaningful to select.
        if petMatrixDisplay == 'None' then
            --table.insert(lines, align_label("└ Layer", format_count_of_choices('None', { 'None' }), HUD_COLORS.off))
        else
            local petEngaged = hud_pet_is_engaged()
            local petIdleColor = petEngaged and HUD_COLORS.off or HUD_COLORS.value
            local petEngagedColor = petEngaged and HUD_COLORS.value or HUD_COLORS.off
            table.insert(lines,
                align_label("└ Idle",
                    format_count_of_choices(refs.matrix.petMatrixLayerIdle, refs.lists.PetMatrixLayersIdle), petIdleColor)
                .. (petEngaged and "" or activeMark))
            table.insert(lines,
                align_label("└ Engaged",
                    format_count_of_choices(refs.matrix.petMatrixLayerEngaged, refs.lists.PetMatrixLayersEngaged), petEngagedColor)
                .. (petEngaged and activeMark or ""))
        end

        -- User override layers (uses the same 0/# counter as the other rows).
        -- Defense/Speed highlighted when active to flag emergency/movement use.
        table.insert(lines, align_label("CustomLayer", user_layer_display('customLayer', 'CustomLayers')))
        local defActive = refs.matrix.defenseLayer and refs.matrix.defenseLayer ~= 'Off' and refs.matrix.defenseLayer ~= 'None'
        local spdActive = refs.matrix.speedLayer and refs.matrix.speedLayer ~= 'Off' and refs.matrix.speedLayer ~= 'None'
        table.insert(lines, align_label("DefenseLayer",
            user_layer_display('defenseLayer', 'DefenseLayers'), defActive and HUD_COLORS.alert or nil))
        table.insert(lines, align_label("SpeedLayer",
            user_layer_display('speedLayer', 'SpeedLayers'), spdActive and HUD_COLORS.alert or nil))

        table.insert(lines, hud_separator())

        -- Status block
        local playerColor = refs.playerInfo.ps_player_status == 'Engaged' and HUD_COLORS.on or HUD_COLORS.value
        table.insert(lines, align_label("Player", refs.playerInfo.ps_player_status, playerColor))

        local petDisplay = refs.playerInfo.ps_pet_status
        if refs.playerInfo.ps_pet_type and refs.playerInfo.ps_pet_type ~= '' then
            petDisplay = petDisplay .. ' [' .. refs.playerInfo.ps_pet_type .. ']'
        end
        local petColor = refs.playerInfo.ps_pet_status == 'Engaged' and HUD_COLORS.on
            or (refs.playerInfo.ps_pet_status == 'None' and HUD_COLORS.off or HUD_COLORS.value)
        table.insert(lines, align_label("Pet", petDisplay, petColor))

        table.insert(lines, hud_separator())

        -- Automation toggles
        table.insert(lines, align_label("AutoDeploy", nil) .. on_off(refs.deploy.ad_toggle_on))
        table.insert(lines, align_label("AutoManeuver", nil) .. on_off(refs.maneuver.am_toggle_on))
        table.insert(lines, align_label("AutoPetWS", nil) .. on_off(refs.petws.apw_toggle_on))

        -- AutoPetEnmity row shows an alert tag while the enmity window is open
        local enmityRow = align_label("AutoPetEnmity", nil) .. on_off(refs.enmity.ae_toggle_on)
        if refs.enmity.ae_toggle_on and refs.enmity.ae_window_open then
            enmityRow = enmityRow .. colored(' [window]', HUD_COLORS.alert)
        end
        table.insert(lines, enmityRow)

        table.insert(lines, align_label("AutoPetCasting", nil) .. on_off(refs.petcast.apc_toggle_on))

        local threshold = tonumber(refs.repair.ar_active_threshold) or 0
        if threshold == 0 then
            table.insert(lines, align_label("AutoRepair", nil) .. on_off(false))
        else
            table.insert(lines,
                align_label("AutoRepair", string.format("%d%%", threshold), HUD_COLORS.alert))
        end

        table.insert(lines, align_label("WeaponLock", nil) .. on_off(refs.weapons.wc_weapon_lock))
        table.insert(lines, align_label("Debug", nil) .. on_off(refs.matrix.debugMode))

        -- Set breakdown (bottom of full HUD)
        local segs = set_segments()
        if #segs > 0 then
            table.insert(lines, hud_separator())
            for _, l in ipairs(set_breakdown_lines()) do table.insert(lines, l) end
        end
    end

    hud:text(table.concat(lines, '\n'))
    hud:show()
end

-----------------------------------------
-- Public API
-----------------------------------------

PUP_HUD = {}

-- Creates (or restyles) the HUD. Requires `player` to be available (call
-- from lib_init/get_sets, not at file scope). refs is the table of live
-- state references documented at the top of this file.
function PUP_HUD.init(refs_in)
    refs = refs_in or refs

    -- Resolve HUD position before creating the text object: saved
    -- per-character position wins; otherwise compute a resolution-aware
    -- default that is guaranteed on-screen.
    local charName = (player and player.name) or 'default'
    hud_pos_file = files.new('data/puptrix-hud-' .. charName .. '.txt', true)

    local savedX, savedY, savedScheme = load_hud_position()
    if savedX and savedY then
        HUD_STATE.hud_settings.pos.x = savedX
        HUD_STATE.hud_settings.pos.y = savedY
        hud_debug(string.format('[PUP-HUD] Restored saved position (%d,%d)', savedX, savedY))
    else
        HUD_STATE.hud_settings.pos.x, HUD_STATE.hud_settings.pos.y = default_hud_position()
        hud_debug(string.format('[PUP-HUD] No saved position - using default (%d,%d)',
            HUD_STATE.hud_settings.pos.x, HUD_STATE.hud_settings.pos.y))
    end

    if not hud then
        hud = texts.new(HUD_STATE.hud_settings)
        hud:bg_visible(true)
        hud:color(255, 255, 255, 255)
    else
        -- init re-run (e.g. job change reload path): apply the resolved
        -- position to the existing text object
        hud:pos(HUD_STATE.hud_settings.pos.x, HUD_STATE.hud_settings.pos.y)
    end

    -- Restore saved color scheme. An unrecognized name (a user scheme that
    -- registers after init) is remembered and applied by register_scheme.
    if savedScheme and not HUD_SCHEMES[savedScheme] then
        HUD_STATE.hud_requested_scheme = savedScheme
    end
    apply_hud_scheme(savedScheme or HUD_STATE.hud_scheme)

    -- Baseline for the drag autosave: only write when the position moves
    HUD_STATE.hud_last_saved_x = HUD_STATE.hud_settings.pos.x
    HUD_STATE.hud_last_saved_y = HUD_STATE.hud_settings.pos.y
end

-- Re-render. Safe to call before init (no-op).
function PUP_HUD.update()
    hud_update()
end

-- Sets the resolved gear-set string shown in the set chain/breakdown.
-- Does not re-render; equip_and_update calls update() after.
function PUP_HUD.set_set_name(name)
    HUD_STATE.hud_set_name = name or 'None'
end

-- Throttled drag-position autosave. Call every frame from prerender;
-- performs one position check per hud_pos_save_interval seconds and
-- writes only when the position actually changed since the last save.
function PUP_HUD.tick()
    if not hud then return end
    if os.clock() - (HUD_STATE.hud_pos_last_check or 0) <= (HUD_STATE.hud_pos_save_interval or 5) then return end
    HUD_STATE.hud_pos_last_check = os.clock()

    local hx, hy = hud:pos_x(), hud:pos_y()
    if hx and hy and (hx ~= HUD_STATE.hud_last_saved_x or hy ~= HUD_STATE.hud_last_saved_y) then
        save_hud_position()
    end
end

-- Cycles Full -> SetsOnly -> Condensed. Returns the new view name.
function PUP_HUD.cycle_view()
    local idx = 1
    for i, v in ipairs(HUD_VIEWS) do
        if v == HUD_STATE.hud_view then
            idx = i
            break
        end
    end
    HUD_STATE.hud_view = HUD_VIEWS[(idx % #HUD_VIEWS) + 1]
    hud_update()
    return HUD_STATE.hud_view
end

-- Cycles through HUD_SCHEME_ORDER (built-ins plus registered user
-- schemes). Persists the choice. Returns the new scheme name.
function PUP_HUD.cycle_scheme()
    local idx = 1
    for i, v in ipairs(HUD_SCHEME_ORDER) do
        if v == HUD_STATE.hud_scheme then
            idx = i
            break
        end
    end
    apply_hud_scheme(HUD_SCHEME_ORDER[(idx % #HUD_SCHEME_ORDER) + 1])
    hud_update()
    save_hud_position() -- persist the scheme choice alongside position
    return HUD_STATE.hud_scheme
end

-- Force-persist the current position and scheme
function PUP_HUD.save_position()
    save_hud_position()
end

-- Recovery hatch if the HUD ends up off-screen (e.g. saved on a larger
-- monitor). Recomputes the resolution-aware default, applies, persists.
-- Returns the new x, y.
function PUP_HUD.reset_position()
    local dx, dy = default_hud_position()
    HUD_STATE.hud_settings.pos.x = dx
    HUD_STATE.hud_settings.pos.y = dy
    if hud then hud:pos(dx, dy) end
    save_hud_position()
    return dx, dy
end

-- Adds or replaces a color scheme. def may specify any subset of
-- { bg = {red,green,blue,alpha}, stroke = {red,green,blue,alpha},
--   colors = { header/mode/label/value/on/off/set/dim/alert = {r,g,b} } };
-- everything unspecified inherits from Default. New names append to the
-- cycle order; existing names are replaced in place (and restyled
-- immediately if currently active). If a saved position file requested
-- this scheme before it was registered, it is applied now.
function PUP_HUD.register_scheme(name, def)
    if type(name) ~= 'string' or name == '' or type(def) ~= 'table' then
        windower.add_to_chat(167, '[PUP-HUD] register_scheme: expected (name, definition table)')
        return false
    end
    if not name:match('^%w+$') then
        -- The position file format is "x,y,scheme" parsed with %w+
        windower.add_to_chat(167, '[PUP-HUD] register_scheme: name must be alphanumeric (no spaces/punctuation)')
        return false
    end

    local base = HUD_SCHEMES.Default
    local scheme = { bg = {}, stroke = {}, colors = {} }
    for k, v in pairs(base.bg) do
        scheme.bg[k] = (def.bg and def.bg[k]) or v
    end
    for k, v in pairs(base.stroke) do
        scheme.stroke[k] = (def.stroke and def.stroke[k]) or v
    end
    for role, color in pairs(base.colors) do
        scheme.colors[role] = (def.colors and def.colors[role]) or color
    end

    local isNew = HUD_SCHEMES[name] == nil
    HUD_SCHEMES[name] = scheme
    if isNew then
        HUD_SCHEME_ORDER[#HUD_SCHEME_ORDER + 1] = name
    end
    hud_debug(string.format('[PUP-HUD] Scheme %s %s', name, isNew and 'registered' or 'replaced'))

    -- Apply immediately if this is the scheme the position file asked for
    -- (registered after init), or if the active scheme was just redefined
    if HUD_STATE.hud_requested_scheme == name or HUD_STATE.hud_scheme == name then
        HUD_STATE.hud_requested_scheme = nil
        apply_hud_scheme(name)
        hud_update()
    end

    return true
end