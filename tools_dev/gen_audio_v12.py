"""Night Harvest 1.2 procedural audio: weather, critters, mining, crafting, boss + mines music.

Run: python3 tools_dev/gen_audio_v12.py   (needs numpy + ffmpeg)
Reuses the helpers from gen_audio.py.
"""
import os, subprocess, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_audio import write_wav, t_of, env, lowpass, norm, SFX, MUS, SR, MSR, hz, voice, drum

rng = np.random.default_rng(12)


def seamless(x, fade):
    """Crossfade the tail into the head so the loop has no click."""
    n = int(fade * SR)
    head = x[:n].copy()
    tail = x[-n:]
    w = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * w + tail * (1 - w)
    return x


def main():
    os.makedirs(SFX, exist_ok=True)
    # Rain loop: filtered noise with random droplet ticks (6 s, seamless)
    n = int(6.0 * SR)
    hiss = lowpass(rng.standard_normal(n), 3) * 0.35 + lowpass(rng.standard_normal(n), 14) * 0.5
    drops = np.zeros(n)
    for _ in range(900):
        s = rng.integers(0, n - 200)
        d = rng.standard_normal(120) * env(120, 0.0003, 0.004)
        drops[s:s + 120] += d * rng.uniform(0.2, 0.7)
    write_wav(f"{SFX}/rain_loop.wav", norm(seamless(hiss + lowpass(drops, 2), 0.4), 0.45))
    # Wind loop: slow swelling low noise
    n = int(8.0 * SR)
    w = lowpass(rng.standard_normal(n), 60)
    w *= 0.6 + 0.4 * np.sin(np.linspace(0, 2 * np.pi * 2, n))
    write_wav(f"{SFX}/wind_loop.wav", norm(seamless(w, 0.6), 0.4))
    # Thunder: crack + long rumble
    t = t_of(3.2)
    rumble = lowpass(rng.standard_normal(len(t)), 90) * env(len(t), 0.08, 1.6, curve=2.2)
    crack = rng.standard_normal(len(t)) * env(len(t), 0.002, 0.08)
    write_wav(f"{SFX}/thunder.wav", norm(np.tanh(3.0 * (rumble * 2.5 + lowpass(crack, 2) * 0.6)), 0.95))
    # Bird flap: quick feathery bursts
    x = np.zeros(int(0.4 * SR))
    for k in range(5):
        s = int(k * 0.07 * SR)
        b = lowpass(rng.standard_normal(int(0.05 * SR)), 6) * env(int(0.05 * SR), 0.002, 0.02)
        x[s:s + len(b)] += b
    write_wav(f"{SFX}/bird_flap.wav", norm(x, 0.5))
    # Bird chirp
    t = t_of(0.22)
    f = 3200 + 900 * np.sin(2 * np.pi * 18 * t)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.005, 0.1)
    write_wav(f"{SFX}/bird_chirp.wav", norm(x, 0.35))
    # Water splash (fish)
    t = t_of(0.35)
    x = lowpass(rng.standard_normal(len(t)), 4) * env(len(t), 0.004, 0.09)
    x += 0.4 * np.sin(2 * np.pi * (700 - 900 * t) * t) * env(len(t), 0.002, 0.05)
    write_wav(f"{SFX}/splash.wav", norm(x, 0.55))
    # Pickaxe on ore: bright metallic ping
    t = t_of(0.3)
    x = (np.sin(2 * np.pi * 1320 * t) + 0.6 * np.sin(2 * np.pi * 1980 * t) + 0.3 * np.sin(2 * np.pi * 3100 * t)) * env(len(t), 0.0005, 0.09)
    x += 0.4 * rng.standard_normal(len(t)) * env(len(t), 0.0003, 0.008)
    write_wav(f"{SFX}/ore_hit.wav", norm(x, 0.65))
    # Rock break: crumble
    x = np.zeros(int(0.5 * SR))
    for k in range(9):
        s = int(rng.uniform(0, 0.25) * SR)
        b = lowpass(rng.standard_normal(int(0.12 * SR)), int(rng.integers(2, 8))) * env(int(0.12 * SR), 0.001, 0.04)
        x[s:s + len(b)] += b * rng.uniform(0.4, 1.0)
    t = t_of(0.5)
    x += 0.6 * np.sin(2 * np.pi * (90 - 60 * t) * t) * env(len(t), 0.002, 0.12)
    write_wav(f"{SFX}/rock_break.wav", norm(x, 0.8))
    # Gem pickup: sparkle arpeggio
    x = np.zeros(int(0.5 * SR))
    for f, off in [(1568, 0), (2093, 0.06), (2637, 0.12), (3136, 0.18)]:
        tt = t_of(0.28)
        s = int(off * SR)
        x[s:s + len(tt)] += np.sin(2 * np.pi * f * tt) * env(len(tt), 0.001, 0.09)
    write_wav(f"{SFX}/gem.wav", norm(x, 0.45))
    # Ladder / descend: wooden creaks going down
    x = np.zeros(int(0.7 * SR))
    for k, f in enumerate([520, 440, 370, 310]):
        tt = t_of(0.12)
        s = int(k * 0.14 * SR)
        x[s:s + len(tt)] += (np.sin(2 * np.pi * f * tt) + 0.4 * np.sin(2 * np.pi * f * 2.1 * tt)) * env(len(tt), 0.001, 0.04)
    write_wav(f"{SFX}/ladder.wav", norm(x, 0.6))
    # Slime: wet bloop
    t = t_of(0.25)
    f = 180 + 420 * np.exp(-t * 18)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.003, 0.08)
    write_wav(f"{SFX}/slime.wav", norm(np.tanh(2 * x), 0.6))
    # Skeleton rattle
    x = np.zeros(int(0.35 * SR))
    for k in range(7):
        s = int(k * 0.04 * SR)
        tt = t_of(0.03)
        x[s:s + len(tt)] += (np.sin(2 * np.pi * rng.uniform(1200, 2400) * tt)) * env(len(tt), 0.0005, 0.01)
    write_wav(f"{SFX}/bones.wav", norm(x, 0.5))
    # Craft: anvil clang + sparkle
    t = t_of(0.6)
    x = (np.sin(2 * np.pi * 880 * t) + 0.7 * np.sin(2 * np.pi * 1245 * t) + 0.4 * np.sin(2 * np.pi * 2210 * t)) * env(len(t), 0.0005, 0.25)
    x += 0.5 * rng.standard_normal(len(t)) * env(len(t), 0.0003, 0.01)
    write_wav(f"{SFX}/craft.wav", norm(x, 0.6))
    # Sprinkler: short spray
    t = t_of(0.5)
    x = lowpass(rng.standard_normal(len(t)), 2) * np.sin(np.linspace(0, np.pi, len(t))) ** 2
    write_wav(f"{SFX}/sprinkler.wav", norm(x, 0.3))
    # Boss roar: deep growl
    t = t_of(1.6)
    f = 70 + 30 * np.sin(2 * np.pi * 3 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = (np.sin(ph) + 0.6 * np.sin(2.02 * ph) + 0.4 * np.sin(3.1 * ph)) * env(len(t), 0.1, 0.9, curve=2.0)
    x += 0.4 * lowpass(rng.standard_normal(len(t)), 8) * env(len(t), 0.05, 0.6)
    write_wav(f"{SFX}/boss_roar.wav", norm(np.tanh(2.5 * x), 0.9))
    # Mission complete: triumphant fanfare
    x = np.zeros(int(1.0 * SR))
    for f, off, d in [(523, 0, 0.18), (659, 0.15, 0.18), (784, 0.3, 0.18), (1047, 0.45, 0.5)]:
        tt = t_of(d)
        s = int(off * SR)
        x[s:s + len(tt)] += (np.sign(np.sin(2 * np.pi * f * tt)) * 0.4 + np.sin(2 * np.pi * f * tt)) * env(len(tt), 0.003, d * 0.8)
    write_wav(f"{SFX}/mission.wav", norm(lowpass(x, 3), 0.55))
    # Whoosh dodge / heavy swing
    n = int(0.25 * SR)
    x = lowpass(rng.standard_normal(n), 5) * np.sin(np.linspace(0, np.pi, n)) ** 3
    write_wav(f"{SFX}/heavy_swing.wav", norm(x, 0.6))
    mines_music()


def mines_music():
    os.makedirs(MUS, exist_ok=True)
    bpm = 72
    beat = 60.0 / bpm
    bars = 16
    total = int(bars * 4 * beat * MSR)
    out = np.zeros(total + 3 * MSR)
    # Drone
    roots = ["A2", "A2", "F2", "G2"]
    for b in range(bars):
        f = hz(roots[(b // 4) % 4])
        s = int(b * 4 * beat * MSR)
        v = voice("pad", f, 4 * beat + 0.6) * 0.35
        out[s:s + len(v)] += v
    # Dripping echoes (music box)
    mel = ["E5", None, "C5", None, "A4", None, None, "B4", "C5", None, "E5", None, "D5", None, None, None]
    for b in range(bars):
        for i, nme in enumerate(mel):
            if nme is None or (b % 2 == 1 and i % 3 == 0):
                continue
            s = int((b * 4 + i * 0.25) * beat * MSR)
            v = voice("musicbox", hz(nme) * (0.5 if b % 4 == 3 else 1.0), 1.6) * 0.12
            out[s:s + len(v)] += v
            e = s + int(0.38 * MSR)
            out[e:e + len(v)] += v * 0.4
    # Heartbeat pulse
    for k in range(bars * 2):
        s = int(k * 2 * beat * MSR)
        d = drum("heart") * 0.25
        out[s:s + len(d)] += d
    # Wrap the tail (reverb of the last notes) back onto the start for a seamless loop
    tail = out[total:]
    out = out[:total].copy()
    out[:len(tail)] += tail
    tmp = os.path.join(MUS, "_mines.wav")
    write_wav(tmp, norm(out, 0.7), MSR)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", os.path.join(MUS, "mines_theme.ogg")], check=True)
    os.remove(tmp)


if __name__ == "__main__":
    main()
    print("ok")
