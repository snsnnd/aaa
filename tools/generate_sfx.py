#!/usr/bin/env python3
"""程序化生成战斗音效（WAV 44.1kHz 16bit 单声道）。
设计原则（game-feel skill）：
  - 打击音 = transient(噪声脉冲) + body(低频正弦衰减) + tail(金属泛音)
  - 挥砍 = 带通噪声扫频（频率下落 = 刀刃挥过的多普勒感）
  - 每种音效生成 3 个变体（pitch 微移），运行时随机采样避免重复感
"""
from __future__ import annotations
import math
import random
import struct
import wave
from pathlib import Path

SR = 44100
OUT = Path(__file__).resolve().parents[1] / "assets/game/audio/sfx"
OUT.mkdir(parents=True, exist_ok=True)
RNG = random.Random(20260829)


def hz_env(t, dur, f0, f1, curve=2.0):
    """频率扫描：f0 -> f1 按 curve 指数插值，返回瞬时频率"""
    p = t / dur
    return f0 + (f1 - f0) * (p ** (1.0 / curve))


def whoosh(dur=0.14, f0=900, f1=300, gain=0.5, variant=0):
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        p = i / n
        # 汉宁窗包络（两端归零）
        env = math.sin(math.pi * p) ** 1.5
        f = hz_env(t, dur, f0, f1)
        phase += 2 * math.pi * f / SR
        # 带通感：噪声 * 载波
        noise = RNG.uniform(-1, 1)
        v = noise * 0.4 * math.sin(phase) + noise * 0.6
        out.append(v * env * gain)
    return out


def thud(dur=0.16, f=95, gain=0.85, variant=0):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 28)
        body = math.sin(2 * math.pi * (f + variant * 4) * t) * env
        click = RNG.uniform(-1, 1) * math.exp(-t * 160) * 0.5
        out.append((body * 0.8 + click) * gain)
    return out


def ding(dur=0.42, base=660, gain=0.5, variant=0):
    """金属泛音：基频 + 非整数泛音簇（打铁声）"""
    n = int(SR * dur)
    partials = [(1.0, 1.0), (2.76, 0.5), (5.4, 0.28), (8.9, 0.15)]
    out = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for k, (ratio, amp) in enumerate(partials):
            decay = math.exp(-t * (6.0 + k * 3.5))
            v += math.sin(2 * math.pi * base * (ratio + variant * 0.01) * t) * amp * decay
        out.append(v * gain * 0.6)
    return out


def crunch(dur=0.12, gain=0.7, variant=0):
    """碎裂/纸破：密噪声簇 + 中频共振"""
    n = int(SR * dur)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 30)
        noise = RNG.uniform(-1, 1)
        lp += (noise - lp) * 0.35  # 一阶低通 → 中频共鸣感
        bursts = 1.0 if RNG.random() < 0.02 * (1 - t / dur) else 0.85
        out.append((lp * 0.7 + noise * 0.3) * env * bursts * gain)
    return out


def boom(dur=0.55, gain=0.95, variant=0):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 7)
        sub = math.sin(2 * math.pi * (52 + variant * 3) * t) * env
        growl = math.sin(2 * math.pi * 31 * t + math.sin(2 * math.pi * 7 * t) * 2.0) * env * 0.5
        noise = RNG.uniform(-1, 1) * math.exp(-t * 22) * 0.4
        out.append((sub + growl + noise) * gain)
    return out


def tick(dur=0.05, f=1200, gain=0.35, variant=0):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 90)
        out.append(math.sin(2 * math.pi * (f + variant * 60) * t) * env * gain)
    return out


def write_wav(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    norm = 0.92 / peak
    with wave.open(str(OUT / name), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(struct.pack("<h", int(max(-1, min(1, s * norm)) * 32767)) for s in samples)
        w.writeframes(frames)
    print("sfx:", name)


def variants(gen, count=3, **kwargs):
    outs = []
    for v in range(count):
        outs.append(gen(variant=v, **kwargs))
    return outs


def main():
    jobs = {
        # 挥砍（起手）：轻/重
        "sfx_swing_light.wav": variants(whoosh, dur=0.11, f0=1050, f1=380, gain=0.42),
        "sfx_swing_heavy.wav": variants(whoosh, dur=0.19, f0=620, f1=160, gain=0.55),
        # 命中分层
        "sfx_impact_light.wav": variants(crunch, dur=0.08, gain=0.5),
        "sfx_impact_medium.wav": variants(thud, dur=0.12, f=130, gain=0.7),
        "sfx_impact_heavy.wav": variants(thud, dur=0.19, f=88, gain=0.9),
        "sfx_impact_break.wav": variants(boom, dur=0.4, gain=0.85),
        "sfx_finisher.wav": variants(boom, dur=0.62, gain=1.0),
        # 反馈小件
        "sfx_cancel.wav": variants(tick, dur=0.06, f=900, gain=0.3),
        "sfx_buffer.wav": variants(tick, dur=0.045, f=1400, gain=0.22),
        # 完美防反：打铁 ding（与既有 parry.wav 叠加成两层）
        "sfx_parry_perfect.wav": variants(ding, dur=0.5, base=720, gain=0.5),
    }
    for name, gens in jobs.items():
        write_wav(name, gens[RNG.randrange(len(gens))])
        # 变体文件
        for i, samples in enumerate(gens):
            write_wav(name.replace(".wav", f"_{i}.wav"), samples)


if __name__ == "__main__":
    main()
