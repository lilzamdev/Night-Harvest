"""Night Harvest procedural audio: gameplay SFX (.wav) and looping music (.ogg).

Run: python3 tools_dev/gen_audio.py   (needs numpy + ffmpeg)
SFX go to Assets/Audio/SFX/ where GameAudio picks them up by name automatically.
Music goes to Assets/Audio/Music/ and is played by scripts/music.gd.
"""
import os, subprocess, wave
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX = os.path.join(ROOT, "Assets/Audio/SFX")
MUS = os.path.join(ROOT, "Assets/Audio/Music")
SR = 22050
MSR = 32000
rng = np.random.default_rng(7)


def write_wav(path, x, sr=SR):
    x = np.clip(x, -1, 1)
    data = (x * 32000).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


def t_of(d, sr=SR):
    return np.arange(int(d * sr)) / sr


def env(n, a=0.005, d=0.1, sr=SR, curve=4.0):
    t = np.arange(n) / sr
    e = np.minimum(1.0, t / max(a, 1e-4)) * np.exp(-np.maximum(0, t - a) * curve / max(d, 1e-4))
    return e


def lowpass(x, k):
    if k <= 1:
        return x
    c = np.cumsum(np.insert(x, 0, 0.0))
    y = (c[k:] - c[:-k]) / k
    return np.concatenate([y, np.zeros(len(x) - len(y))])


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


# ------------------------------------------------------------------ SFX
def sfx():
    os.makedirs(SFX, exist_ok=True)
    # Sword swing: swept noise whoosh
    n = int(0.2 * SR)
    noise = rng.standard_normal(n)
    sweep = np.concatenate([lowpass(noise[i:i + 400], int(2 + 10 * (1 - i / n))) for i in range(0, n, 400)])[:n]
    e = np.sin(np.linspace(0, np.pi, n)) ** 2
    write_wav(f"{SFX}/sword_swing.wav", norm(sweep * e, 0.55))
    # Sword hit: thump + click
    t = t_of(0.14)
    x = np.sin(2 * np.pi * (140 - 300 * t) * t) * env(len(t), 0.001, 0.05) + 0.5 * rng.standard_normal(len(t)) * env(len(t), 0.0005, 0.012)
    write_wav(f"{SFX}/sword_hit.wav", norm(lowpass(x, 2), 0.8))
    # Tree chop: woody knock
    t = t_of(0.16)
    x = (np.sin(2 * np.pi * 310 * t) + 0.6 * np.sin(2 * np.pi * 523 * t) + 0.3 * np.sin(2 * np.pi * 870 * t)) * env(len(t), 0.001, 0.045)
    x += 0.4 * lowpass(rng.standard_normal(len(t)), 3) * env(len(t), 0.0005, 0.02)
    write_wav(f"{SFX}/tree_chop.wav", norm(x, 0.8))
    # Pickaxe on rock reuses a brighter knock
    t = t_of(0.14)
    x = (np.sin(2 * np.pi * 900 * t) + 0.5 * np.sin(2 * np.pi * 1400 * t)) * env(len(t), 0.0005, 0.03) + 0.3 * rng.standard_normal(len(t)) * env(len(t), 0.0005, 0.01)
    write_wav(f"{SFX}/rock_hit.wav", norm(x, 0.7))
    # Crop plant: soft dirt pat
    t = t_of(0.1)
    x = lowpass(rng.standard_normal(len(t)), 8) * env(len(t), 0.002, 0.03)
    write_wav(f"{SFX}/crop_plant.wav", norm(x, 0.6))
    # Crop harvest: pluck pop
    t = t_of(0.14)
    x = np.sin(2 * np.pi * (380 + 900 * t) * t) * env(len(t), 0.002, 0.05) + 0.25 * lowpass(rng.standard_normal(len(t)), 4) * env(len(t), 0.001, 0.02)
    write_wav(f"{SFX}/crop_harvest.wav", norm(x, 0.7))
    # Eat bite: crunchy bursts
    x = np.zeros(int(0.32 * SR))
    for k, off in enumerate([0.0, 0.11, 0.21]):
        s = int(off * SR)
        b = rng.standard_normal(int(0.06 * SR)) * env(int(0.06 * SR), 0.001, 0.02)
        x[s:s + len(b)] += lowpass(b, 3 + k)
    write_wav(f"{SFX}/eat_bite.wav", norm(x, 0.6))
    # Coin: two bright chimes
    x = np.zeros(int(0.32 * SR))
    for f, off in [(1976, 0.0), (2637, 0.07)]:
        tt = t_of(0.24)
        s = int(off * SR)
        tone = (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(4 * np.pi * f * tt)) * env(len(tt), 0.001, 0.08)
        x[s:s + len(tone)] += tone
    write_wav(f"{SFX}/coin.wav", norm(x, 0.5))
    # Build: two hammer knocks
    x = np.zeros(int(0.36 * SR))
    for off in [0.0, 0.16]:
        tt = t_of(0.12)
        s = int(off * SR)
        k = (np.sin(2 * np.pi * 220 * tt) + 0.7 * np.sin(2 * np.pi * 660 * tt)) * env(len(tt), 0.0005, 0.035)
        k += 0.4 * rng.standard_normal(len(tt)) * env(len(tt), 0.0005, 0.01)
        x[s:s + len(k)] += k
    write_wav(f"{SFX}/build.wav", norm(x, 0.75))
    # Crossbow: twang
    t = t_of(0.18)
    saw = 2 * ((t * (520 - 900 * t)) % 1.0) - 1
    x = lowpass(saw, 3) * env(len(t), 0.001, 0.05) + 0.3 * rng.standard_normal(len(t)) * env(len(t), 0.0005, 0.015)
    write_wav(f"{SFX}/bow_shot.wav", norm(x, 0.6))
    # Zombie death: falling groan + squelch
    t = t_of(0.7)
    f = 160 * np.exp(-1.6 * t)
    phase = 2 * np.pi * np.cumsum(f) / SR
    x = (np.sin(phase) + 0.5 * np.sin(2.01 * phase) + 0.25 * np.sin(3.03 * phase)) * env(len(t), 0.03, 0.35)
    x += 0.35 * lowpass(rng.standard_normal(len(t)), 6) * env(len(t), 0.01, 0.12)
    write_wav(f"{SFX}/zombie_death.wav", norm(np.tanh(2.2 * x), 0.75))
    # Door
    t = t_of(0.22)
    x = (np.sin(2 * np.pi * 95 * t) + 0.5 * np.sin(2 * np.pi * 180 * t)) * env(len(t), 0.002, 0.08) + 0.3 * lowpass(rng.standard_normal(len(t)), 10) * env(len(t), 0.001, 0.05)
    write_wav(f"{SFX}/door.wav", norm(x, 0.7))
    # Footstep: soft grass tick
    t = t_of(0.06)
    x = lowpass(rng.standard_normal(len(t)), 5) * env(len(t), 0.001, 0.015)
    write_wav(f"{SFX}/footstep.wav", norm(x, 0.35))
    # Zombie groan: reuse the title screen's groan
    src = os.path.join(ROOT, "Assets/UI/MainMenu/sfx_groan.wav")
    if os.path.exists(src):
        import shutil
        shutil.copy(src, f"{SFX}/zombie_groan.wav")


