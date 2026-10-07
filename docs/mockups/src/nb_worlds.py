"""World palettes for MWM Neon Bricks, worlds 1-6 (DESIGN section 11). Pure Python, no bpy.

Colours are sRGB hex. "Displayed" colours are what the player sees through the field glass;
sources are derived from them (src_lin = displayed_lin / glass transmission).
"""

GLASS_ALPHA = 0.72  # field glass everywhere
WINDOW_ALPHA = 0.55  # glass alpha inside a motif window (DESIGN 13.1)

WORLDS = {
    1: {
        "name": "Neonstranda",
        "sky": {"top": "#0B0630", "mid": "#3A0E5C", "low": "#C2186B", "horizon": "#FF7A3D"},
        "stars": {"col": "#FFEBF2", "gain": 0.6, "square": 0, "density": 0.975},
        "motif": {"kind": 1, "c": (0.0, 0.012), "r": 0.222, "window": True,
                  # displayed through the window: top, mid, low (DESIGN 13.1)
                  "top": "#D2402E", "mid": "#D4326C", "low": "#A42CC4", "rim": "#F27088"},
        "ridge": {"col": "#FF2E88", "gain": 1.0, "height": 1.0, "solid": "#120618"},
        "nebula": None,
        "floor": {"mode": "grid", "base": "#07041A", "line": "#D63AF9", "period": 3.0, "width": 0.035, "gain": 0.85,
                  "streak": "#FF7A3D", "haze": "#9E1F4C"},
        "tube": "#FF2E88", "rail": "#15122B", "card_rim": "#FF2E88",
        "ramp": ["sun", "tangerine", "coral", "hotpink", "magenta"],
        "key": "#D9E6FF", "key_energy": 1.1, "fill": "#FF7359", "ambient_energy": 0.7,
        "psm_top": "#1A0D4D", "psm_horizon": "#D94073",
    },
    2: {
        "name": "Rutenettbyen",
        "sky": {"top": "#040A22", "mid": "#0B1C48", "low": "#1D3C7A", "horizon": "#3A6FD0"},
        "stars": {"col": "#DCE6FF", "gain": 0.35, "square": 0, "density": 0.985},
        "motif": {"kind": 2, "c": (0.07, 0.86), "r": 0.075, "window": False,
                  # full moon in the sky band (no glass, no luminance cap)
                  "top": "#E4ECFF", "mid": "#B4C6FF", "low": "#8FA6F0", "rim": "#FFFFFF"},
        "ridge": None,
        "nebula": None,
        "floor": {"mode": "grid", "base": "#040814", "line": "#3D7BFF", "period": 2.0, "width": 0.03, "gain": 0.8,
                  "streak": "#FFB547", "haze": "#1D3C7A"},
        "tube": "#3D7BFF", "rail": "#0C1430", "card_rim": "#3D7BFF",
        "ramp": ["hotpink", "coral", "tangerine", "sun"],
        "key": "#E0E8FF", "key_energy": 1.1, "fill": "#4D7BFF", "ambient_energy": 0.6,
        "psm_top": "#0B1C48", "psm_horizon": "#3A6FD0",
    },
    3: {
        "name": "Arkadehallen",
        "sky": {"top": "#0E0818", "mid": "#1C0E2A", "low": "#3A1838", "horizon": "#C8501E"},
        "stars": {"col": "#FFE14D", "gain": 0.9, "square": 1, "density": 0.982},
        "motif": {"kind": 3, "c": (0.0, 0.10), "r": 0.075, "window": True,
                  # screen base, pixel hills, pixel sun, bezel rim
                  "top": "#B4400E", "mid": "#8A1F66", "low": "#12082A", "rim": "#B89A3A"},
        "ridge": None,
        "nebula": None,
        "floor": {"mode": "checker", "base": "#0F0716", "base2": "#22102E", "line": "#FFC93C", "period": 2.5, "width": 0.025,
                  "gain": 0.75, "streak": "#FF3D6E", "haze": "#3A1838"},
        "tube": "#FFC93C", "rail": "#1E1020", "card_rim": "#FFC93C",
        "ramp": ["sun", "coral", "hotpink", "violet"],
        "key": "#FFF0D9", "key_energy": 1.15, "fill": "#FF8A3D", "ambient_energy": 0.6,
        "psm_top": "#1C0E2A", "psm_horizon": "#C8501E",
    },
    4: {
        "name": "Nattveien",
        "sky": {"top": "#05030C", "mid": "#160818", "low": "#3E0C1C", "horizon": "#C0283A"},
        "stars": {"col": "#FFE6C8", "gain": 0.45, "square": 0, "density": 0.982},
        "motif": {"kind": 0, "c": (0.0, 0.0), "r": 1.0, "window": False,
                  "top": "#000000", "mid": "#000000", "low": "#000000", "rim": "#000000"},
        "ridge": {"col": "#FF3B30", "gain": 0.8, "height": 1.6, "solid": "#0A0510"},
        "nebula": None,
        "floor": {"mode": "road", "base": "#0A0710", "line": "#5A1028", "period": 4.0, "width": 0.03, "gain": 0.6,
                  "dash": "#FFB23D", "edge": "#FF3B30", "streak": "#FF3B30", "haze": "#3E0C1C"},
        "tube": "#FF3B30", "rail": "#1A0A12", "card_rim": "#FF5A3C",
        "ramp": ["coral", "tangerine", "sun", "hotpink"],
        "key": "#FFE6D0", "key_energy": 1.05, "fill": "#FF3B30", "ambient_energy": 0.55,
        "psm_top": "#160818", "psm_horizon": "#C0283A",
    },
    5: {
        "name": "Krystallgrotta",
        "sky": {"top": "#02060C", "mid": "#061624", "low": "#0E2438", "horizon": "#1E5A4E"},
        "stars": {"col": "#9CFFC8", "gain": 0.25, "square": 0, "density": 0.99},
        "motif": {"kind": 5, "c": (0.0, 0.10), "r": 0.13, "window": True,
                  "top": "#6A44E0", "mid": "#4A2CB0", "low": "#2A1A80", "rim": "#20A060"},
        "ridge": None,
        "nebula": {"a": "#1B2A4A", "b": "#123A34", "gain": 0.5},
        "floor": {"mode": "lattice", "base": "#03070C", "line": "#6A4CFF", "period": 2.5, "width": 0.03, "gain": 0.45,
                  "streak": "#4DFF9A", "haze": "#1B2A4A"},
        "tube": "#4DFF9A", "rail": "#0A1A20", "card_rim": "#3DDC8A",
        "ramp": ["mint", "violet", "magenta", "hotpink"],
        "key": "#D9FFF0", "key_energy": 1.05, "fill": "#8A5CFF", "ambient_energy": 0.6,
        "psm_top": "#061624", "psm_horizon": "#1E5A4E",
    },
    6: {
        "name": "Stjerneporten",
        "sky": {"top": "#020108", "mid": "#120828", "low": "#2A0C4A", "horizon": "#5A1C8A"},
        "stars": {"col": "#FFF0F8", "gain": 0.8, "square": 0, "density": 0.965},
        "motif": {"kind": 6, "c": (0.0, 0.16), "r": 0.30, "window": False,
                  "top": "#8A5CFF", "mid": "#D63AF9", "low": "#2A0C4A", "rim": "#FFD27A"},
        "ridge": None,
        "nebula": {"a": "#5A2CB0", "b": "#A0249C", "gain": 0.55},
        "floor": {"mode": "grid", "base": "#05030E", "line": "#FFD27A", "period": 3.0, "width": 0.025, "gain": 0.55,
                  "streak": "#8A5CFF", "haze": "#2A0C4A"},
        "tube": "#8A5CFF", "rail": "#120A24", "card_rim": "#FFD27A",
        "ramp": ["violet", "magenta", "hotpink", "sun"],
        "key": "#F0E6FF", "key_energy": 1.1, "fill": "#D63AF9", "ambient_energy": 0.6,
        "psm_top": "#120828", "psm_horizon": "#5A1C8A",
    },
}


def lin1(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lin(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(lin1(int(h[i : i + 2], 16) / 255.0) for i in (0, 2, 4))


def srgb1(x: float) -> float:
    x = max(0.0, x)
    return 12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055


def lum(h: str) -> float:
    r, g, b = lin(h)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio_white(h: str) -> float:
    return 1.05 / (lum(h) + 0.05)


def gcol(h: str) -> str:
    h = h.lstrip("#")
    r, g, b = (int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4))
    return f"Color({r:.3f}, {g:.3f}, {b:.3f})"


def src_for_displayed(h: str, trans: float) -> tuple:
    return tuple(round(c / trans, 3) for c in lin(h))
