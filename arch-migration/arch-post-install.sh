#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  Arch Linux Post-Install: XLibre + Awesome + Full Desktop       ║
# ║  Run as:  sudo ./arch-post-install.sh                          ║
# ║  (Optional: put your wallpaper.jpg next to this script first — ║
# ║   it'll be copied into place automatically if present.)        ║
# ╚══════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ── Sanity ───────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run as root → sudo ./arch-post-install.sh"
    exit 1
fi

REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
REAL_HOME=$(eval echo "~$REAL_USER")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "═══════════════════════════════════════════════════════════"
echo "  Arch Linux Post-Install"
echo "  User: $REAL_USER | Home: $REAL_HOME"
echo "═══════════════════════════════════════════════════════════"

step() {
    echo ""
    echo "── $1 ──────────────────────────────────────────────────"
}

# =====================================================================
# 1. FULL SYSTEM UPDATE
# =====================================================================
step "System update"
pacman -Syu --noconfirm

# =====================================================================
# 2. XLIBRE REPOSITORY
# =====================================================================
step "Adding XLibre binary repo"

# Import the signing key
curl -fsSL -o /tmp/xlibre-archlinux.asc https://xlibre-arch.github.io/xlibre-archlinux.asc
pacman-key --add /tmp/xlibre-archlinux.asc
pacman-key --finger B97F7C613F359424
pacman-key --lsign-key B97F7C613F359424
rm -f /tmp/xlibre-archlinux.asc

# Add the repo to pacman.conf (if not already there)
if ! grep -q "\[xlibre-stable\]" /etc/pacman.conf; then
    cat >> /etc/pacman.conf << 'REPO'

[xlibre-stable]
Server = https://packages.xlibre.net/arch/stable/$arch
REPO
    echo "  → xlibre-stable repo added to pacman.conf"
else
    echo "  → xlibre-stable repo already in pacman.conf"
fi

pacman -Syy

# =====================================================================
# 3. INSTALL XLIBRE
# =====================================================================
step "Installing XLibre (replaces Xorg)"

pacman -S --noconfirm xlibre-meta

# =====================================================================
# 4. GPU DRIVER
# =====================================================================
step "Detecting GPU"

GPU_INFO=$(lspci 2>/dev/null | grep -iE "vga|3d|display" || true)

if echo "$GPU_INFO" | grep -qi "nvidia"; then
    echo "  → NVIDIA detected"
    echo "  → XLibre supports nouveau out of the box."
    echo "  → For proprietary: pacman -S nvidia nvidia-utils"
    echo "  → (Not auto-installing proprietary — it can break things)"

elif echo "$GPU_INFO" | grep -qi "amd\|radeon"; then
    echo "  → AMD/Radeon detected"
    pacman -S --noconfirm --needed mesa vulkan-radeon libva-mesa-driver

elif echo "$GPU_INFO" | grep -qi "intel"; then
    echo "  → Intel detected"
    pacman -S --noconfirm --needed mesa vulkan-intel intel-media-driver

elif echo "$GPU_INFO" | grep -qi "vmware\|virtualbox\|qxl\|virtio"; then
    echo "  → Virtual machine detected"
    pacman -S --noconfirm --needed mesa
else
    echo "  → Could not detect GPU. Installing mesa as fallback."
    pacman -S --noconfirm --needed mesa
fi

# =====================================================================
# 5. AWESOME + DISPLAY MANAGER
# =====================================================================
step "Installing Awesome + LightDM"

pacman -S --noconfirm --needed \
    awesome xorg-xrandr \
    lightdm lightdm-gtk-greeter

systemctl enable lightdm

# =====================================================================
# 6. AUDIO — PIPEWIRE
# =====================================================================
step "Installing PipeWire audio stack"

pacman -S --noconfirm --needed \
    pipewire pipewire-alsa pipewire-pulse pipewire-jack \
    wireplumber \
    pavucontrol

# =====================================================================
# 7. DESKTOP ESSENTIALS
# =====================================================================
step "Installing desktop packages"

pacman -S --noconfirm --needed \
    alacritty \
    rofi \
    picom \
    dunst \
    feh \
    flameshot \
    i3lock \
    playerctl \
    thunar gvfs thunar-volman \
    network-manager-applet \
    bluez bluez-utils \
    blueman \
    brightnessctl \
    arandr \
    lxappearance \
    polkit-gnome \
    xdg-user-dirs \
    xdg-utils \
    xclip \
    xdotool \
    xorg-xsetroot \
    xorg-xset \
    xorg-xdpyinfo

# =====================================================================
# 8. FLATPAK
# =====================================================================
step "Installing Flatpak + Flathub"

pacman -S --noconfirm --needed flatpak
sudo -u "$REAL_USER" flatpak remote-add --if-not-exists flathub \
    https://flathub.org/repo/flathub.flatpakrepo