# ------------------------------------------------------------------ Music
NOTES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def hz(name):
    n, o = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTES[n] + 12 * (o + 1) - 69) / 12)


def voice(kind, f, dur, sr=MSR):
    t = np.arange(int(dur * sr)) / sr
    if kind == "square":
        x = np.sign(np.sin(2 * np.pi * f * t)) * 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * f * 1.003 * t)) * 0.5
        x = lowpass(x, 3)
        e = np.minimum(1, t / 0.01) * np.exp(-t * 2.2)
        e = np.maximum(e, 0.35 * np.minimum(1, t / 0.01)) * np.clip((dur - t) / 0.03, 0, 1)
    elif kind == "pluck":
        x = np.sin(2 * np.pi * f * t) + 0.4 * np.sin(4 * np.pi * f * t) + 0.15 * np.sin(6 * np.pi * f * t)
        e = np.minimum(1, t / 0.003) * np.exp(-t * 5.5)
    elif kind == "musicbox":
        x = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 2.76 * t) + 0.12 * np.sin(2 * np.pi * f * 5.4 * t)
        e = np.minimum(1, t / 0.002) * np.exp(-t * 3.2)
    elif kind == "tri":
        x = 2 * np.abs(2 * ((f * t) % 1.0) - 1) - 1
        e = np.minimum(1, t / 0.006) * np.clip((dur - t) / 0.02, 0, 1) * (0.7 + 0.3 * np.exp(-t * 4))
    elif kind == "pad":
        x = sum(np.sin(2 * np.pi * f * d * t + p) for d, p in [(1.0, 0), (1.004, 1.3), (0.996, 2.1), (2.0, 0.5)]) / 3.0
        x = lowpass(x, 6)
        e = np.minimum(1, t / 0.6) * np.clip((dur - t) / 0.6, 0, 1)
    elif kind == "dist":
        x = np.tanh(3.0 * (np.sign(np.sin(2 * np.pi * f * t)) * 0.6 + np.sin(2 * np.pi * f * 0.5 * t) * 0.4))
        x = lowpass(x, 4)
        e = np.minimum(1, t / 0.008) * np.exp(-t * 1.5) * np.clip((dur - t) / 0.03, 0, 1)
    else:
        x = np.sin(2 * np.pi * f * t)
        e = np.ones_like(t)
    return x * e


