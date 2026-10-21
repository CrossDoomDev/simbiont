"""Create Symbiont's original soundtrack and sound design without external assets.

Run: python tools/generate_audio.py
Only Python's standard library is required. All synthesis is deterministic.
The long tracks and alarm use circular event placement and carry RIFF `smpl`
loop markers. The Godot importer should still explicitly enable forward looping.
"""

from __future__ import annotations

from array import array
import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import wave

RATE = 44100
TAU = math.tau
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio"


def zeros(seconds: float) -> tuple[array, array]:
    count = round(seconds * RATE)
    return array("f", [0.0]) * count, array("f", [0.0]) * count


def envelope(t: float, duration: float, attack: float, release: float) -> float:
    a = min(1.0, max(0.0, t / max(attack, 1 / RATE)))
    r = min(1.0, max(0.0, (duration - t) / max(release, 1 / RATE)))
    return math.sin(a * math.pi / 2) ** 2 * math.sin(r * math.pi / 2) ** 2


def add(target: tuple[array, array], data: array, start: float, gain=1.0,
        pan=0.0, circular=False) -> None:
    left, right = target
    offset = round(start * RATE)
    gl = math.sqrt((1 - pan) * 0.5) * gain
    gr = math.sqrt((1 + pan) * 0.5) * gain
    length = len(left)
    if circular:
        for i, sample in enumerate(data):
            j = (offset + i) % length
            left[j] += sample * gl
            right[j] += sample * gr
    else:
        for i, sample in enumerate(data):
            j = offset + i
            if 0 <= j < length:
                left[j] += sample * gl
                right[j] += sample * gr


def room(target: tuple[array, array], data: array, start: float, gain=1.0,
         pan=0.0, circular=False) -> None:
    add(target, data, start, gain, pan, circular)
    for delay, decay, side in ((0.137, .19, -.65), (.281, .13, .7),
                              (.463, .075, -.3), (.719, .045, .45)):
        add(target, data, start + delay, gain * decay, side, circular)


def pad(freq: float, duration: float, seed: int) -> array:
    rng = random.Random(seed)
    phase = rng.random() * TAU
    out = array("f")
    for i in range(round(duration * RATE)):
        t = i / RATE
        env = envelope(t, duration, 2.4, 4.2)
        v = math.sin(TAU * freq * t + .08 * math.sin(TAU * .17 * t) + phase)
        v += .36 * math.sin(TAU * freq * 2.003 * t + phase)
        v += .19 * math.sin(TAU * freq * 2.997 * t + .3)
        v += .13 * math.sin(TAU * freq * .4995 * t)
        out.append(v * env * (.86 + .14 * math.sin(TAU * .11 * t + phase)))
    return out


def pulse(freq: float, duration=.48, seed=1) -> array:
    rng = random.Random(seed)
    low = 0.0
    out = array("f")
    for i in range(round(duration * RATE)):
        t = i / RATE
        low += .18 * (rng.uniform(-1, 1) - low)
        pitch = TAU * (freq * t + 19 * .032 * (1 - math.exp(-t / .032)))
        v = math.sin(pitch) * math.exp(-t * 11)
        v += low * .09 * math.exp(-t * 38)
        out.append(v * min(1.0, t / .0025) * min(1.0, (duration - t) / .025))
    return out


def chime(freq: float, duration=1.7) -> array:
    out = array("f")
    for i in range(round(duration * RATE)):
        t = i / RATE
        v = (math.sin(TAU * freq * t) * math.exp(-t * 3.1)
             + .25 * math.sin(TAU * freq * 2.007 * t) * math.exp(-t * 5.5)
             + .065 * math.sin(TAU * freq * 4.09 * t) * math.exp(-t * 8))
        out.append(v * envelope(t, duration, .006, .25))
    return out


