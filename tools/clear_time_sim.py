"""Rough clear-time sim for MWM Neon Bricks world 1 (design aid, not game code)."""
import math, random, statistics, sys

FL, FR, FT = 40.0, 1040.0, 280.0
PADDLE_Y = 1420.0
NET_Y = 1540.0
CELL_W, CELL_H, GRID_Y = 100.0, 52.0, 340.0
BW, BH = 92.0, 44.0
R = 22.0
MIN_VY = math.sin(math.radians(20))
MIN_VX = math.sin(math.radians(6))

LEVELS = {
 1: ["..........","..........","..........","..........",".GGGGGGGG.","..GGGGGG.."],
 2: ["..........","..........","..........",".GDDGGDDG.",".GDDGGDDG.","..GGGGGG.."],
 3: ["..........","..........","GGGGGGGGGG","GGDDGGDDGG","GGGGGGGGGG","..g....g.."],
 4: ["..........","..........","GGGGGGGGGG",".GGGGGGGG.","..........","C...CC...C","..........","..dD..Dd.."],
 5: ["..........","..........","..GGGGGG..",".GGGGGGGG.","..........",".DDDDDDDD.","..........","..GgGGgG.."],
}
HP = {"G":1,"g":1,"D":2,"d":2,"C":-1}

def run(level, speed, pw, ramp, assist_s, seed, err):
    rnd = random.Random(seed)
    bricks = {}
    for r,row in enumerate(LEVELS[level]):
        for c,ch in enumerate(row):
            if ch != ".":
                x = FL + c*CELL_W + (CELL_W-BW)/2; y = GRID_Y + r*CELL_H + (CELL_H-BH)/2
                bricks[(r,c)] = [x,y,HP[ch], ch in "gd"]
    left = sum(1 for b in bricks.values() if b[2] > 0)
    t = 3.0  # auto launch
    ang = math.radians(rnd.choice([-1,1])*rnd.uniform(10,20))
    px = 540.0
    x, y = px, PADDLE_Y - R
    sp = speed
    vx, vy = math.sin(ang)*sp, -math.cos(ang)*sp
    dt = 1/60
    comet = 0; comet_t = 0.0
    caps = []
    last_break = t; nets = 0; nudges = 0; assists = 0
    aim_next = False
    off = rnd.uniform(-0.6,0.6)*pw/2
    while left > 0 and t < 900:
        t += dt
        cur = speed*min(1+ramp*int((t-3)/15), 1+ (0.15 if ramp else 0))
        # paddle AI: track ball x with error, max 2500 px/s
        target = x - off
        px += max(-2500*dt, min(2500*dt, target-px)); px = max(FL+pw/2, min(FR-pw/2, px))
        steps = max(1, math.ceil(cur*dt/8))
        sdt = dt/steps
        n = math.hypot(vx,vy); vx, vy = vx/n*cur, vy/n*cur
        for _ in range(steps):
            for axis in (0,1):
                if axis == 0:
                    x += vx*sdt
                    if x < FL+R: x = FL+R; vx = abs(vx)
                    elif x > FR-R: x = FR-R; vx = -abs(vx)
                else:
                    y += vy*sdt
                    if y < FT+R: y = FT+R; vy = abs(vy)
                hit_solid = False
                for k,b in list(bricks.items()):
                    if x+R > b[0] and x-R < b[0]+BW and y+R > b[1] and y-R < b[1]+BH:
                        if b[2] < 0: hit_solid = True; continue
                        if comet > 0:
                            b[2] = 0
                        else:
                            b[2] -= 1; hit_solid = True
                        if b[2] <= 0:
                            if comet > 0: comet -= 1
                            if b[3]: caps.append([b[0]+BW/2, b[1]+BH])
                            del bricks[k]; left -= 1; last_break = t
                if hit_solid:
                    if axis == 0: x -= vx*sdt; vx = -vx
                    else: y -= vy*sdt; vy = -vy
            # paddle
            if vy > 0 and PADDLE_Y - 4 <= y + R <= PADDLE_Y + 24 and abs(x-px) <= pw/2 + R:
                rel = max(-1,min(1,(x-px)/(pw/2+R)))
                a = math.radians(rel*60)
                if aim_next and bricks:
                    tgt = min((b for b in bricks.values() if b[2]>0), key=lambda b: math.hypot(b[0]+BW/2-x, b[1]+BH/2-y))
                    a = math.atan2(tgt[0]+BW/2-x, -(tgt[1]+BH/2-y)); a = max(-math.radians(60), min(math.radians(60), a))
                    aim_next = False; assists += 1
                vx, vy = math.sin(a)*cur, -math.cos(a)*cur
                if abs(vx) < MIN_VX*cur: vx = math.copysign(MIN_VX*cur, vx if vx else 1); vy = -math.sqrt(cur*cur-vx*vx)
                y = PADDLE_Y - 4 - R
                off = rnd.uniform(-0.6,0.6)*pw/2
            if vy > 0 and y + R >= NET_Y:  # net (infinite in sim)
                nets += 1; y = NET_Y - R; vy = -abs(vy)
        if abs(vy) < MIN_VY*cur:
            vy = math.copysign(MIN_VY*cur, vy if vy else -1); vx = math.copysign(math.sqrt(cur*cur-vy*vy), vx if vx else 1)
        if t - last_break > assist_s: aim_next = True; last_break = t
        if comet > 0:
            comet_t -= dt
            if comet_t <= 0: comet = 0
        for cp in caps[:]:
            cp[1] += 260*dt
            if PADDLE_Y-10 <= cp[1] <= PADDLE_Y+30:
                if abs(cp[0]-px) <= pw/2 + 30: comet = 8; comet_t = 6.0; caps.remove(cp)
            elif cp[1] > NET_Y: caps.remove(cp)
    return t, nets, assists

def main():
    for name, speed, pw, ramp, assist, errs in [("Lett", 520, 400, 0.0, 15, (0, 120, 260)), ("Vanlig", 680, 280, 0.02, 30, (0, 90, 180))]:
        for lv in LEVELS:
            res = []
            for s in range(150):
                e = random.Random(1000+s).uniform(-1,1)
                res.append(run(lv, speed, pw, ramp, assist, s, 0))
            ts = [r[0] for r in res]
            print(f"{name} L{lv}: median {statistics.median(ts):.0f}s p90 {sorted(ts)[int(.9*len(ts))]:.0f}s assists/run {statistics.mean(r[2] for r in res):.1f}")
main()
