"""Numpy port of sky.gdshader v2 (DESIGN 11.3). Returns LINEAR rgb before the field glass.

sky(world_id, tx, ty, px_per_t) -> (H, W, 3) float32
t = view direction (x, y) / -z, the same tangent-plane coordinates as the Godot shader.
Also writes the baked nebula/mist textures (nebula_texture()).
"""

import numpy as np

import nb_worlds as W


def _c(h):
    return np.array(W.lin(h), dtype=np.float32)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def mix(a, b, f):
    return a + (b - a) * f[..., None]


def hash2(x, y):
    return np.modf(np.sin(x * 127.1 + y * 311.7) * 43758.5453)[0] % 1.0


def nebula_texture(size=512, seed=0, octaves=5):
    """Tileable fbm value noise (R = big clouds, G = fine wisps)."""
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size, 2), np.float32)
    for ch, base in ((0, 4), (1, 9)):
        acc = np.zeros((size, size), np.float32)
        amp, tot = 1.0, 0.0
        for o in range(octaves):
            n = base * 2**o
            g = rng.random((n, n)).astype(np.float32)
            xs = np.linspace(0, n, size, endpoint=False)
            i0 = np.floor(xs).astype(int)
            f = xs - i0
            f = f * f * (3 - 2 * f)
            i1 = (i0 + 1) % n
            a = g[i0][:, i0] * (1 - f)[None, :] + g[i0][:, i1] * f[None, :]
            b = g[i1][:, i0] * (1 - f)[None, :] + g[i1][:, i1] * f[None, :]
            acc += amp * (a * (1 - f)[:, None] + b * f[:, None])
            tot += amp
            amp *= 0.5
        out[..., ch] = acc / tot
    return out


_NEB = None


def _neb():
    global _NEB
    if _NEB is None:
        _NEB = nebula_texture()
    return _NEB


def sample_neb(u, v):
    n = _neb()
    s = n.shape[0]
    iu = (np.floor(u * s).astype(int)) % s
    iv = (np.floor(v * s).astype(int)) % s
    return n[iv, iu, 0], n[iv, iu, 1]