def texture(duration: float, seed=1, flavor="slime") -> array:
    rng = random.Random(seed)
    out = array("f")
    low = mid = phase = 0.0
    for i in range(round(duration * RATE)):
        t = i / RATE
        u = t / duration
        white = rng.uniform(-1, 1)
        low += .035 * (white - low)
        mid += .31 * (white - mid)
        env = envelope(t, duration, min(.012, duration / 8), min(.12, duration / 3))
        if flavor == "slime":
            freq = 96 + 440 * math.exp(-u * 6) + 32 * math.sin(u * 19)
            phase += TAU * freq / RATE
            v = (.46 * math.sin(phase + 1.6 * math.sin(phase * .51))
                 + .34 * low + .15 * (mid - low)) * math.exp(-u * 3.4)
        elif flavor == "infect":
            freq = 80 + 390 * u ** 1.7 + 28 * math.sin(u * 38)
            phase += TAU * freq / RATE
            bubble = .55 + .45 * math.sin(TAU * (6 * t + 11 * t * t)) ** 4
            v = (.42 * math.sin(phase + 1.9 * math.sin(phase * 1.49))
                 + .5 * low + .12 * mid) * bubble * (1 - .5 * u)
        elif flavor == "transfer":
            freq = 72 + 700 * u ** 2
            phase += TAU * freq / RATE
            v = (low * 1.7 + (mid - low) * .48 + math.sin(phase) * .16)
            v *= math.sin(math.pi * u) ** .65
        elif flavor == "hit":
            phase += TAU * (45 + 170 * math.exp(-t * 40)) / RATE
            v = (.8 * math.sin(phase) * math.exp(-t * 19)
                 + (mid - low) * .85 * math.exp(-t * 43)
                 + low * .35 * math.exp(-t * 16))
        elif flavor == "death":
            freq = 38 + 310 * (1 - u) ** 2.2
            phase += TAU * freq / RATE
            v = (.48 * math.sin(phase + 1.4 * math.sin(phase * .501))
                 + low * .8 + (mid - low) * .22) * (1 - u) ** .55
            v *= .75 + .25 * math.sin(TAU * 13 * t)
        elif flavor == "shot":
            phase += TAU * (180 + 1300 * math.exp(-t * 65)) / RATE
            v = (.55 * math.sin(phase) + .22 * math.sin(phase * 1.93)
                 + .55 * (white - mid)) * math.exp(-t * 36)
        elif flavor == "bio_shot":
            phase += TAU * (95 + 780 * math.exp(-t * 34)) / RATE
            v = (.58 * math.sin(phase + .85 * math.sin(phase * .501))
                 + .18 * math.sin(phase * 2.01) + .55 * mid) * math.exp(-t * 25)
        elif flavor == "door":
            phase += TAU * (38 + 5 * math.sin(t * 18)) / RATE
            pressure = math.sin(math.pi * u) ** .7
            v = ((mid - low) * .4 + low * .8 + .24 * math.sin(phase)
                 + .09 * math.sin(phase * 3)) * pressure
        else:
            v = .25 * low
        out.append(v * env)
    return out


