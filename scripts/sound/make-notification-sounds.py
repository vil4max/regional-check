#!/usr/bin/env python3
"""Synthesise the candidate notification sounds for Drive Check (ALERT-push).

The owner wants a sound that is very short, very calm and recognisably Drive Check's own, with no
siren and no sharp attack (2026-11-10). Each candidate is built from sine partials with a soft
attack and an exponential decay, peaks at -14 dBFS, and lasts under one second. Synthesis keeps
the result reproducible and free of licensing questions.

Usage:
  scripts/sound/make-notification-sounds.py <output-dir>   every candidate, to listen to
  scripts/sound/make-notification-sounds.py --bundle       the chosen one as the app's sound
Writes <name>.wav and, with macOS `afconvert`, <name>.caf (IMA4 in CAF, which iOS accepts for
notification sounds of under 30 seconds). `--bundle` writes RegionalCheck/Resources/drivecheck.caf,
the name the server sends as `"sound"`.
"""

import math
import shutil
import struct
import subprocess
import sys
import wave
from pathlib import Path

RATE = 44_100
PEAK_DBFS = -14.0


def note(freq, start, length, partials=((1.0, 1.0),), attack=0.035, decay=4.0):
    """One note: (multiple of freq, gain) partials, a raised-cosine attack, exponential decay."""
    return (freq, start, length, partials, attack, decay)


def render(notes, total):
    samples = [0.0] * int(total * RATE)
    for freq, start, length, partials, attack, decay in notes:
        first = int(start * RATE)
        count = int(length * RATE)
        for i in range(count):
            t = i / RATE
            env = math.exp(-decay * t)
            if t < attack:
                env *= 0.5 - 0.5 * math.cos(math.pi * t / attack)
            # A short fade at the end so no note clicks off.
            tail = length - t
            if tail < 0.02:
                env *= tail / 0.02
            value = 0.0
            for partial in partials:
                if partial[0] == "fm":
                    # Two-operator FM: a modulator at `ratio` x freq whose depth decays, the
                    # classic soft electric-piano and glass tones.
                    _, ratio, index, index_decay = partial
                    depth = index * math.exp(-index_decay * t)
                    value += math.sin(2 * math.pi * freq * t + depth * math.sin(2 * math.pi * freq * ratio * t))
                else:
                    ratio, gain = partial
                    value += gain * math.sin(2 * math.pi * freq * ratio * t)
            index = first + i
            if index < len(samples):
                samples[index] += env * value
    peak = max(abs(s) for s in samples) or 1.0
    scale = (10 ** (PEAK_DBFS / 20)) / peak
    return [s * scale for s in samples]


def write_wav(path, samples):
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))


# Soft partials: mostly fundamental, a little octave, a trace of the twelfth; a bell adds
# inharmonic partials that fade faster.
SOFT = ((1.0, 1.0), (2.0, 0.18), (3.0, 0.05))
BELL = ((1.0, 1.0), (2.76, 0.22), (5.4, 0.07))

# Car themes the owner suggested (2026-11-10), synthesised rather than sampled: a turn-signal
# relay, an on-board computer chime, a key-fob chirp. All kept soft and short.
CLICK = ((1.0, 1.0), (2.3, 0.35), (0.22, 0.6))
DING = ((1.0, 1.0), (2.0, 0.12), (4.07, 0.04))

EPIANO = (("fm", 1.0, 1.6, 6.0),)
GLASS = (("fm", 3.5, 0.9, 5.0),)
KALIMBA = ((1.0, 1.0), (5.95, 0.10), (8.4, 0.04))
MARIMBA = ((1.0, 1.0), (3.93, 0.28), (9.2, 0.06))

