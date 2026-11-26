-- --- hypr/user.lua --------------------------------------------------------
-- Your Hyprland overrides, in Ryoku's `hl` Lua API. Loaded LAST, so anything
-- here wins over Ryoku's defaults and over Ryoku Settings. Updates never touch
-- it. Reach for it only for raw config the GUI does not expose.
--
-- --- who owns what --------------------------------------------------------
--   Ryoku defaults   the base modules           replaced by updates   don't edit
--   Ryoku Settings   settings.lua, rebinds.lua  the GUI writes these  edit in-app
--   you              this file (edit it here); whole-file forks in user_edits  yours
--
-- --- take over a whole module ---------------------------------------------
-- Copy it into the overlay at the same path and edit there, e.g.
--   ~/.config/ryoku/user_edits/hypr/modules/binds.lua
-- You then own that file: `ryoku doctor` warns when an update changes the
-- original, and `ryoku reset hypr/modules/binds.lua` hands it back.
--
-- --- examples -------------------------------------------------------------
-- hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("kitty"))
-- hl.window_rule({ name = "float-mpv", match = { class = "mpv" }, float = true })
-- hl.config({ general = { border_size = 3 } })

-- Maximize window (tetap menampilkan bar/gaps)

-- Variasi 1: Gunakan koma sebagai pemisah tombol

-- maximize dengan Super + D
hl.bind("SUPER + D", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
-- tanpa gap saat maximize
hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })

-- Buka panel calendar + todo (~/.config/qs-calendar) dengan Super + C
-- Dulu: hl.bind("SUPER + C", hl.dsp.exec_cmd("vesktop"))
hl.bind("SUPER + C", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/calendar-panel"))
-- Buka panel Now Playing + equalizer dengan Super + X
hl.bind("SUPER + X", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/calendar-panel media"))

-- Buka ZapFast (WhatsApp) dengan Super + Z; tekan lagi untuk fokus window yang sudah jalan
hl.bind("SUPER + Z", hl.dsp.exec_cmd("zapfast"))

-- Startup layout: open these apps on login, each on its own workspace.
-- Runs only once per login (not on config reload). "silent" keeps you on
-- workspace 1 instead of jumping to each app as it opens.
hl.on("hyprland.start", function()
    hl.exec_cmd("brave",   { workspace = "3 silent" })
    hl.exec_cmd("zapfast", { workspace = "2 silent" })
    hl.exec_cmd("vesktop", { workspace = "1 silent" })
    -- panel calendar + todo (Super + C), jalan di background
    hl.exec_cmd("qs -p " .. os.getenv("HOME") .. "/.config/qs-calendar -d")
end)

-- Command Deck (fastfetch + btop + cava) dengan Super + Shift + F
hl.bind("SUPER + SHIFT + F", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/ryoku-deck"))
hl.window_rule({
    name   = "float-ryoku-deck",
    match  = { class = "ryoku-deck" },
    float  = true,
    size   = { "min(1500, monitor_w * 0.92)", "min(880, monitor_h * 0.88)" },
    center = true,
})