def write_wav(name: str, signal: tuple[array, array], description: str,
              *, loop=False, peak=.55, role="sfx") -> dict:
    left, right = signal
    if not loop:
        # FM body resonances can leave a DC component. Remove sub-audible drift,
        # then taper the short filter tail so sounds remain click-free when cut.
        coefficient = math.exp(-TAU * 25 / RATE)
        taper = round(.025 * RATE)
        for channel in (left, right):
            previous_in = previous_out = 0.0
            for i, sample in enumerate(channel):
                value = sample - previous_in + coefficient * previous_out
                previous_in, previous_out = sample, value
                if i >= len(channel) - taper:
                    value *= math.sin((len(channel) - 1 - i) / taper * math.pi / 2) ** 2
                channel[i] = value
    max_value = max(max(abs(x) for x in left), max(abs(x) for x in right), .000001)
    gain = peak / max_value
    data = bytearray(len(left) * 4)
    power = 0.0
    dc = 0.0
    previous = [0, 0]
    seam = []
    max_step = 0
    for i in range(len(left)):
        l = round(max(-.98, min(.98, left[i] * gain)) * 32767)
        r = round(max(-.98, min(.98, right[i] * gain)) * 32767)
        struct.pack_into("<hh", data, i * 4, l, r)
        power += l * l + r * r
        dc += l + r
        if i:
            max_step = max(max_step, abs(l - previous[0]), abs(r - previous[1]))
        previous = [l, r]
    first = struct.unpack_from("<hh", data, 0)
    last = struct.unpack_from("<hh", data, len(data) - 4)
    seam = [abs(first[c] - last[c]) for c in (0, 1)]
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(data)
    if loop:
        # Standard MIDI sample loop chunk: forward loop, inclusive final frame.
        sample_header = struct.pack("<9I", 0, 0, round(1_000_000_000 / RATE),
                                    60, 0, 0, 0, 1, 0)
        sample_loop = struct.pack("<6I", 0, 0, 0, len(left) - 1, 0, 0)
        with path.open("ab") as wav:
            wav.write(b"smpl" + struct.pack("<I", 60) + sample_header + sample_loop)
        with path.open("r+b") as wav:
            wav.seek(4)
            wav.write(struct.pack("<I", path.stat().st_size - 8))
    with wave.open(str(path), "rb") as wav:
        assert wav.getnchannels() == 2 and wav.getsampwidth() == 2
        assert wav.getframerate() == RATE and wav.getnframes() == len(left)
        assert len(wav.readframes(wav.getnframes())) == len(data)
    if loop:
        assert max(seam) <= max_step, f"Unnatural seam in {name}: {seam} > {max_step}"
    item = {
        "name": name, "path": f"res://assets/audio/{name}.wav",
        "role": role, "description": description,
        "seconds": round(len(left) / RATE, 4), "sample_rate": RATE,
        "channels": 2, "bits": 16, "loop": loop,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "verification": {"complete_pcm_read": True,
                         "peak_dbfs": round(20 * math.log10(peak), 2),
                         "rms_dbfs": round(20 * math.log10(math.sqrt(power / (len(left) * 2)) / 32767), 2),
                         "dc_offset": round(dc / (len(left) * 2 * 32767), 7),
                         "boundary_jump_pcm": max(seam),
                         "max_adjacent_jump_pcm": max_step,
                         "clipped_samples": 0},
    }
    print(f"{name}: {item['seconds']}s, peak {item['verification']['peak_dbfs']} dBFS", flush=True)
    return item


def music() -> tuple[array, array]:
    # 24 bars in 4/4 at 80 BPM. Four evolving 6-bar phrases, 72 seconds.
    song = zeros(72)
    # D minor with a suspended E-flat colour and a final A drone: uneasy, quiet.
    chords = [(73.4162, 110, 174.6141), (65.4064, 98, 146.8324),
              (58.2705, 87.3071, 130.8128), (55, 82.4069, 123.4708),
              (73.4162, 110, 164.8138), (77.7817, 116.5409, 174.6141),
              (58.2705, 87.3071, 146.8324), (55, 82.4069, 130.8128)]
    for k, chord in enumerate(chords):
        for j, frequency in enumerate(chord):
            add(song, pad(frequency, 15.0, 15 + k * 3 + j), k * 9 - 2.5,
                .085 if j else .12, (-.55, .5, -.1)[j], True)
    for beat in range(96):
        time = beat * .75
        # A restrained paired heartbeat, leaving generous silence between beats.
        if beat % 4 in (0, 2):
            add(song, pulse(43.6535, seed=beat + 1), time, .20, -.06, True)
            add(song, pulse(55, .32, beat + 401), time + .165, .08, .12, True)
        if beat % 8 == 5:
            room(song, texture(.17, beat, "slime"), time + .38, .095, .6, True)
    notes = [293.6648, 349.2282, 440, 523.2511, 349.2282, 293.6648,
             261.6256, 220, 293.6648, 349.2282, 466.1638, 440,
             349.2282, 261.6256, 220, 246.9417]
    for k, note in enumerate(notes):
        room(song, chime(note, 2.6), k * 4.5 + 1.125, .026,
             -.6 if k % 2 else .6, True)
    return song