CANDIDATES = {
    # Soft electric piano, a major third up: warm and unhurried.
    "drivecheck-g-epiano": (
        [note(523.25, 0.00, 0.70, EPIANO, attack=0.01, decay=4.5), note(659.25, 0.13, 0.70, EPIANO, attack=0.01, decay=4.5)],
        0.86,
    ),
    # Kalimba, two plucked notes a fifth apart: wooden and friendly.
    "drivecheck-h-kalimba": (
        [note(587.33, 0.00, 0.55, KALIMBA, attack=0.004, decay=7.0), note(880.00, 0.14, 0.60, KALIMBA, attack=0.004, decay=6.0)],
        0.76,
    ),
    # Marimba, one low round note: the quietest of the set.
    "drivecheck-i-marimba": (
        [note(392.00, 0.00, 0.70, MARIMBA, attack=0.004, decay=6.5)],
        0.72,
    ),
    # A single glass ping with a slow bloom: clear but soft.
    "drivecheck-j-glass": (
        [note(987.77, 0.00, 0.85, GLASS, attack=0.012, decay=4.0)],
        0.88,
    ),
    # Turn-signal relay: two soft mechanical clicks, tick then a lower tock.
    "drivecheck-d-relay": (
        [
            note(1800.0, 0.00, 0.07, CLICK, attack=0.002, decay=60.0),
            note(1350.0, 0.36, 0.08, CLICK, attack=0.002, decay=55.0),
        ],
        0.50,
    ),
    # On-board computer: one electronic "di-ling", two close tones, round and quiet.
    "drivecheck-e-onboard": (
        [note(1046.50, 0.00, 0.22, DING, attack=0.008, decay=9.0), note(1318.51, 0.09, 0.55, DING, attack=0.008, decay=5.5)],
        0.66,
    ),
    # Key fob: two short soft chirps, the "armed" confirmation, without the sharp edge.
    "drivecheck-f-fob": (
        [note(2093.0, 0.00, 0.09, SOFT, attack=0.006, decay=22.0), note(2093.0, 0.14, 0.11, SOFT, attack=0.006, decay=18.0)],
        0.30,
    ),
    # Two gentle rising notes, a fourth apart: "here is news", not "danger".
    "drivecheck-a-two-notes": (
        [note(659.25, 0.00, 0.45, SOFT, decay=5.0), note(880.00, 0.16, 0.62, SOFT, decay=4.5)],
        0.80,
    ),
    # One soft chime with a bell timbre, low and round.
    "drivecheck-b-chime": (
        [note(784.00, 0.00, 0.90, BELL, attack=0.02, decay=4.2)],
        0.92,
    ),
    # Three quick soft notes of a major triad, falling: calm and resolved.
    "drivecheck-c-triad": (
        [
            note(783.99, 0.00, 0.30, SOFT, decay=7.0),
            note(659.25, 0.11, 0.30, SOFT, decay=7.0),
            note(523.25, 0.22, 0.50, SOFT, decay=5.0),
        ],
        0.74,
    ),
}


# The owner's pick, 2026-11-10.
CHOSEN = "drivecheck-h-kalimba"
BUNDLE_SOUND = Path(__file__).resolve().parents[2] / "RegionalCheck/Resources/drivecheck.caf"


def bundle():
    afconvert = shutil.which("afconvert") or sys.exit("afconvert (macOS) is required for --bundle")
    notes, total = CANDIDATES[CHOSEN]
    wav = BUNDLE_SOUND.with_suffix(".wav")
    write_wav(wav, render(notes, total))
    try:
        subprocess.run([afconvert, "-f", "caff", "-d", "ima4", str(wav), str(BUNDLE_SOUND)], check=True)
    finally:
        wav.unlink()
    print(f"{BUNDLE_SOUND} from {CHOSEN}, {total:.2f}s")


def main():
    if sys.argv[1:] == ["--bundle"]:
        bundle()
        return
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    afconvert = shutil.which("afconvert")
    for name, (notes, total) in CANDIDATES.items():
        wav = out / f"{name}.wav"
        write_wav(wav, render(notes, total))
        line = f"{wav} {total:.2f}s"
        if afconvert:
            caf = out / f"{name}.caf"
            subprocess.run([afconvert, "-f", "caff", "-d", "ima4", str(wav), str(caf)], check=True)
            line += f", {caf.name}"
        print(line)


if __name__ == "__main__":
    main()
