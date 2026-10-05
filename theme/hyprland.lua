-- AETHER — Hyprland surfaces. Loaded only while the AETHER theme is active
-- (before ~/.config/hypr/*, so personal settings there still win).

local active_border_color = { colors = { "rgba(55d6ffcc)", "rgba(9b8cff80)" }, angle = 45 }
local inactive_border_color = "rgba(263544aa)"

hl.config({
  general = {
    border_size = 1,
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },

  decoration = {
    rounding = 14,
    -- Soft and wide rather than heavy.
    shadow = {
      enabled = true,
      range = 22,
      render_power = 3,
      color = "rgba(02040a88)",
      color_inactive = "rgba(02040a55)",
    },
    blur = {
      enabled = true,
      size = 6,
      passes = 2,
      vibrancy = 0.12,
    },
  },

  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },
})

-- Frosted glass behind the floating bar and notification cards. ignore_alpha
-- keeps the blur inside the visible (rounded) shape.
hl.layer_rule({ match = { namespace = "^(omarchy-bar|omarchy-notifications|omarchy-osd)$" }, blur = true, ignore_alpha = 0.3 })