def ambient() -> tuple[array, array]:
    target = zeros(18)
    left, right = target
    rng = random.Random(7831)
    # Integer periods in an 18s cycle make every oscillator wrap continuously.
    partials = [(rng.randrange(300, 4200), rng.uniform(0, TAU), rng.uniform(.002, .008))
                for _ in range(29)]
    for i in range(len(left)):
        cycle = i / len(left)
        breath = .64 + .18 * math.sin(TAU * cycle * 3) + .12 * math.sin(TAU * cycle * 7)
        base = .19 * math.sin(TAU * 864 * cycle) + .075 * math.sin(TAU * 1728 * cycle)
        l, r = base, base
        for period, phase, amplitude in partials:
            l += amplitude * math.sin(TAU * period * cycle + phase)
            r += amplitude * math.sin(TAU * period * cycle + phase + .37)
        left[i] = l * breath
        right[i] = r * breath
    for k, time in enumerate([1.2, 4.9, 8.2, 12.8, 16.4]):
        room(target, chime(710 + k * 87, .7), time, .027,
             -.7 if k % 2 else .7, True)
        room(target, texture(.33, k + 900, "slime"), time + .12, .028, .3, True)
    return target


def hub() -> tuple[array, array]:
    # Same harmonic palette as combat, without its rhythm: the ship is breathing.
    track = zeros(72)
    for k, root in enumerate([36.7081, 32.7032, 43.6535, 36.7081]):
        for j, ratio in enumerate([1, 2, 3, 4.004]):
            add(track, pad(root * ratio, 25, 610 + k * 4 + j),
                k * 18 - 3.5, (.19, .095, .035, .021)[j],
                (-.1, .4, -.65, .6)[j], True)
    for k in range(8):
        room(track, chime(146.8324 if k % 3 else 174.6141, 3),
             5 + k * 9, .011, -.7 if k % 2 else .7, True)
    return track


def organ() -> tuple[array, array]:
    track = zeros(1.5)
    add(track, pad(55, 1.4, 736), 0, .9)
    add(track, texture(.83, 2256, "infect"), .03, .17)
    add(track, chime(110, 1.4), .045, .24)
    return track


def boss() -> tuple[array, array]:
    track = zeros(3.1)
    for k, frequency in enumerate([36.7081, 55, 77.7817]):
        add(track, pad(frequency, 2.9, 202 + k), 0, .6 - .13 * k,
            -.35 if k % 2 else .35)
    add(track, texture(1.55, 29876, "death"), .12, .27)
    add(track, pulse(36.7081, 1.0, 982), .04, .5)
    return track


def alarm() -> tuple[array, array]:
    target = zeros(1.6)
    left, right = target
    for i in range(len(left)):
        t = i / RATE
        cyc = t / 1.6
        # Integrated sinusoidal FM. Carrier is exactly 880 periods per cycle.
        phase = TAU * 880 * cyc - 40 * math.cos(TAU * 2 * cyc)
        gate = .15 + .85 * math.sin(TAU * cyc) ** 2
        v = (math.sin(phase) + .16 * math.sin(phase * 3)) * gate
        left[i] = v * (.78 + .12 * math.sin(TAU * cyc))
        right[i] = v * (.78 - .12 * math.sin(TAU * cyc))
    return target