# =====================================================================
# 9. CLI TOOLS
# =====================================================================
step "Installing CLI tools"

pacman -S --noconfirm --needed \
    git \
    curl \
    wget \
    htop \
    btop \
    neovim \
    ripgrep \
    fd \
    eza \
    bat \
    tree \
    unzip \
    p7zip \
    fastfetch \
    bash-completion \
    man-db \
    man-pages

# =====================================================================
# 10. FONTS
# =====================================================================
step "Installing fonts"

pacman -S --noconfirm --needed \
    ttf-jetbrains-mono-nerd \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    ttf-font-awesome \
    ttf-dejavu

# =====================================================================
# 11. BROWSER
# =====================================================================
step "Installing Firefox"
pacman -S --noconfirm --needed firefox

# =====================================================================
# 12. BUILD TOOLS (for ZarisWM later)
# =====================================================================
step "Installing build tools (C/C++, cmake, xcb — ready for ZarisWM)"

pacman -S --noconfirm --needed \
    cmake \
    pkgconf \
    xcb-util \
    xcb-util-wm \
    xcb-util-keysyms \
    xcb-util-cursor \
    xcb-util-xrm \
    libxcb \
    libx11 \
    libxft \
    libxinerama \
    libxrandr \
    pango \
    cairo \
    startup-notification

# =====================================================================
# 13. THEMING
# =====================================================================
step "Installing GTK themes + icons"

pacman -S --noconfirm --needed \
    papirus-icon-theme \
    arc-gtk-theme

# =====================================================================
# 14. INSTALL yay (AUR HELPER)
# =====================================================================
step "Installing yay (AUR helper)"

if ! command -v yay &>/dev/null; then
    cd /tmp
    sudo -u "$REAL_USER" git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    sudo -u "$REAL_USER" makepkg -si --noconfirm
    cd /
    rm -rf /tmp/yay-bin
    echo "  → yay installed"
else
    echo "  → yay already installed"
fi

# =====================================================================
# 15. ENABLE SERVICES
# =====================================================================
step "Enabling services"

systemctl enable NetworkManager
systemctl enable bluetooth

echo "  → Enabled: NetworkManager, bluetooth, lightdm"
echo "  → snapper-timeline.timer / snapper-cleanup.timer should already"
echo "    be enabled from the manual install steps"

# =====================================================================
# 16. PIPEWIRE USER AUTOSTART
# =====================================================================
step "PipeWire user autostart (handled by wireplumber)"

su - "$REAL_USER" -c "systemctl --user enable pipewire.socket 2>/dev/null" || true
su - "$REAL_USER" -c "systemctl --user enable pipewire-pulse.socket 2>/dev/null" || true
su - "$REAL_USER" -c "systemctl --user enable wireplumber 2>/dev/null" || true

echo "  → PipeWire user services enabled"

# =====================================================================
# 17. XDG USER DIRS
# =====================================================================
step "Creating XDG user directories"
su - "$REAL_USER" -c "xdg-user-dirs-update" 2>/dev/null || true

# =====================================================================
# 18. toggle-hdmi SCRIPT
# =====================================================================
step "Installing toggle-hdmi script"

cat > /usr/local/bin/toggle-hdmi << 'HDMIEOF'
#!/usr/bin/env bash
# Toggles HDMI-A-0 (mirrors DisplayPort-0) on/off.
if xrandr --query | grep -q "^HDMI-A-0 connected [0-9]"; then
    xrandr --output HDMI-A-0 --off
else
    xrandr --output HDMI-A-0 --mode 1920x1080 --rate 60 --rotate normal --same-as DisplayPort-0
fi
HDMIEOF
chmod +x /usr/local/bin/toggle-hdmi

# =====================================================================
# 19. AWESOME CONFIG
# =====================================================================
step "Writing Awesome config"

AWESOME_DIR="$REAL_HOME/.config/awesome"
mkdir -p "$AWESOME_DIR"

# ── theme.lua ────────────────────────────────────────────────────────
# Same palette used everywhere else (deep space navy, nebula blue,
# warm cloud orange, coral pink) — pulled straight from the NixOS setup,
# nothing here is Nix-specific so it ports over unchanged.
cat > "$AWESOME_DIR/theme.lua" << 'THEMEEOF'
local theme_assets = require("beautiful.theme_assets")
local xresources = require("beautiful.xresources")
local dpi = xresources.apply_dpi

local gfs = require("gears.filesystem")
local themes_path = gfs.get_themes_dir()

local theme = {}

theme.font          = "JetBrainsMono Nerd Font 11"