def drum(kind, sr=MSR):
    if kind == "kick":
        t = np.arange(int(0.25 * sr)) / sr
        return np.sin(2 * np.pi * (55 + 110 * np.exp(-t * 30)) * t) * np.exp(-t * 14)
    if kind == "heart":
        t = np.arange(int(0.2 * sr)) / sr
        return lowpass(np.sin(2 * np.pi * (45 + 40 * np.exp(-t * 25)) * t) * np.exp(-t * 18), 4)
    if kind == "snare":
        t = np.arange(int(0.16 * sr)) / sr
        return (0.6 * rng.standard_normal(len(t)) + 0.4 * np.sin(2 * np.pi * 190 * t)) * np.exp(-t * 26)
    if kind == "hat":
        t = np.arange(int(0.05 * sr)) / sr
        n = rng.standard_normal(len(t))
        return (n - lowpass(n, 3)) * np.exp(-t * 70)
    return np.zeros(1)


class Song:
    def __init__(self, bpm, bars, sr=MSR):
        self.sr = sr
        self.eighth = 60.0 / bpm / 2.0
        self.len = int(bars * 8 * self.eighth * sr)
        self.buf = np.zeros(self.len + sr * 4)

    def add(self, x, at_eighth, gain):
        s = int(at_eighth * self.eighth * self.sr)
        self.buf[s:s + len(x)] += x * gain

    def melody(self, seq, kind, gain, octave_shift=0, start=0):
        pos = start
        for tok in seq.split():
            n, d = tok.split(":")
            d = float(d)
            if n != "R":
                f = hz(n) * (2 ** octave_shift)
                self.add(voice(kind, f, d * self.eighth * 0.98, self.sr), pos, gain)
            pos += d
        return pos

    def chords(self, prog, kind, gain, per_bar=8, pattern=None, octave=4):
        for i, ch in enumerate(prog):
            notes = [hz(n + str(octave + (1 if k > 0 and NOTES[n] < NOTES[ch[0]] else 0))) for k, n in enumerate(ch)]
            base = i * per_bar
            if pattern is None:
                for f in notes:
                    self.add(voice(kind, f, per_bar * self.eighth, self.sr), base, gain / len(notes))
            else:
                for j, idx in enumerate(pattern):
                    if idx is None:
                        continue
                    self.add(voice(kind, notes[idx % len(notes)] * (2 if idx >= len(notes) else 1), self.eighth * 0.95, self.sr), base + j, gain)

    def bass(self, roots, kind, gain, pattern, octave=2):
        for i, r in enumerate(roots):
            f = hz(r + str(octave))
            for j, mult in enumerate(pattern):
                if mult:
                    self.add(voice(kind, f * mult, self.eighth * 0.9, self.sr), i * 8 + j, gain)

    def drums(self, bars, pattern, gains):
        for b in range(bars):
            for j, hits in enumerate(pattern):
                for h in hits:
                    self.add(drum(h, self.sr), b * 8 + j, gains[h])

    def render(self, path, fade=0.0):
        # Fold the tail (reverb-ish decays past the loop point) back to the start for a clean loop.
        out = self.buf[:self.len].copy()
        tail = self.buf[self.len:self.len + self.sr * 4]
        out[:len(tail)] += tail
        # Cheap room: feedback echo
        d = int(0.19 * self.sr)
        wet = np.zeros_like(out)
        for k, g in enumerate([0.22, 0.12, 0.06]):
            sh = d * (k + 1)
            wet[sh:] += out[:-sh] * g
            wet[:sh] += out[-sh:] * g
        out = norm(out + lowpass(wet, 5), 0.82)
        tmp = path + ".wav"
        write_wav(tmp, out, self.sr)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", path], check=True)
        os.remove(tmp)