def main(effects_only=False) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    if effects_only:
        previous = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
        manifest.extend(a for a in previous["assets"] if a["name"] in ("hub", "mission", "ambient"))
    else:
        manifest.append(write_wav("mission", music(),
        "Оригинальная 72-секундная музыка: низкие минорные подкладки, сдвоенный пульс, далёкие стеклянные обертоны; 80 BPM.",
        loop=True, peak=.38, role="music"))
        manifest.append(write_wav("hub", hub(),
        "Приглушённый эмбиент живого корабля: низкое дыхание тканей, тёмные гармоники и далёкие обертоны без речи.",
        loop=True, peak=.32, role="music"))
        manifest.append(write_wav("ambient", ambient(),
        "Низкий органический резонанс и редкие влажные капли живого корабля; бесшовный цикл без речи.",
        loop=True, peak=.28, role="ambience"))
    effects = [
        ("move", .18, "slime", .23, "Тихий мягкий шаг носителя по биологической поверхности."),
        ("slime", .34, "slime", .31, "Биологическое шевеление и мягкое хлюпанье."),
        ("shoot", .22, "bio_shot", .53, "Выстрел биоимпульсного оружия: короткий влажный импульс с низким телесным резонансом."),
        ("hit", .24, "hit", .64, "Телесный удар с коротким хрустом и низким толчком."),
        ("hurt", .32, "hit", .52, "Получение урона носителем: приглушённый плотный удар."),
        ("enemy_die", .43, "death", .41, "Короткий органический распад побеждённого врага."),
        ("death", 1.3, "death", .57, "Угасающий биологический вой и распад массы."),
        ("enemy_shot", .19, "bio_shot", .45, "Протяжный импульс враждебного излучателя."),
    ]
    for k, (name, duration, flavor, peak, description) in enumerate(effects):
        track = zeros(duration + (.26 if name == "death" else .045))
        add(track, texture(duration, 1300 + k, flavor), 0)
        manifest.append(write_wav(name, track, description, peak=peak))
    for name, notes, duration, peak, description in [
        ("pickup", [(587.3295, 0), (880, .085)], .65, .39,
         "Короткий ясный двойной сигнал получения биоматериала."),
        ("save", [(293.6648, 0), (440, .12), (587.3295, .24)], 1.25, .35,
         "Спокойное трёхнотное подтверждение контрольной точки."),
        ("upgrade", [(220, 0), (329.6276, .11), (440, .22), (659.2551, .34)], 1.35, .39,
         "Успешное улучшение симбионта: тёплое восходящее органическое созвучие."),
        ("objective", [(293.6648, 0), (440, .20), (587.3295, .40)], 1.55, .43,
         "Выполнение обязательной цели: три ясных гармонических импульса."),
        ("success", [(146.8324, 0), (220, .22), (293.6648, .44), (440, .70), (587.3295, 1.0)], 2.5, .48,
         "Возврат с успешной миссии: сдержанное минорное разрешение."),
        ("ui", [(660, 0), (990, .018)], .10, .23,
         "Короткое подтверждение кнопки без резкого щелчка."),
    ]:
        track = zeros(duration)
        for k, (note, start) in enumerate(notes):
            tail = min(duration - start, .075 if name == "ui" else .95)
            add(track, chime(note, tail), start, 1 if k == 0 else .7,
                -.15 if k % 2 else .15)
        manifest.append(write_wav(name, track, description, peak=peak))
    manifest.append(write_wav("organ", organ(),
        "Контакт с живым органом: низкий органический резонанс и мягкий влажный отклик без речи.", peak=.42))
    manifest.append(write_wav("boss", boss(),
        "Появление стража: низкое тревожное созвучие, распухающий биологический рёв и тяжёлый пульс.", peak=.55))
    manifest.append(write_wav("alarm", alarm(),
        "Плавная двухфазная тревожная сирена лаборатории; включать только при опасности.",
        loop=True, peak=.33))
    result = {
        "title": "Symbiont — original procedural soundtrack and sound design",
        "generator": "tools/generate_audio.py",
        "seed_policy": "All random generators have fixed seeds. Rebuilds are deterministic.",
        "source": "Original additive, FM and filtered-noise synthesis; no samples, external music or voice assets.",
        "format": "44100 Hz, stereo, signed 16-bit PCM WAV",
        "loop_implementation": "Circular event accumulation and RIFF smpl markers; loop_end is the frame count in Godot.",
        "godot": {
            "load": "var stream = load(\"res://assets/audio/mission.wav\").duplicate() as AudioStreamWAV",
            "loop": "stream.loop_mode = AudioStreamWAV.LOOP_FORWARD; stream.loop_begin = 0; stream.loop_end = int(stream.get_length() * stream.mix_rate)",
            "play": "AudioStreamPlayer.stream = stream; AudioStreamPlayer.play()",
            "recommended_db": {"music": -8, "ambient": -19, "sfx": -6, "alarm": -13},
            "note": "Loop hub, mission, ambient and alarm only. Stop/pause background AudioStreamPlayers when the game loses focus."
        },
        "assets": manifest,
    }
    (OUT / "manifest.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Verified {len(manifest)} original WAV files; manifest: {OUT / 'manifest.json'}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--effects-only", action="store_true",
                        help="Rebuild short sounds while retaining verified long tracks.")
    main(parser.parse_args().effects_only)