local bg        = "#0a0e1a"
local surface   = "#1a1b26"
local border    = "#292e42"
local text      = "#c0caf5"
local muted     = "#565f89"
local blue      = "#7aa2f7"
local orange    = "#ff9e64"
local pink      = "#f7768e"

theme.bg_normal     = bg
theme.bg_focus      = blue
theme.bg_urgent     = pink
theme.bg_minimize   = surface
theme.bg_systray    = theme.bg_normal

theme.fg_normal     = text
theme.fg_focus      = bg
theme.fg_urgent     = bg
theme.fg_minimize   = muted

theme.useless_gap   = dpi(10)
theme.border_width  = dpi(2)
theme.border_normal = border
theme.border_focus  = blue
theme.border_marked = orange

local taglist_square_size = dpi(4)
theme.taglist_squares_sel = theme_assets.taglist_squares_sel(
    taglist_square_size, theme.fg_normal
)
theme.taglist_squares_unsel = theme_assets.taglist_squares_unsel(
    taglist_square_size, theme.fg_normal
)

theme.menu_submenu_icon = themes_path.."default/submenu.png"
theme.menu_height = dpi(20)
theme.menu_width  = dpi(140)
theme.menu_bg_normal = surface
theme.menu_fg_normal = text
theme.menu_bg_focus = blue
theme.menu_fg_focus = bg
theme.menu_border_color = border

theme.prompt_fg = text
theme.prompt_bg = surface
theme.prompt_fg_cursor = bg
theme.prompt_bg_cursor = blue

theme.titlebar_close_button_normal = themes_path.."default/titlebar/close_normal.png"
theme.titlebar_close_button_focus  = themes_path.."default/titlebar/close_focus.png"

theme.titlebar_minimize_button_normal = themes_path.."default/titlebar/minimize_normal.png"
theme.titlebar_minimize_button_focus  = themes_path.."default/titlebar/minimize_focus.png"

theme.titlebar_ontop_button_normal_inactive = themes_path.."default/titlebar/ontop_normal_inactive.png"
theme.titlebar_ontop_button_focus_inactive  = themes_path.."default/titlebar/ontop_focus_inactive.png"
theme.titlebar_ontop_button_normal_active = themes_path.."default/titlebar/ontop_normal_active.png"
theme.titlebar_ontop_button_focus_active  = themes_path.."default/titlebar/ontop_focus_active.png"

theme.titlebar_sticky_button_normal_inactive = themes_path.."default/titlebar/sticky_normal_inactive.png"
theme.titlebar_sticky_button_focus_inactive  = themes_path.."default/titlebar/sticky_focus_inactive.png"
theme.titlebar_sticky_button_normal_active = themes_path.."default/titlebar/sticky_normal_active.png"
theme.titlebar_sticky_button_focus_active  = themes_path.."default/titlebar/sticky_focus_active.png"

theme.titlebar_floating_button_normal_inactive = themes_path.."default/titlebar/floating_normal_inactive.png"
theme.titlebar_floating_button_focus_inactive  = themes_path.."default/titlebar/floating_focus_inactive.png"
theme.titlebar_floating_button_normal_active = themes_path.."default/titlebar/floating_normal_active.png"
theme.titlebar_floating_button_focus_active  = themes_path.."default/titlebar/floating_focus_active.png"

theme.titlebar_maximized_button_normal_inactive = themes_path.."default/titlebar/maximized_normal_inactive.png"
theme.titlebar_maximized_button_focus_inactive  = themes_path.."default/titlebar/maximized_focus_inactive.png"
theme.titlebar_maximized_button_normal_active = themes_path.."default/titlebar/maximized_normal_active.png"
theme.titlebar_maximized_button_focus_active  = themes_path.."default/titlebar/maximized_focus_active.png"

theme.titlebar_bg_normal = surface
theme.titlebar_fg_normal = muted
theme.titlebar_bg_focus = surface
theme.titlebar_fg_focus = text

theme.wallpaper = os.getenv("HOME") .. "/.config/awesome/wallpaper.jpg"

theme.layout_fairh = themes_path.."default/layouts/fairhw.png"
theme.layout_fairv = themes_path.."default/layouts/fairvw.png"
theme.layout_floating  = themes_path.."default/layouts/floatingw.png"
theme.layout_magnifier = themes_path.."default/layouts/magnifierw.png"
theme.layout_max = themes_path.."default/layouts/maxw.png"
theme.layout_fullscreen = themes_path.."default/layouts/fullscreenw.png"
theme.layout_tilebottom = themes_path.."default/layouts/tilebottomw.png"
theme.layout_tileleft   = themes_path.."default/layouts/tileleftw.png"
theme.layout_tile = themes_path.."default/layouts/tilew.png"
theme.layout_tiletop = themes_path.."default/layouts/tiletopw.png"
theme.layout_spiral  = themes_path.."default/layouts/spiralw.png"
theme.layout_dwindle = themes_path.."default/layouts/dwindlew.png"
theme.layout_cornernw = themes_path.."default/layouts/cornernww.png"
theme.layout_cornerne = themes_path.."default/layouts/cornernew.png"
theme.layout_cornersw = themes_path.."default/layouts/cornersww.png"
theme.layout_cornerse = themes_path.."default/layouts/cornersew.png"