DAY_PROG = [["C", "E", "G"], ["A", "C", "E"], ["F", "A", "C"], ["G", "B", "D"],
            ["C", "E", "G"], ["E", "G", "B"], ["F", "A", "C"], ["G", "B", "D"],
            ["A", "C", "E"], ["F", "A", "C"], ["C", "E", "G"], ["G", "B", "D"],
            ["F", "A", "C"], ["G", "B", "D"], ["C", "E", "G"], ["C", "E", "G"]]
DAY_MEL = ("E5:2 G5:2 C6:2 G5:2  A5:3 G5:1 E5:2 C5:2  F5:2 A5:2 G5:2 F5:2  E5:2 D5:2 G4:4 "
           "E5:2 G5:2 C6:3 D6:1  B5:2 G5:2 E5:4  A5:2 C6:2 B5:2 A5:2  G5:6 R:2 "
           "C6:2 B5:2 A5:2 E5:2  F5:2 A5:2 C6:4  G5:2 E5:2 C5:2 E5:2  D5:4 G5:4 "
           "A5:3 G5:1 F5:2 A5:2  B5:3 A5:1 G5:2 D5:2  C6:2 G5:2 E5:2 G5:2  C6:6 R:2")
NIGHT_PROG = [["A", "C", "E"], ["A", "C", "E"], ["F", "A", "C"], ["E", "G#", "B"],
              ["A", "C", "E"], ["D", "F", "A"], ["E", "G#", "B"], ["E", "G#", "B"],
              ["F", "A", "C"], ["G", "B", "D"], ["A", "C", "E"], ["A", "C", "E"],
              ["D", "F", "A"], ["E", "G#", "B"], ["A", "C", "E"], ["E", "G#", "B"]]
NIGHT_MEL = ("A4:4 C5:2 E5:2  D5:6 C5:2  A4:4 F4:4  G#4:8  A4:2 C5:2 E5:2 A5:2  F5:4 E5:2 D5:2  E5:4 G#4:4  B4:8 "
             "C5:2 A4:2 F4:4  D5:2 B4:2 G4:4  E5:4 C5:4  A4:8  F5:4 D5:4  E5:2 D5:2 B4:2 G#4:2  A4:8  R:4 E4:4")


def music():
    os.makedirs(MUS, exist_ok=True)
    # Day: bright and bouncy
    s = Song(104, 16)
    s.melody(DAY_MEL, "square", 0.22)
    s.chords(DAY_PROG, "tri", 0.10, pattern=[0, 1, 2, 3, 2, 1, 0, 2], octave=4)
    s.bass([c[0] for c in DAY_PROG], "tri", 0.30, [1, 0, 2, 0, 1, 0, 2, 1], octave=2)
    s.drums(16, [["kick"], ["hat"], ["snare"], ["hat"], ["kick"], ["hat", "kick"], ["snare"], ["hat"]],
            {"kick": 0.35, "hat": 0.10, "snare": 0.12})
    s.render(f"{MUS}/day_theme.ogg")
    # Night: tense, sparse, heartbeat
    s = Song(84, 16)
    s.melody(NIGHT_MEL, "musicbox", 0.30)
    s.chords(NIGHT_PROG, "pad", 0.26, octave=3)
    s.bass([c[0] for c in NIGHT_PROG], "tri", 0.26, [1, 0, 0, 0, 1, 0, 0, 0], octave=2)
    s.drums(16, [["heart"], ["heart"], [], [], [], [], [], []], {"heart": 0.5})
    s.render(f"{MUS}/night_theme.ogg")
    # Blood Moon: driving and loud
    s = Song(124, 16)
    s.melody(NIGHT_MEL, "dist", 0.20, octave_shift=-1)
    s.melody(NIGHT_MEL, "pluck", 0.12)
    s.chords(NIGHT_PROG, "pad", 0.22, octave=3)
    s.bass([c[0] for c in NIGHT_PROG], "square", 0.20, [1, 1, 2, 1, 1, 1, 2, 1], octave=2)
    s.drums(16, [["kick", "hat"], ["hat"], ["kick", "snare"], ["hat"], ["kick", "hat"], ["kick"], ["snare"], ["hat"]],
            {"kick": 0.45, "hat": 0.12, "snare": 0.2})
    s.render(f"{MUS}/blood_moon_theme.ogg")
    # Title: music box lullaby over a soft pad
    s = Song(72, 16)
    s.melody(NIGHT_MEL, "musicbox", 0.34)
    s.melody(NIGHT_MEL, "musicbox", 0.10, octave_shift=1, start=1)
    s.chords(NIGHT_PROG, "pad", 0.22, octave=3)
    s.render(f"{MUS}/title_theme.ogg")


if __name__ == "__main__":
    sfx()
    music()
    print("audio done")