def sky(wid, tx, ty, px_per_t=1350.0):
    P = W.WORLDS[wid]
    s = P["sky"]
    e = ty / np.sqrt(1 + tx * tx + ty * ty)
    c = np.broadcast_to(_c(s["horizon"]), tx.shape + (3,)).copy()
    c = mix(c, _c(s["low"]), smoothstep(0.0, 0.06, e))
    c = mix(c, _c(s["mid"]), smoothstep(0.06, 0.22, e))
    c = mix(c, _c(s["top"]), smoothstep(0.22, 0.55, e))
    aa = 1.0 / px_per_t

    # nebula / mist from the baked 512 px texture (u, v = t * 0.6)
    nb = P["nebula"]
    if nb:
        r, g = sample_neb(tx * 0.6 + 0.37, ty * 0.6 + 0.11)
        k = smoothstep(-0.02, 0.15, ty) * nb["gain"]
        if wid == 5:
            k = k * (1 - smoothstep(0.05, 0.45, ty))  # mist hugs the floor
        c = c + (_c(nb["a"]) * smoothstep(0.40, 0.80, r)[..., None] + _c(nb["b"]) * smoothstep(0.50, 0.85, g)[..., None]) * k[..., None]

    # stars
    st = P["stars"]
    gx, gy = tx * 90.0, ty * 90.0
    cx, cy = np.floor(gx), np.floor(gy)
    h = hash2(cx, cy)
    ox = hash2(cx + 7.0, cy + 7.0) * 0.6 + 0.2
    oy = hash2(cx + 13.0, cy + 13.0) * 0.6 + 0.2
    dx, dy = gx - cx - ox, gy - cy - oy
    if st["square"]:
        sd = np.maximum(np.abs(dx), np.abs(dy))
        shape = 1.0 - smoothstep(0.07, 0.09, sd)
    else:
        sd = np.sqrt(dx * dx + dy * dy)
        shape = 1.0 - smoothstep(0.04, 0.09, sd)
    star = (h > st["density"]) * shape * smoothstep(0.10, 0.25, e)
    c = c + _c(st["col"])[None, None, :] * (star * st["gain"] * (0.5 + 0.5 * hash2(cx + 3.0, cy + 3.0)))[..., None]

    # motif
    m = P["motif"]
    hdr = 1.0 / (1.0 - W.WINDOW_ALPHA) if m["window"] else 1.0
    spx, spy = (tx - m["c"][0]) / m["r"], (ty - m["c"][1]) / m["r"]
    rr = np.sqrt(spx * spx + spy * spy)
    a_r = aa / m["r"]
    top, mid, low, rim = _c(m["top"]), _c(m["mid"]), _c(m["low"]), _c(m["rim"])
    add = np.zeros_like(c)
    cover = np.zeros(tx.shape, np.float32)
    k = m["kind"]
    if k == 1:  # sliced sun
        disc = 1.0 - smoothstep(1.0 - a_r * 1.5, 1.0, rr)
        sc = mix(np.broadcast_to(low, c.shape), np.broadcast_to(mid, c.shape), smoothstep(-0.9, 0.0, spy))
        sc = mix(sc, np.broadcast_to(top, c.shape), smoothstep(0.0, 0.8, spy))
        gap = np.clip((0.35 - spy) / 1.35, 0.0, 1.0) * 0.6
        sl = (np.modf(spy * 7.0 + 100)[0] >= gap).astype(np.float32)
        rimw = 2.5 * a_r
        rim_m = (rr > 1.0 - rimw) * (spy > 0.05) * disc
        cover = disc * sl
        add = sc * hdr
        add = mix(add, np.broadcast_to(rim * hdr, c.shape), rim_m)
        c = c + mid[None, None, :] * (0.18 * np.exp(-np.maximum(rr - 1.0, 0.0) * 6.0) * (1.0 - disc))[..., None]
    elif k == 2:  # moon with cloud bands
        disc = 1.0 - smoothstep(1.0 - a_r * 1.5, 1.0, rr)
        sc = mix(np.broadcast_to(low, c.shape), np.broadcast_to(top, c.shape), smoothstep(-0.9, 0.7, spy - 0.3 * spx))
        rim_m = (rr > 1.0 - 2.5 * a_r) * (spx < 0.2) * (spy > -0.2)
        sc = mix(sc, np.broadcast_to(rim, c.shape), rim_m * disc)
        cover = disc
        add = sc * hdr
        # two soft cloud bands drift across the moon (sky_mid, 80% cover)
        for yb, hb, x0, x1 in ((0.05, 0.07, -1.6, 0.7), (-0.42, 0.05, -0.4, 1.7)):
            band = smoothstep(hb, hb * 0.4, np.abs(spy - yb)) * smoothstep(x0, x0 + 0.3, spx) * smoothstep(x1, x1 - 0.3, spx)
            cover = np.maximum(cover * (1 - band * 0.8), band * 0.8)
            add = mix(add, np.broadcast_to(_c(s["mid"]) * 1.2, c.shape), band)
        c = c + low[None, None, :] * (0.25 * np.exp(-np.maximum(rr - 1.0, 0.0) * 2.5) * (1.0 - disc))[..., None]
    elif k == 3:  # CRT arcade screen with pixel hills and a pixel sun
        def rbox(x, y, hx, hy, rc):
            qx, qy = np.abs(x) - hx + rc, np.abs(y) - hy + rc
            return np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2) + np.minimum(np.maximum(qx, qy), 0) - rc

        d_in = rbox(spx, spy, 1.75, 1.0, 0.28)
        d_out = rbox(spx, spy, 1.95, 1.2, 0.36)
        bez = (d_out < 0) * (d_in >= 0)
        scr = (d_in < 0).astype(np.float32)
        q = 0.1
        qx, qy = np.floor(spx / q) * q, np.floor(spy / q) * q
        hill = -0.45 + 0.28 + 0.22 * np.sin(qx * 2.3 + 0.6) + 0.12 * np.sin(qx * 5.7)
        hills = (qy < hill) * scr
        sun = (np.sqrt((qx - 0.55) ** 2 + (qy - 0.25) ** 2) < 0.42) * scr * (1 - hills)
        scan = 0.82 + 0.18 * (np.modf(spy * 18 + 100)[0] > 0.5)
        col = np.broadcast_to(low, c.shape) * scan[..., None]
        col = mix(col, np.broadcast_to(mid, c.shape), hills)
        col = mix(col, np.broadcast_to(top, c.shape), sun.astype(np.float32))
        bez_col = np.broadcast_to(_c("#1A0C24"), c.shape)
        rim_m = (np.abs(d_out) < 2.0 * a_r).astype(np.float32)
        col = mix(col, bez_col, bez.astype(np.float32))
        col = mix(col, np.broadcast_to(rim, c.shape), rim_m)
        cover = np.maximum(scr, bez.astype(np.float32))
        cover = np.maximum(cover, rim_m)
        add = col * hdr
        c = c + mid[None, None, :] * (0.08 * np.exp(-np.maximum(d_out, 0) * 4.0) * (d_out > 0))[..., None]
    elif k == 4:  # crescent moon (sky band, no glass)
        d1 = rr
        d2 = np.sqrt((spx - 0.38) ** 2 + (spy - 0.22) ** 2)
        cres = (1.0 - smoothstep(1.0 - a_r * 1.5, 1.0, d1)) * smoothstep(0.92, 0.92 + a_r * 1.5, d2)
        cover = cres
        add = np.broadcast_to(top, c.shape) * np.ones_like(c)
        c = c + top[None, None, :] * (0.06 * np.exp(-np.maximum(rr - 1.0, 0.0) * 1.5))[..., None]
    elif k == 5:  # hex crystal heart
        x, y = spx, spy / 1.3
        ax, ay = np.abs(x), np.abs(y)
        d = np.maximum(ax, ax * 0.5 + ay * 0.866) / 0.866
        hexm = 1.0 - smoothstep(1.0 - a_r * 1.5, 1.0, d)
        ang = np.arctan2(y, x)
        sector = np.floor((ang + np.pi) / (np.pi / 3)).astype(int)
        shade = np.where(sector % 2 == 0, 1.0, 0.0).astype(np.float32)
        col = mix(np.broadcast_to(mid, c.shape), np.broadcast_to(top, c.shape), shade * smoothstep(-1.0, 0.6, y))
        col = mix(col, np.broadcast_to(low, c.shape), smoothstep(0.0, -1.0, y) * (1 - shade) * 0.7)
        inner = (d < 0.45).astype(np.float32)
        col = mix(col, np.broadcast_to(top, c.shape), inner * 0.8)
        aa_ang = (ang - np.pi / 2) / (np.pi / 3)
        edge_ang = np.abs(np.modf(aa_ang + 100.5)[0] - 0.5) * (np.pi / 3) * np.maximum(rr, 1e-3)
        edges = ((edge_ang < 1.6 * a_r) * (d > 0.45)) + (np.abs(d - 0.45) < 1.6 * a_r) + (d > 1.0 - 2.2 * a_r)
        col = mix(col, np.broadcast_to(rim, c.shape), np.clip(edges, 0, 1).astype(np.float32))
        cover = hexm
        add = col * hdr
        c = c + top[None, None, :] * (0.10 * np.exp(-np.maximum(d - 1.0, 0.0) * 3.0) * (1 - hexm))[..., None]
    elif k == 6:  # gate light: radial violet/magenta glow behind the 3D ring gate
        g = np.exp(-rr * rr * 1.6)
        c = c + (mid * 0.10)[None, None, :] * g[..., None] + (top * 0.12)[None, None, :] * np.exp(-rr * rr * 0.5)[..., None]

    # ridges / mountains
    rd = P["ridge"]
    if rd:
        ax = np.abs(tx)
        hill = np.maximum(ax - 0.12, 0.0) * (0.10 + 0.05 * np.sin(tx * 47.0) + 0.03 * np.sin(tx * 113.0)) * rd["height"]
        edge = np.abs(ty - hill)
        line = 1.0 - smoothstep(0.0012, 0.0012 + aa * 1.5, edge)
        under = (ty <= hill) * (ty >= 0.0)
        wgx, wgy = tx * 60.0, (ty / np.maximum(hill, 0.001)) * 3.0
        wl = np.minimum(np.abs(np.modf(wgx + 100)[0] - 0.5), np.abs(np.modf(wgy + 100)[0] - 0.5))
        wire = under * (1.0 - smoothstep(0.03, 0.08, wl)) * (1.0 if wid == 1 else 0.0)
        c = mix(c, np.broadcast_to(_c(rd["solid"]), c.shape), under * 0.85)
        c = c + _c(rd["col"])[None, None, :] * ((line * 0.9 + wire * 0.35) * rd["gain"])[..., None]

    # horizon haze band
    hz = _c(P["floor"]["haze"])
    c = c + hz[None, None, :] * (0.35 * np.exp(-np.abs(ty) * 160.0))[..., None]
    c = np.minimum(c, 0.98)
    c = mix(c, add, cover)
    return c.astype(np.float32)