theme.awesome_icon = theme_assets.awesome_icon(
    theme.menu_height, theme.bg_focus, theme.fg_focus
)

theme.icon_theme = nil

return theme
THEMEEOF

# ── rc.lua ───────────────────────────────────────────────────────────
# Same layout order (dwindle/spiral included), same keybindings, same
# monitor setup as the NixOS Awesome config. Differences from that
# version: this restores Awesome's own wibar (there's no quickshell
# here), and points at real binary paths instead of Nix store paths.
#
# NOTE: the xrandr line below assumes the same monitor names
# (DisplayPort-0/1/2, HDMI-A-0) as the NixOS box. Run `xrandr --query`
# after first login and adjust the names below if XLibre reports them
# differently.
cat > "$AWESOME_DIR/rc.lua" << 'RCEOF'
pcall(require, "luarocks.loader")

local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
local wibox = require("wibox")
local beautiful = require("beautiful")
local naughty = require("naughty")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
require("awful.hotkeys_popup.keys")

if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        if in_error then return end
        in_error = true
        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = tostring(err) })
        in_error = false
    end)
end

beautiful.init(os.getenv("HOME") .. "/.config/awesome/theme.lua")

terminal = "alacritty"
editor = os.getenv("EDITOR") or "nvim"
editor_cmd = terminal .. " -e " .. editor

modkey = "Mod4"

awful.layout.layouts = {
    awful.layout.suit.fair,
    awful.layout.suit.tile,
    awful.layout.suit.floating,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.tile.top,
    awful.layout.suit.fair.horizontal,
    awful.layout.suit.spiral,
    awful.layout.suit.spiral.dwindle,
    awful.layout.suit.max,
    awful.layout.suit.max.fullscreen,
    awful.layout.suit.magnifier,
    awful.layout.suit.corner.nw,
}

-- Monitor setup: same layout as the NixOS box (DP-0 primary 165Hz,
-- DP-1 rotated right 144Hz, DP-2 144Hz, HDMI-A-0 off/mirror-on-demand).
-- Double check output names with `xrandr --query` if this doesn't apply.
awful.spawn.with_shell(
    "xrandr" ..
    " --output DisplayPort-0 --mode 1920x1080 --rate 165 --pos 0x0 --rotate normal --primary" ..
    " --output DisplayPort-1 --mode 1920x1080 --rate 144 --rotate right --right-of DisplayPort-0" ..
    " --output DisplayPort-2 --mode 1920x1080 --rate 144 --rotate normal --right-of DisplayPort-1" ..
    " --output HDMI-A-0 --off"
)

awful.spawn("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
awful.spawn("nm-applet")
awful.spawn("blueman-applet")
awful.spawn.with_shell("picom --daemon --backend glx --vsync")
awful.spawn("dunst")

local function set_wallpaper(s)
    if beautiful.wallpaper then
        local wallpaper = beautiful.wallpaper
        if type(wallpaper) == "function" then
            wallpaper = wallpaper(s)
        end
        if gears.filesystem.file_readable(wallpaper) then
            gears.wallpaper.maximized(wallpaper, s, false)
        else
            gears.wallpaper.set(beautiful.bg_normal)
        end
    end
end

screen.connect_signal("property::geometry", set_wallpaper)

awful.screen.connect_for_each_screen(function(s)
    set_wallpaper(s)
    awful.tag({ "1", "2", "3", "4", "5", "6", "7", "8", "9" }, s, awful.layout.layouts[1])
    s.mypromptbox = awful.widget.prompt()
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
        awful.button({ }, 1, function () awful.layout.inc( 1) end),
        awful.button({ }, 3, function () awful.layout.inc(-1) end),
        awful.button({ }, 4, function () awful.layout.inc( 1) end),
        awful.button({ }, 5, function () awful.layout.inc(-1) end)
    ))

    s.mytaglist = awful.widget.taglist {
        screen  = s,
        filter  = awful.widget.taglist.filter.all,
        buttons = gears.table.join(
            awful.button({ }, 1, function(t) t:view_only() end),
            awful.button({ modkey }, 1, function(t) if client.focus then client.focus:move_to_tag(t) end end),
            awful.button({ }, 3, awful.tag.viewtoggle),
            awful.button({ modkey }, 3, function(t) if client.focus then client.focus:toggle_tag(t) end end),
            awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
            awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end)
        ),
    }

    s.mytasklist = awful.widget.tasklist {
        screen  = s,
        filter  = awful.widget.tasklist.filter.currenttags,
        buttons = gears.table.join(
            awful.button({ }, 1, function (c)
                c:emit_signal("request::activate", "tasklist", {raise = true})
            end),
            awful.button({ }, 3, function() awful.menu.client_list({ theme = { width = 250 } }) end),
            awful.button({ }, 4, function() awful.client.focus.byidx(1) end),
            awful.button({ }, 5, function() awful.client.focus.byidx(-1) end)
        ),
    }

    s.mywibox = awful.wibar({ position = "top", screen = s, height = 28 })
    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left
            layout = wibox.layout.fixed.horizontal,
            s.mytaglist,
        },
        s.mytasklist, -- Middle
        { -- Right
            layout = wibox.layout.fixed.horizontal,
            wibox.widget.systray(),
            wibox.widget.textclock(" %a %b %d  %H:%M:%S "),
            s.mylayoutbox,
        },
    }
