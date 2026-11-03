-- Animaciones: https://wiki.hypr.land/configuring/core/animations/
-- Curvas bezier: diseñar en https://cubic-bezier.com  ·  springs: masa/rigidez/amortiguación

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}    } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}  } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 })

-- ---------- Curvas propias (Nivel 3) ----------
-- Spring: el rebote depende de ζ = damping / (2·√(stiffness·mass)).
--   ζ = 1 → sin rebote · ζ < 1 → rebota · cuanto más bajo, más rebota.
--   "easy" (la de serie): ζ ≈ 0.78.  "ayuRebote": ζ = 25 / (2·√320) ≈ 0.70 → un pelín más vivo y rápido.
hl.curve("ayuRebote",   { type = "spring", mass = 1, stiffness = 320, damping = 25 })
-- Bezier tipo "ease-out expo": arranca rápido y frena suave. Probar en https://cubic-bezier.com/#.16,1,.3,1
hl.curve("ayuDeslizar", { type = "bezier", points = { {0.16, 1}, {0.3, 1} } })
-- Con un poco de "sobrepaso" (y > 1): se pasa un 4 % y vuelve. Para el scratchpad.
hl.curve("ayuAsomar",   { type = "bezier", points = { {0.34, 1.04}, {0.64, 1} } })

-- { leaf, speed, curva, estilo? }  — "curva" es bezier salvo las marcadas como spring
local animaciones = {
    { "global",        10,   "default"                   },
    { "border",        5.39, "easeOutQuint"              },
    { "windows",       4.79, "easy",         nil, true   },
    { "windowsIn",     4.1,  "ayuRebote",    "popin 87%", true },  -- propia
    { "windowsOut",    1.49, "linear",       "popin 87%" },
    { "fadeIn",        1.73, "almostLinear"              },
    { "fadeOut",       1.46, "almostLinear"              },
    { "fade",          3.03, "quick"                     },
    { "layers",        3.81, "easeOutQuint"              },
    { "layersIn",      4,    "easeOutQuint", "fade"      },
    { "layersOut",     1.5,  "linear",       "fade"      },
    { "fadeLayersIn",  1.79, "almostLinear"              },
    { "fadeLayersOut", 1.39, "almostLinear"              },
    { "workspaces",    3.5,  "ayuDeslizar",  "slidefade 20%" },  -- propia: desliza + desvanece
    { "workspacesIn",  3.5,  "ayuDeslizar",  "slidefade 20%" },
    { "workspacesOut", 3.5,  "ayuDeslizar",  "slidefade 20%" },
    { "specialWorkspace", 3, "ayuAsomar",    "slidefadevert 25%" },  -- scratchpad (SUPER+S) sube desde abajo
    { "zoomFactor",    7,    "quick"                     },
}

for _, a in ipairs(animaciones) do
    local leaf, speed, curva, estilo, es_spring = a[1], a[2], a[3], a[4], a[5]
    local spec = { leaf = leaf, enabled = true, speed = speed, style = estilo }
    if es_spring then spec.spring = curva else spec.bezier = curva end
    hl.animation(spec)
end
