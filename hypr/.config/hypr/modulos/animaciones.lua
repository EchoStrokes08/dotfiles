-- Animaciones: https://wiki.hypr.land/configuring/core/animations/
-- Curvas bezier: diseñar en https://cubic-bezier.com  ·  springs: masa/rigidez/amortiguación

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}    } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}  } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 })

-- { leaf, speed, curva, estilo? }  — "curva" es bezier salvo las marcadas como spring
local animaciones = {
    { "global",        10,   "default"                   },
    { "border",        5.39, "easeOutQuint"              },
    { "windows",       4.79, "easy",         nil, true   },
    { "windowsIn",     4.1,  "easy",         "popin 87%", true },
    { "windowsOut",    1.49, "linear",       "popin 87%" },
    { "fadeIn",        1.73, "almostLinear"              },
    { "fadeOut",       1.46, "almostLinear"              },
    { "fade",          3.03, "quick"                     },
    { "layers",        3.81, "easeOutQuint"              },
    { "layersIn",      4,    "easeOutQuint", "fade"      },
    { "layersOut",     1.5,  "linear",       "fade"      },
    { "fadeLayersIn",  1.79, "almostLinear"              },
    { "fadeLayersOut", 1.39, "almostLinear"              },
    { "workspaces",    1.94, "almostLinear", "fade"      },
    { "workspacesIn",  1.21, "almostLinear", "fade"      },
    { "workspacesOut", 1.94, "almostLinear", "fade"      },
    { "zoomFactor",    7,    "quick"                     },
}

for _, a in ipairs(animaciones) do
    local leaf, speed, curva, estilo, es_spring = a[1], a[2], a[3], a[4], a[5]
    local spec = { leaf = leaf, enabled = true, speed = speed, style = estilo }
    if es_spring then spec.spring = curva else spec.bezier = curva end
    hl.animation(spec)
end