end)

root.buttons(gears.table.join(
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))

globalkeys = gears.table.join(
    awful.key({ modkey }, "s", hotkeys_popup.show_help,
              {description="show help", group="awesome"}),
    awful.key({ modkey }, "Escape", awful.tag.history.restore,
              {description = "go back", group = "tag"}),

    awful.key({ modkey }, "Left", function () awful.client.focus.bydirection("left") end,
        {description = "focus left", group = "client"}),
    awful.key({ modkey }, "Right", function () awful.client.focus.bydirection("right") end,
        {description = "focus right", group = "client"}),
    awful.key({ modkey }, "Up", function () awful.client.focus.bydirection("up") end,
        {description = "focus up", group = "client"}),
    awful.key({ modkey }, "Down", function () awful.client.focus.bydirection("down") end,
        {description = "focus down", group = "client"}),

    awful.key({ modkey }, "q", function ()
        if client.focus then client.focus:kill() end
    end, {description = "close focused window", group = "client"}),

    awful.key({ modkey }, "e", function () awful.spawn("thunar") end,
              {description = "open file manager", group = "launcher"}),
    awful.key({ modkey }, "d", function () awful.spawn("toggle-hdmi") end,
              {description = "toggle HDMI monitor", group = "screen"}),
    awful.key({ modkey, "Shift" }, "x", function () awful.spawn("i3lock") end,
              {description = "lock screen", group = "awesome"}),
    awful.key({ }, "Print", function () awful.spawn("flameshot gui") end,
              {description = "screenshot", group = "launcher"}),

    awful.key({ }, "XF86AudioRaiseVolume", function () awful.spawn("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+") end,
              {description = "raise volume", group = "media"}),
    awful.key({ }, "XF86AudioLowerVolume", function () awful.spawn("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") end,
              {description = "lower volume", group = "media"}),
    awful.key({ }, "XF86AudioMute", function () awful.spawn("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") end,
              {description = "mute", group = "media"}),
    awful.key({ }, "XF86MonBrightnessUp", function () awful.spawn("brightnessctl set +5%") end,
              {description = "brightness up", group = "media"}),
    awful.key({ }, "XF86MonBrightnessDown", function () awful.spawn("brightnessctl set 5%-") end,
              {description = "brightness down", group = "media"}),
    awful.key({ }, "XF86AudioPlay", function () awful.spawn("playerctl play-pause") end,
              {description = "play/pause", group = "media"}),
    awful.key({ }, "XF86AudioNext", function () awful.spawn("playerctl next") end,
              {description = "next track", group = "media"}),
    awful.key({ }, "XF86AudioPrev", function () awful.spawn("playerctl previous") end,
              {description = "previous track", group = "media"}),

    awful.key({ modkey }, "j", function () awful.client.focus.byidx(1) end,
        {description = "focus next by index", group = "client"}),
    awful.key({ modkey }, "k", function () awful.client.focus.byidx(-1) end,
        {description = "focus previous by index", group = "client"}),

    awful.key({ modkey, "Shift" }, "j", function () awful.client.swap.byidx(1) end,
              {description = "swap with next client by index", group = "client"}),
    awful.key({ modkey, "Shift" }, "k", function () awful.client.swap.byidx(-1) end,
              {description = "swap with previous client by index", group = "client"}),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative(1) end,
              {description = "focus the next screen", group = "screen"}),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end,
              {description = "focus the previous screen", group = "screen"}),
    awful.key({ modkey }, "u", awful.client.urgent.jumpto,
              {description = "jump to urgent client", group = "client"}),
    awful.key({ modkey }, "Tab", function ()
        awful.client.focus.history.previous()
        if client.focus then client.focus:raise() end
    end, {description = "go back", group = "client"}),

    awful.key({ modkey }, "Return", function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Shift" }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),

    awful.key({ modkey }, "l", function () awful.tag.incmwfact(0.05) end,
              {description = "increase master width factor", group = "layout"}),
    awful.key({ modkey }, "h", function () awful.tag.incmwfact(-0.05) end,
              {description = "decrease master width factor", group = "layout"}),
    awful.key({ modkey, "Shift" }, "h", function () awful.tag.incnmaster(1, nil, true) end,
              {description = "increase the number of master clients", group = "layout"}),
    awful.key({ modkey, "Shift" }, "l", function () awful.tag.incnmaster(-1, nil, true) end,
              {description = "decrease the number of master clients", group = "layout"}),
    awful.key({ modkey, "Control" }, "h", function () awful.tag.incncol(1, nil, true) end,
              {description = "increase the number of columns", group = "layout"}),
    awful.key({ modkey, "Control" }, "l", function () awful.tag.incncol(-1, nil, true) end,
              {description = "decrease the number of columns", group = "layout"}),

    awful.key({ modkey }, "space", function () awful.spawn("rofi -show drun -show-icons") end,
              {description = "application launcher", group = "launcher"}),
    awful.key({ modkey, "Control" }, "space", function () awful.layout.inc(1) end,
              {description = "select next layout", group = "layout"}),
    awful.key({ modkey, "Shift" }, "space", function () awful.layout.inc(-1) end,
              {description = "select previous layout", group = "layout"}),

    awful.key({ modkey, "Control" }, "n", function ()
        local c = awful.client.restore()
        if c then
            c:emit_signal("request::activate", "key.unminimize", {raise = true})
        end
    end, {description = "restore minimized", group = "client"}),

    awful.key({ modkey }, "r", function () awful.screen.focused().mypromptbox:run() end,
              {description = "run prompt", group = "launcher"}),
    awful.key({ modkey }, "p", function() menubar.show() end,
              {description = "show the menubar", group = "launcher"})
)

clientkeys = gears.table.join(
    awful.key({ modkey }, "f", function (c)
        c.fullscreen = not c.fullscreen
        c:raise()
    end, {description = "toggle fullscreen", group = "client"}),
    awful.key({ modkey, "Shift" }, "c", function (c) c:kill() end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "space", awful.client.floating.toggle,
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    awful.key({ modkey }, "o", function (c) c:move_to_screen() end,
              {description = "move to screen", group = "client"}),
    awful.key({ modkey }, "t", function (c) c.ontop = not c.ontop end,
              {description = "toggle keep on top", group = "client"}),
    awful.key({ modkey }, "n", function (c) c.minimized = true end,
              {description = "minimize", group = "client"}),
    awful.key({ modkey }, "m", function (c)
        c.maximized = not c.maximized
        c:raise()
    end, {description = "(un)maximize", group = "client"})
)

for i = 1, 9 do
    globalkeys = gears.table.join(globalkeys,
        awful.key({ modkey }, "#" .. i + 9, function ()
            local screen = awful.screen.focused()
            local tag = screen.tags[i]
            if tag then tag:view_only() end
        end, {description = "view tag #"..i, group = "tag"}),
        awful.key({ modkey, "Control" }, "#" .. i + 9, function ()
            local screen = awful.screen.focused()
            local tag = screen.tags[i]
            if tag then awful.tag.viewtoggle(tag) end
        end, {description = "toggle tag #" .. i, group = "tag"}),
        awful.key({ modkey, "Shift" }, "#" .. i + 9, function ()
            if client.focus then
                local tag = client.focus.screen.tags[i]
                if tag then client.focus:move_to_tag(tag) end
            end
        end, {description = "move focused client to tag #"..i, group = "tag"}),
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9, function ()
            if client.focus then
                local tag = client.focus.screen.tags[i]
                if tag then client.focus:toggle_tag(tag) end
            end
        end, {description = "toggle focused client on tag #" .. i, group = "tag"})
    )
end

clientbuttons = gears.table.join(
    awful.button({ }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
    end),
    awful.button({ modkey }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.move(c)
    end),
    awful.button({ modkey }, 3, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.resize(c)
    end)
)

root.keys(globalkeys)

awful.rules.rules = {
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = awful.client.focus.filter,
                     raise = true,
                     keys = clientkeys,
                     buttons = clientbuttons,
                     screen = awful.screen.preferred,
                     placement = awful.placement.no_overlap+awful.placement.no_offscreen
     }
    },
    { rule_any = {
        instance = { "DTA", "copyq", "pinentry" },
        class = {
          "Arandr", "Blueman-manager", "Gpick", "Kruler",
          "MessageWin", "Sxiv", "Tor Browser", "Wpa_gui",
          "veromix", "xtightvncviewer"},
        name = { "Event Tester" },
        role = { "AlarmWindow", "ConfigManager", "pop-up" }
      }, properties = { floating = true }},
}

client.connect_signal("manage", function (c)
    if awesome.startup
      and not c.size_hints.user_position
      and not c.size_hints.program_position then
        awful.placement.no_offscreen(c)
    end
end)

client.connect_signal("request::titlebars", function(c)
    local buttons = gears.table.join(
        awful.button({ }, 1, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 3, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.resize(c)
        end)
    )
    awful.titlebar(c) : setup {
        { awful.titlebar.widget.iconwidget(c), buttons = buttons, layout = wibox.layout.fixed.horizontal },
        { { align = "center", widget = awful.titlebar.widget.titlewidget(c) }, buttons = buttons, layout = wibox.layout.flex.horizontal },
        { awful.titlebar.widget.floatingbutton(c), awful.titlebar.widget.maximizedbutton(c),
          awful.titlebar.widget.stickybutton(c), awful.titlebar.widget.ontopbutton(c),
          awful.titlebar.widget.closebutton(c), layout = wibox.layout.fixed.horizontal() },
        layout = wibox.layout.align.horizontal
    }
end)

client.connect_signal("mouse::enter", function(c)
    c:emit_signal("request::activate", "mouse_enter", {raise = false})
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
RCEOF

# ── wallpaper ────────────────────────────────────────────────────────
if [[ -f "$SCRIPT_DIR/wallpaper.jpg" ]]; then
    cp "$SCRIPT_DIR/wallpaper.jpg" "$AWESOME_DIR/wallpaper.jpg"
    echo "  → wallpaper.jpg copied in"
else
    echo "  → No wallpaper.jpg next to this script — Awesome will fall back"
    echo "    to a solid background color until you drop one at"
    echo "    $AWESOME_DIR/wallpaper.jpg"
fi

chown -R "$REAL_USER:$REAL_USER" "$AWESOME_DIR"

# ── .xinitrc fallback (only used for manual `startx`, not LightDM) ────
cat > "$REAL_HOME/.xinitrc" << 'XIEOF'
#!/bin/sh
[ -d /etc/X11/xinit/xinitrc.d ] && for f in /etc/X11/xinit/xinitrc.d/?*.sh; do
    [ -x "$f" ] && . "$f"
done
exec awesome
XIEOF
chmod +x "$REAL_HOME/.xinitrc"
chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.xinitrc"

# =====================================================================
# 20. ALACRITTY CONFIG
# =====================================================================
step "Writing Alacritty config"

ALACRITTY_DIR="$REAL_HOME/.config/alacritty"
mkdir -p "$ALACRITTY_DIR"

cat > "$ALACRITTY_DIR/alacritty.toml" << 'ALEOF'
[font]
size = 11.0

[font.normal]
family = "JetBrainsMono Nerd Font"
style = "Regular"

[font.bold]
family = "JetBrainsMono Nerd Font"
style = "Bold"

[font.italic]
family = "JetBrainsMono Nerd Font"
style = "Italic"

[window]
padding = { x = 8, y = 8 }
opacity = 0.95

[colors.primary]
background = "#1E1E2E"
foreground = "#CDD6F4"

[colors.cursor]
text = "#1E1E2E"
cursor = "#F5E0DC"

[colors.normal]
black   = "#45475A"
red     = "#F38BA8"
green   = "#A6E3A1"
yellow  = "#F9E2AF"
blue    = "#89B4FA"
magenta = "#F5C2E7"
cyan    = "#94E2D5"
white   = "#BAC2DE"

[colors.bright]
black   = "#585B70"
red     = "#F38BA8"
green   = "#A6E3A1"
yellow  = "#F9E2AF"
blue    = "#89B4FA"
magenta = "#F5C2E7"
cyan    = "#94E2D5"
white   = "#A6ADC8"
ALEOF

chown -R "$REAL_USER:$REAL_USER" "$ALACRITTY_DIR"

# =====================================================================
# 21. PICOM CONFIG
# =====================================================================
step "Writing Picom config"

PICOM_DIR="$REAL_HOME/.config/picom"
mkdir -p "$PICOM_DIR"

cat > "$PICOM_DIR/picom.conf" << 'PCEOF'
backend = "glx";
vsync = true;

active-opacity = 1.0;
inactive-opacity = 0.92;
frame-opacity = 1.0;
inactive-opacity-override = false;

# Fading off by default -- on the NixOS box this was the actual cause of
# a perceptible "delay before anything appears" on every redraw, not
# just window open/close. Flip to true only if you want it and have
# confirmed it doesn't reintroduce that lag.
fading = false;
fade-in-step = 0.03;
fade-out-step = 0.03;
fade-delta = 5;

shadow = true;
shadow-radius = 12;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.5;
shadow-exclude = [
    "name = 'Notification'",
    "class_g ?= 'Dunst'",
    "_GTK_FRAME_EXTENTS@:c",
];

corner-radius = 8;
rounded-corners-exclude = [
    "window_type = 'dock'",
    "window_type = 'desktop'",
];
PCEOF

chown -R "$REAL_USER:$REAL_USER" "$PICOM_DIR"

# =====================================================================
# 22. DUNST CONFIG
# =====================================================================
step "Writing Dunst config"

DUNST_DIR="$REAL_HOME/.config/dunst"
mkdir -p "$DUNST_DIR"

cat > "$DUNST_DIR/dunstrc" << 'DNEOF'
[global]
    monitor = 0
    follow = mouse
    width = 350
    height = 150
    origin = top-right
    offset = 12x12
    progress_bar = true
    indicate_hidden = yes
    transparency = 10
    separator_height = 2
    padding = 12
    horizontal_padding = 12
    frame_width = 2
    frame_color = "#89b4fa"
    separator_color = frame
    sort = yes
    font = JetBrainsMono Nerd Font 10
    markup = full
    format = "<b>%s</b>\n%b"
    alignment = left
    show_age_threshold = 60
    icon_position = left
    max_icon_size = 48
    corner_radius = 8

[urgency_low]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    timeout = 5

[urgency_normal]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    timeout = 10

[urgency_critical]
    background = "#1e1e2e"
    foreground = "#f38ba8"
    frame_color = "#f38ba8"
    timeout = 0
DNEOF

chown -R "$REAL_USER:$REAL_USER" "$DUNST_DIR"

# =====================================================================
# 23. ROFI CONFIG
# =====================================================================
step "Writing Rofi config"

ROFI_DIR="$REAL_HOME/.config/rofi"
mkdir -p "$ROFI_DIR"

cat > "$ROFI_DIR/config.rasi" << 'ROEOF'
configuration {
    show-icons: true;
    icon-theme: "Papirus-Dark";
    display-drun: " Apps";
    display-run: " Run";
    display-window: " Windows";
    font: "JetBrainsMono Nerd Font 12";
}

* {
    bg:     #1e1e2edd;
    bg-alt: #313244;
    fg:     #cdd6f4;
    accent: #89b4fa;
    urgent: #f38ba8;

    background-color: transparent;
    text-color: @fg;
}

window {
    width: 500px;
    background-color: @bg;
    border: 2px;
    border-color: @accent;
    border-radius: 12px;
    padding: 20px;
}

inputbar {
    children: [prompt, entry];
    spacing: 8px;
    padding: 8px 12px;
    background-color: @bg-alt;
    border-radius: 8px;
}

prompt {
    text-color: @accent;
}

entry {
    placeholder: "Search...";
}

listview {
    lines: 8;
    columns: 1;
    spacing: 4px;
    padding: 8px 0 0 0;
}

element {
    padding: 8px 12px;
    border-radius: 6px;
}

element selected {
    background-color: @accent;
    text-color: #1e1e2e;
}
ROEOF

chown -R "$REAL_USER:$REAL_USER" "$ROFI_DIR"

# =====================================================================
# DONE
# =====================================================================
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✓ SETUP COMPLETE"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "  Installed:"
echo "    • XLibre X server (xlibre-meta from xlibre-stable repo)"
echo "    • Awesome + full config (dwindle/spiral layouts, same"
echo "      keybindings as the NixOS box, native wibar)"
echo "    • LightDM display manager"
echo "    • PipeWire audio, Bluetooth, NetworkManager"
echo "    • Alacritty, Rofi, Picom (fade off), Dunst, Feh, Flameshot"
echo "    • i3lock, playerctl, Flatpak + Flathub"
echo "    • JetBrainsMono Nerd Font + Noto fonts"
echo "    • Firefox, yay (AUR helper)"
echo "    • Build tools ready for ZarisWM"
echo ""
echo "  Snapper (Btrfs snapshots) was set up during the manual install"
echo "  steps -- 'sudo snapper -c root list' to see snapshots,"
echo "  'sudo snapper -c root create --description \"...\"' before"
echo "  anything risky."
echo ""
echo "  Verify XLibre after reboot:"
echo "    xdpyinfo | grep vendor"
echo ""
echo "  Double check monitor names match rc.lua's xrandr line:"
echo "    xrandr --query"
echo ""
echo "  Build ZarisWM when ready:"
echo "    git clone https://github.com/crosseyedCOBRA/zaris.git"
echo "    cd zaris && mkdir build && cd build"
echo "    cmake -DCMAKE_BUILD_TYPE=Release .."
echo "    make -j\$(nproc) && sudo make install"
echo ""
echo "  → sudo reboot"
echo ""
