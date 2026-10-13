#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
탄지무림 알까기 — 국악풍 소리 합성기 (배경 음악 · 징글 · 효과음)

모든 소리를 코드로 직접 합성한다. 녹음·샘플·내려받은 소리는 하나도 쓰지 않는다
(저작권 걱정 없음 — 이 파일이 곧 원본이다).

    실행:  python3 -I app/tool/make_audio.py          (저장소 맨 위에서)
    결과:  app/assets/sounds/<이름>.ogg   (Ogg Vorbis · 44100 Hz)

- 필요한 것: Python 3 + numpy, 그리고 libvorbis 가 들어간 ffmpeg.
- 씨앗(MASTER_SEED)이 고정이라 몇 번을 돌려도 같은 소리·같은 파일이 나온다
  (소리마다 이름으로 따로 씨앗을 갈라 쓰므로 순서를 바꿔도 결과가 같다).
- 배경 음악은 스테레오·끊김 없는 반복(loop), 징글은 스테레오, 효과음은 모노.
- 끝에 파일마다 길이·최대 표본(dBFS)·ffmpeg ebur128 통합 음량(LUFS)·
  반복 이음매 측정값을 표로 찍는다. (사람 귀로 들어 본 것이 아니라 숫자로 본 것이다.)

  옵션:  --only 이름1,이름2   그 소리만 다시 만든다
         --jobs N            동시에 만들 프로세스 수(기본 = CPU 수, 최대 4)
"""
import math
import os
import re
import shutil
import subprocess
import sys
import time
import zlib
from concurrent.futures import ProcessPoolExecutor

import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
OUT_DIR = os.path.join(APP, 'assets', 'sounds')
FFMPEG = shutil.which('ffmpeg') or '/usr/bin/ffmpeg'
FFPROBE = shutil.which('ffprobe') or '/usr/bin/ffprobe'
MASTER_SEED = 20261011
TAU = 2 * np.pi


def rng_for(name):
    """소리 이름마다 따로 씨앗 — 다른 소리를 고쳐도 이 소리는 그대로."""
    return np.random.default_rng([MASTER_SEED, zlib.crc32(name.encode('utf-8'))])


# ════════════════════════════════════════════════════════════════════
# 1. 기본 신호 처리 도구
# ════════════════════════════════════════════════════════════════════

def nsamp(sec):
    return int(round(sec * SR))


def tvec(n):
    return np.arange(n) / SR


def fast_len(n):
    """FFT 길이: 2·3·5 로만 이뤄진 n 이상의 가장 작은 수(numpy pocketfft 가 빠르다)."""
    best = 1 << int(math.ceil(math.log2(max(2, n))))
    p5 = 1
    while p5 < best:
        p35 = p5
        while p35 < best:
            p = p35
            while p < n:
                p *= 2
            best = min(best, p)
            p35 *= 3
        p5 *= 5
    return best


def smooth01(x):
    """0→1 부드러운 계단(smoothstep)."""
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3 - 2 * x)


def fft_conv(x, h):
    """FFT 합성곱(긴 잔향 임펄스도 한 번에)."""
    n = len(x) + len(h) - 1
    N = fast_len(n)
    return np.fft.irfft(np.fft.rfft(x, N) * np.fft.rfft(h, N), N)[:n]


# ── 2차 필터(RBJ 쿡북) 설계 ─────────────────────────────────────────
def rbj(kind, f0, q=0.707, gain_db=0.0):
    f0 = min(max(f0, 5.0), 0.47 * SR)
    w0 = TAU * f0 / SR
    cw, sw = math.cos(w0), math.sin(w0)
    al = sw / (2 * q)
    A = 10 ** (gain_db / 40)
    if kind == 'lp':
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        a = [1 + al, -2 * cw, 1 - al]
    elif kind == 'hp':
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        a = [1 + al, -2 * cw, 1 - al]
    elif kind == 'bp':  # 꼭대기 0 dB 대역 통과
        b = [al, 0.0, -al]
        a = [1 + al, -2 * cw, 1 - al]
    elif kind == 'peak':
        b = [1 + al * A, -2 * cw, 1 - al * A]
        a = [1 + al / A, -2 * cw, 1 - al / A]
    elif kind == 'hshelf':
        s = 2 * math.sqrt(A) * al
        b = [A * ((A + 1) + (A - 1) * cw + s), -2 * A * ((A - 1) + (A + 1) * cw), A * ((A + 1) + (A - 1) * cw - s)]
        a = [(A + 1) - (A - 1) * cw + s, 2 * ((A - 1) - (A + 1) * cw), (A + 1) - (A - 1) * cw - s]
    elif kind == 'lshelf':
        s = 2 * math.sqrt(A) * al
        b = [A * ((A + 1) - (A - 1) * cw + s), 2 * A * ((A - 1) - (A + 1) * cw), A * ((A + 1) - (A - 1) * cw - s)]
        a = [(A + 1) + (A - 1) * cw + s, -2 * ((A - 1) + (A + 1) * cw), (A + 1) + (A - 1) * cw - s]
    else:
        raise ValueError(kind)
    a0 = a[0]
    return np.array(b) / a0, np.array(a) / a0


def _ring_len(a):
    """극점 반지름으로 임펄스 응답이 -120 dB 까지 줄어드는 길이를 잰다."""
    r = float(np.max(np.abs(np.roots(a))))
    r = min(r, 0.999995)
    if r < 1e-6:
        return 64
    return int(min(math.log(1e-6) / math.log(r) + 64, 3 * SR))


def filt(x, *specs, tail=False, circular=False):
    """2차 필터 여러 개를 주파수 영역에서 한 번에 건다(정확한 IIR 응답을 곱함 — 벡터화).

    specs: ('lp', f, q) · ('hp', f, q) · ('bp', f, q) · ('peak', f, q, dB) · ('hshelf'/'lshelf', f, q, dB)
    x 는 (n,) 또는 (n, 채널). 응답이 사라질 만큼 뒤를 비워 두고 계산하므로 순환 겹침이 없다.
    circular=True 면 일부러 순환으로 건다 — 반복 재생 소리(루프)에 걸면 이음매에서도 연속이다.
    """
    if not specs:
        return x
    secs = [rbj(*s) for s in specs]
    P = max(_ring_len(a) for _, a in secs)
    n = len(x)
    N = n if circular else fast_len(n + P)
    z1 = np.exp(-2j * np.pi * np.arange(N // 2 + 1) / N)
    H = np.ones(N // 2 + 1, dtype=complex)
    for b, a in secs:
        H *= (b[0] + b[1] * z1 + b[2] * z1 * z1) / (a[0] + a[1] * z1 + a[2] * z1 * z1)
    if x.ndim == 2:
        H = H[:, None]
    y = np.fft.irfft(np.fft.rfft(x, N, axis=0) * H, N, axis=0)
    return y[: n + P] if tail else y[:n]


def spec_shape(x, gain_fn, circular=False):
    """주파수마다 이득을 곱한다(위상 0). circular=True 면 순환(반복 소리용, 이음매가 저절로 맞는다)."""
    n = len(x)
    N = n if circular else fast_len(2 * n)
    X = np.fft.rfft(x, N)
    f = np.fft.rfftfreq(N, 1 / SR)
    return np.fft.irfft(X * gain_fn(f), N)[:n]


def stft_filter(x, gain_fn, win=1024, hop=256):
    """시간에 따라 바뀌는 필터(쓸어 올리는 바람 소리 등): 짧은 구간마다 스펙트럼에 이득을 곱해 겹쳐 더한다."""
    n = len(x)
    R = win // hop
    nfr = int(math.ceil((n + win) / hop)) + R
    nfr += (-nfr) % R
    pad = np.zeros(nfr * hop + win)
    pad[win: win + n] = x
    w = np.hanning(win + 1)[:-1]
    idx = np.arange(nfr)[:, None] * hop + np.arange(win)[None, :]
    frames = pad[idx] * w
    X = np.fft.rfft(frames, axis=1)
    times = (np.arange(nfr) * hop + win / 2 - win) / SR
    freqs = np.fft.rfftfreq(win, 1 / SR)
    G = gain_fn(times[:, None], freqs[None, :])
    Y = np.fft.irfft(X * G, win, axis=1) * w
    out = np.zeros(len(pad))
    norm = np.zeros(len(pad))
    w2 = w * w
    for r in range(R):  # 겹치지 않는 묶음끼리 이어 붙여 한 번에 더한다
        sub = Y[r::R]
        L = sub.size
        out[r * hop: r * hop + L] += sub.reshape(-1)
        norm[r * hop: r * hop + L] += np.tile(w2, len(sub))
    out = out / np.maximum(norm, 1e-3)
    return out[win: win + n]


def white(n, r):
    return r.standard_normal(n)


def pink(n, r):
    """분홍 잡음(1/f)."""
    X = np.fft.rfft(r.standard_normal(n))
    f = np.maximum(np.fft.rfftfreq(n, 1 / SR), 20.0)
    y = np.fft.irfft(X / np.sqrt(f), n)
    return y / (np.std(y) + 1e-12)


def periodic_noise(n, r, shape_fn):
    """정확히 n 표본마다 되풀이되는 잡음(무작위 위상 스펙트럼) — 반복 재생 이음매가 없다."""
    f = np.fft.rfftfreq(n, 1 / SR)
    mag = shape_fn(f)
    ph = r.uniform(0, TAU, len(f))
    X = mag * np.exp(1j * ph)
    X[0] = 0
    y = np.fft.irfft(X, n)
    return y / (np.std(y) + 1e-12)


def phase_of(freq):
    """시간에 따라 바뀌는 주파수 → 누적 위상."""
    return TAU * np.cumsum(freq) / SR


def midi_hz(m):
    return 440.0 * 2.0 ** ((np.asarray(m) - 69.0) / 12.0)


def exp_env(n, tau, att=0.0005):
    t = tvec(n)
    e = np.exp(-t / tau)
    if att > 0:
        e *= 1 - np.exp(-t / att)
    return e


def fade(y, fin=0.0, fout=0.0):
    y = y.copy()
    if fin > 0:
        k = min(len(y), nsamp(fin))
        y[:k] *= smooth01(np.arange(k) / max(1, k))[:, None] if y.ndim == 2 else smooth01(np.arange(k) / max(1, k))
    if fout > 0:
        k = min(len(y), nsamp(fout))
        g = smooth01(1 - np.arange(k) / max(1, k))
        y[len(y) - k:] *= g[:, None] if y.ndim == 2 else g
    return y


def place(buf, sig, start):
    """버퍼의 start 표본 자리에 신호를 더한다(넘치는 끝은 자른다)."""
    if start < 0:
        sig = sig[-start:]
        start = 0
    end = min(len(buf), start + len(sig))
    if end > start:
        buf[start:end] += sig[: end - start]


def modal(n, partials, amp_att=0.0003):
    """두드림 소리의 기본: (주파수, 세기, 감쇠 시간) 진동 모드들의 합. 사인 0 위상에서 시작(딸깍 방지)."""
    t = tvec(n)
    y = np.zeros(n)
    for f, a, tau in partials:
        if f >= 0.47 * SR:
            continue
        y += a * np.exp(-t / tau) * np.sin(TAU * f * t)
    if amp_att > 0:
        y *= 1 - np.exp(-t / amp_att)
    return y


def burst(n, r, tau, *specs, amp=1.0, att=0.0002):
    """짧은 잡음 터짐(타격·마찰의 '딱'): 걸러 낸 흰 잡음 × 지수 감쇠."""
    k = min(n, nsamp(tau * 9) + 16)
    z = white(k, r)
    if specs:
        z = filt(z, *specs)
    z = z / (np.max(np.abs(z)) + 1e-12)
    y = np.zeros(n)
    y[:k] = amp * z * exp_env(k, tau, att)
    return y


def varispeed(src, ratio):
    """읽는 빠르기를 표본마다 바꿔 음높이를 움직인다(4점 Hermite 보간)."""
    pos = np.concatenate([[0.0], np.cumsum(ratio[:-1])])
    pos = np.minimum(pos, len(src) - 1.001)
    i = np.floor(pos).astype(np.int64)
    fr = pos - i
    p = np.concatenate([[0.0], src, [0.0, 0.0, 0.0]])
    xm1, x0, x1, x2 = p[i], p[i + 1], p[i + 2], p[i + 3]
    c1 = 0.5 * (x1 - xm1)
    c2 = xm1 - 2.5 * x0 + 2 * x1 - 0.5 * x2
    c3 = 0.5 * (x2 - xm1) + 1.5 * (x0 - x1)
    return ((c3 * fr + c2) * fr + c1) * fr + x0


def moving_avg(x, w, circular=False):
    """가운데 맞춘 이동 평균(누적합)."""
    w = max(1, int(w))
    if w == 1:
        return x.copy()
    h = w // 2
    if circular:
        xp = np.concatenate([x[-h - 1:], x, x[: w]])
    else:
        xp = np.concatenate([np.full(h + 1, x[0]), x, np.full(w, x[-1])])
    cs = np.concatenate([[0.0], np.cumsum(xp)])
    idx = np.arange(len(x)) + 1
    return (cs[idx + w] - cs[idx]) / w


def run_min_fwd(x, w):
    """m[i] = min(x[i .. i+w-1]) — van Herk 방식(블록 앞·뒤 누적 최솟값)으로 벡터화."""
    n = len(x)
    nb = (n + w) // w + 1
    xp = np.full(nb * w, np.inf)
    xp[:n] = x
    B = xp.reshape(nb, w)
    pre = np.minimum.accumulate(B, axis=1).ravel()
    suf = np.minimum.accumulate(B[:, ::-1], axis=1)[:, ::-1].ravel()
    return np.minimum(suf[:n], pre[w - 1: w - 1 + n])


def pan_st(y, p):
    """같은 힘 팬(-1 왼쪽 … +1 오른쪽)."""
    a = (p + 1) * np.pi / 4
    return np.stack([y * math.cos(a), y * math.sin(a)], axis=1)


# ════════════════════════════════════════════════════════════════════
# 2. 마스터 단: 잔향 · 압축 · 리미터 · 음량(LUFS)
# ════════════════════════════════════════════════════════════════════

def make_ir(r, rt60=2.2, length=None, predelay=0.02, n_er=12, er_span=0.075, hf=0.45, lf=1.15):
    """합성 잔향 임펄스(스테레오): 초기 반사 몇 개 + 대역마다 다르게 사라지는 잡음 꼬리.

    - 꼬리: 흰 잡음을 4대역(코사인 경사 교차)으로 나눠 대역마다 다른 RT60 로 지수 감쇠
      (높은 소리일수록 빨리 사라져 실제 공간처럼 따뜻해진다).
    - 왼쪽·오른쪽은 다른 잡음 → 서로 상관이 낮아 넓게 퍼진다.
    """
    length = length or rt60 * 1.25
    n = nsamp(length)
    t = tvec(n)
    f = np.fft.rfftfreq(n, 1 / SR)
    lf2 = np.log2(np.maximum(f, 1.0))

    def low_of(fc):  # fc 아래 1 → 위 0 (한 옥타브에 걸친 코사인 경사)
        x = np.clip(lf2 - math.log2(fc) + 0.5, 0, 1)
        return 0.5 * (1 + np.cos(np.pi * x))

    L1, L2, L3 = low_of(350), low_of(1500), low_of(5000)
    bands = [L1, L2 - L1, L3 - L2, 1 - L3]
    mults = [lf, 1.0, 0.72, hf]
    out = []
    pd = nsamp(predelay)
    for ch in range(2):
        X = np.fft.rfft(r.standard_normal(n))
        tail = np.zeros(n)
        for band, m in zip(bands, mults):
            tail += np.fft.irfft(X * band, n) * np.exp(-6.908 * t / (rt60 * m))
        tail *= smooth01(t / 0.035)  # 확산 꼬리는 서서히 차오른다
        tail /= np.sqrt(np.sum(tail ** 2)) + 1e-12
        ir = np.zeros(n)
        ir[pd:] = tail[: n - pd]
        er = np.zeros(n)
        for _ in range(n_er):
            d = predelay * 0.4 + r.uniform(0.003, er_span)
            k = nsamp(d)
            if k < n:
                er[k] += r.choice([-1, 1]) * r.uniform(0.35, 0.9) * math.exp(-d / 0.06)
        er = filt(er, ('lp', 7000, 0.7))
        ir += 0.5 * er / (np.sqrt(np.sum(er ** 2)) + 1e-12)
        out.append(ir / (np.sqrt(np.sum(ir ** 2)) + 1e-12))
    return np.stack(out, axis=1)


def reverb_st(send, ir):
    """모노 보내기 → 스테레오 잔향(왼·오른 임펄스가 달라 넓게)."""
    return np.stack([fft_conv(send, ir[:, 0]), fft_conv(send, ir[:, 1])], axis=1)


def compress(x, thr_db, ratio=2.0, win=0.05, smooth=0.15, circular=False):
    """부드러운 RMS 압축(믹스 버스 다듬기). 오프라인이라 가운데 맞춘 창으로 지연 없이."""
    p = np.mean(x * x, axis=1) if x.ndim == 2 else x * x
    env = moving_avg(p, nsamp(win), circular)
    db = 10 * np.log10(env + 1e-12)
    over = np.maximum(0.0, db - thr_db)
    g = moving_avg(-over * (1 - 1 / ratio), nsamp(smooth), circular)
    g = 10 ** (g / 20)
    return x * (g[:, None] if x.ndim == 2 else g)


def limiter(x, ceiling_db=-1.5, look=0.003, hold=0.04, circular=False):
    """앞을 내다보는 최대치 제한기 — 이득 = (앞뒤 창 최솟값)을 이동 평균한 것.

    m[k] = min(필요 이득 r[k-H .. k+W]), a[n] = 평균(m[n-W+1 .. n]) 이면 a[n] ≤ r[n] 이 늘 성립
    → 넘침 없이 부드럽게 눌러 준다(공격 W, 붙잡기 H). circular=True 면 반복 이음매에서도 연속.
    """
    st = x if x.ndim == 2 else x[:, None]
    peak = np.max(np.abs(st), axis=1)
    c = 10 ** (ceiling_db / 20)
    req = np.minimum(1.0, c / np.maximum(peak, 1e-12))
    W, H = max(1, nsamp(look)), nsamp(hold)
    P = W + H + 1
    if circular:
        rp = np.concatenate([req[-P:], req, req[:P]])
    else:
        rp = np.concatenate([np.ones(P), req, np.ones(P)])
    fwd = run_min_fwd(rp, W + H + 1)
    mp = np.ones_like(fwd)
    if H > 0:
        mp[H:] = fwd[:-H]
    else:
        mp = fwd
    cs = np.concatenate([[0.0], np.cumsum(mp)])
    idx = np.arange(len(req)) + P
    a = (cs[idx + 1] - cs[idx + 1 - W]) / W
    y = st * a[:, None]
    y = np.clip(y, -c, c)  # 이론상 이미 안쪽이다(안전망)
    return y if x.ndim == 2 else y[:, 0]


def lufs(x):
    """ITU-R BS.1770 통합 음량(K-가중 + 400 ms 블록 + 절대·상대 문턱)."""
    st = x if x.ndim == 2 else x[:, None]
    y = filt(st, ('hshelf', 1500.0, 1 / math.sqrt(2), 4.0), ('hp', 38.0, 0.5))
    bl, hop = nsamp(0.4), nsamp(0.1)
    if len(y) < bl:
        return -70.0
    cs = np.concatenate([np.zeros((1, y.shape[1])), np.cumsum(y * y, axis=0)])
    starts = np.arange(0, len(y) - bl + 1, hop)
    z = (cs[starts + bl] - cs[starts]) / bl
    pw = np.sum(z, axis=1)
    lk = -0.691 + 10 * np.log10(pw + 1e-15)
    g = pw[lk > -70]
    if len(g) == 0:
        return -70.0
    rel = -0.691 + 10 * np.log10(np.mean(g)) - 10
    g2 = pw[(lk > -70) & (lk > rel)]
    return float(-0.691 + 10 * np.log10(np.mean(g2)))


def master_music(x, target, ceiling, circular):
    """음악·징글 마무리: 목표 음량으로 맞춤 → 부드러운 압축 → 리미터 → 음량 다시 맞춤(몇 번 되풀이)."""
    x = filt(x, ('hp', 28.0, 0.7), circular=circular)
    x = x * 10 ** ((target - lufs(x)) / 20)
    rms = 10 * np.log10(np.mean(x * x) + 1e-12)
    x = compress(x, rms + 6.0, ratio=1.8, circular=circular)
    g = target - lufs(x)
    y = x
    for _ in range(5):
        y = limiter(x * 10 ** (g / 20), ceiling, circular=circular)
        err = target - lufs(y)
        if abs(err) < 0.08:
            break
        g += err
    return y


def master_sfx(x, peak_db, drive_db, ceiling, circular=False):
    """효과음 마무리: 꼭대기를 맞춘 뒤 drive 만큼 더 밀어 리미터로 눌러 단단하게(펀치).
    circular=True(반복 효과음)면 필터·리미터를 순환으로 걸어 이음매를 지킨다."""
    x = filt(x, ('hp', 45.0, 0.7), circular=circular)
    pk = np.max(np.abs(x)) + 1e-12
    x = x / pk * 10 ** ((peak_db + drive_db) / 20)
    y = limiter(x, min(peak_db, ceiling), look=0.0015, hold=0.02, circular=circular)
    return y


# ════════════════════════════════════════════════════════════════════
# 3. 국악기 합성
# ════════════════════════════════════════════════════════════════════

# ── 3-1. 뜯는 줄(가야금·거문고): Karplus–Strong ─────────────────────
def ks_string(f0, length, r, *, t60=2.0, s=0.2, bright=0.6, pick=0.13, cents=None):
    """Karplus–Strong 줄: 잡음으로 튕긴 뒤 지연(N 표본) + 감쇠 필터 고리를 돈다.

    - 고리 필터 y[n] = g·((1-s)·y[n-N] + s·y[n-N-1]) — s 가 클수록 높은 배음이 빨리 죽어 어두워진다.
    - y[n] 은 N 표본 전 값만 쓰므로 N 개씩 묶어 벡터로 계산한다(표본마다 도는 파이썬 고리 없음).
    - 정수 지연 때문에 생기는 음높이 오차와 농현(밀고 흔드는 음높이 변화)은
      마지막에 읽는 빠르기를 바꿔(varispeed) 맞춘다.
    """
    n_out = nsamp(length)
    N = max(8, int(SR / f0))
    f_ks = SR / (N + s)  # 고리 필터의 반 표본 지연 보정
    if cents is None:
        cents = np.zeros(n_out)
    ratio = (f0 / f_ks) * 2.0 ** (cents / 1200.0)
    n_src = int(np.sum(ratio)) + N + 8
    g = 10 ** (-3.0 / (t60 * f_ks))
    # 튕김: 밝기만큼 걸러 낸 잡음 + 뜯는 자리 빗살(pick) → 줄 가운데 성분이 비는 실제 뜯기 모양
    exc = r.uniform(-1, 1, N + 1)
    exc = filt(np.concatenate([exc, np.zeros(N)]), ('lp', 600 + 9000 * bright, 0.6))[: N + 1]
    k = max(1, int(pick * N))
    exc = exc - np.roll(exc, k)
    exc -= np.mean(exc)
    exc /= np.max(np.abs(exc)) + 1e-12
    y = np.zeros(n_src)
    y[: N + 1] = exc
    pos = N + 1
    a0, a1 = g * (1 - s), g * s
    while pos < n_src:
        m = min(N, n_src - pos)
        y[pos: pos + m] = a0 * y[pos - N: pos - N + m] + a1 * y[pos - N - 1: pos - N - 1 + m]
        pos += m
    return varispeed(y, ratio)


def pluck_cents(n, dur, orn, r, depth=1.0):
    """뜯는 악기의 시김새(음높이 꾸밈, 단위 cent).

    v / V : 농현 — 줄을 눌렀다 놓았다 하며 떠는 음(누르면 음이 올라가므로 위로만 흔든다)
    /     : 추성 — 아래 음에서 밀어 올려 제 음으로
    \\    : 퇴성 — 음 끝에서 흘려 내림
    ^     : 전성 — 살짝 꺾어 올렸다 내림
    """
    t = tvec(n)
    c = np.zeros(n)
    if 'v' in orn or 'V' in orn:
        dep = (95 if 'V' in orn else 42) * depth
        rate = r.uniform(4.6, 5.6)
        on = 0.12
        ramp = smooth01((t - on) / 0.3)
        c += dep * ramp * 0.5 * (1 - np.cos(TAU * rate * np.maximum(t - on, 0)))
    if '/' in orn:
        c += -190 * (1 - smooth01(t / 0.13))
    if '\\' in orn:
        st = max(0.08, dur - 0.28)
        c += -170 * smooth01((t - st) / 0.24)
    if '^' in orn:
        c += 120 * np.exp(-((t - 0.17) / 0.065) ** 2)
    return c


def gayageum_note(f0, dur, vel, orn, r):
    """가야금: 명주실 줄을 손가락으로 뜯는 소리.

    따뜻하고 밝은 Karplus–Strong 줄 + 손톱/살이 줄을 스치는 '틱' 잡음 + 농현.
    높은 줄일수록 빨리 사라진다.
    """
    t60 = float(np.clip(3.0 - (f0 - 150) / 330, 0.9, 3.0))
    length = min(max(dur * 1.7, 0.7), t60 * 0.9) + 0.06
    n = nsamp(length)
    c = pluck_cents(n, dur, orn, r)
    y = ks_string(f0, length, r, t60=t60, s=0.16 + 0.06 * (1 - vel),
                  bright=0.38 + 0.4 * vel, pick=0.11 + r.uniform(-0.02, 0.02), cents=c)
    y = y[:n]
    y += burst(n, r, 0.004, ('hp', 2600, 0.7), amp=0.22 * vel)
    y *= vel
    return fade(y, fout=0.06)


def geomungo_note(f0, dur, vel, orn, r):
    """거문고: 굵은 줄을 술대(대나무 막대)로 내려치는 낮고 굵은 소리.

    어두운 줄(감쇠 필터 강하게) + 괘(fret)에 스치는 거친 맛(약한 포화) + 술대가 몸통을 치는
    '딱' 하는 나무 소리(대역 잡음 + 낮은 노크)가 앞에 붙는다. 농현은 깊다.
    """
    t60 = float(np.clip(2.3 - (f0 - 70) / 250, 0.9, 2.3))
    length = min(max(dur * 1.5, 0.6), t60) + 0.06
    n = nsamp(length)
    c = pluck_cents(n, dur, orn, r, depth=1.35)
    y = ks_string(f0, length, r, t60=t60, s=0.38, bright=0.32 + 0.25 * vel, pick=0.2, cents=c)[:n]
    y = np.tanh(1.6 * y) / np.tanh(1.6)
    # 술대 소리: 나무 막대가 대모(가죽)·몸통을 때리는 '탁'
    knock = modal(n, [(175 * r.uniform(0.95, 1.05), 0.55, 0.05), (410, 0.3, 0.03), (980, 0.12, 0.015)])
    knock += burst(n, r, 0.012, ('bp', 1500, 1.2), amp=0.55)
    y = y + knock * (0.45 + 0.5 * vel)
    y *= vel
    return fade(y, fout=0.06)


# ── 3-2. 이어 부는·켜는 악기(해금·대금·태평소): 한 프레이즈를 한 번에 ─────
LEG_CFG = {
    # rate: 떠는 빠르기(Hz), depth: 기본 떨림(cent), v/V: 떠는 음 표시가 있을 때, delay: 떨림이 시작되는 시점
    'haegeum': dict(rate=5.8, depth=20, v=55, V=105, delay=0.13, glide=0.06, att=0.045, dip=0.38),
    'daegeum': dict(rate=4.5, depth=12, v=45, V=85, delay=0.24, glide=0.075, att=0.07, dip=0.5),
    'taepyeongso': dict(rate=6.4, depth=16, v=42, V=80, delay=0.1, glide=0.04, att=0.022, dip=0.32),
}


def legato_orn(tt, d, orn):
    c = np.zeros(len(tt))
    if '/' in orn:   # 추성: 아래에서 밀어 올려 들어감
        c += -150 * (1 - smooth01(tt / 0.12))
    if '\\' in orn:  # 퇴성: 음 끝에서 흘러내림
        c += -210 * smooth01((tt - max(0.05, d - 0.32)) / 0.3)
    if '^' in orn:   # 꺾는 음
        c += 130 * np.exp(-((tt - 0.15) / 0.06) ** 2)
    return c


def legato_curves(notes, cfg, r):
    """프레이즈(쉼 없이 이어진 음들) → 표본마다의 음높이(MIDI 실수)와 세기 곡선.

    음 사이는 미끄러지듯 잇고(포르타멘토), 새 음마다 활/숨을 살짝 고쳐 쥐는 세기 골을 넣는다.
    떨림(비브라토)은 음이 나오고 조금 뒤에 서서히 깊어진다 — 국악의 '농음' 느낌.
    notes: [(시작 s, 길이 s, midi, 세기, 꾸밈)] (시작은 프레이즈 기준)
    """
    end = notes[-1][0] + notes[-1][1]
    rel = 0.16
    n = nsamp(end + rel) + 1
    m = np.zeros(n)
    amp = np.zeros(n)
    cents = np.zeros(n)
    vdep = np.zeros(n)
    starts = [nsamp(nt[0]) for nt in notes]
    se = min(n, nsamp(end))
    for i, (t0, d, mid, vel, orn) in enumerate(notes):
        s0 = starts[i]
        s1 = starts[i + 1] if i + 1 < len(notes) else se
        k = s1 - s0
        if k <= 0:
            continue
        tt = np.arange(k) / SR
        seg = np.full(k, float(mid))
        if i > 0:
            g = min(nsamp(cfg['glide']), k)
            prev = notes[i - 1][2]
            seg[:g] = prev + (mid - prev) * smooth01(np.arange(g) / max(1, g))
        m[s0:s1] = seg
        a = vel * (0.88 + 0.12 * np.sin(np.pi * np.clip(tt / max(d, 0.12), 0, 1)))
        if i == 0:
            a *= 1 - np.exp(-tt / cfg['att'])
        else:
            a *= 1 - cfg['dip'] * np.exp(-((tt - 0.012) / 0.028) ** 2)
        amp[s0:s1] = a
        cents[s0:s1] = legato_orn(tt, d, orn)
        dep = cfg['V'] if 'V' in orn else cfg['v'] if 'v' in orn else cfg['depth']
        vdep[s0:s1] = dep * smooth01((tt - cfg['delay']) / 0.35)
    # 마지막 음 뒤: 음높이·떨림은 그대로, 세기만 부드럽게 사라짐
    last = max(se - 1, 0)
    m[se:] = m[last]
    cents[se:] = cents[last]
    vdep[se:] = vdep[last]
    kk = n - se
    amp[se:] = amp[last] * smooth01(1 - np.arange(kk) / max(1, kk))
    amp = moving_avg(amp, nsamp(0.004))
    rate = cfg['rate'] * (1 + 0.04 * np.sin(TAU * 0.37 * tvec(n) + r.uniform(0, TAU)))
    vib = vdep * np.sin(phase_of(rate) + r.uniform(0, TAU))
    return m + (cents + vib) / 100.0, np.maximum(amp, 0.0)


def band_saw(ph, f, rolloff=1.0, maxf=17000.0, kmax=60):
    """대역 제한 톱니파(배음 합) — 나이퀴스트를 넘는 배음은 부드럽게 뺀다(앨리어싱 없음)."""
    y = np.zeros(len(ph))
    fmin = float(np.min(f))
    for k in range(1, kmax + 1):
        if k * fmin > maxf + 1500:
            break
        g = np.clip((maxf + 1500 - k * f) / 1500.0, 0, 1)
        y += g * np.sin(k * ph) / k ** rolloff
    return y


def haegeum_synth(m, amp, r):
    """해금: 두 줄 사이에 낀 말총 활로 켜는 찰현악기.

    활이 줄을 끌고 놓는 헬름홀츠 운동 = 톱니파 + 송진 긁는 활 잡음(음 주기에 맞춰 흔들림)
    + 콧소리 같은 공명(약 0.95 · 2.4 · 3.6 kHz 공진 필터)과 얇은 저음(울림통이 작다).
    """
    f = midi_hz(m)
    ph = phase_of(f)
    y = band_saw(ph, f, rolloff=0.95)
    nz = filt(white(len(m), r), ('bp', 2800, 0.6)) * (0.55 + 0.45 * np.cos(ph))
    nz /= np.std(nz) + 1e-12
    y = y / (np.std(y) + 1e-12)
    y = (y + 0.16 * nz) * amp
    y = filt(y, ('hp', 230, 0.7), ('peak', 950, 2.4, 9), ('peak', 2400, 3.0, 6),
             ('peak', 3600, 4.0, 3), ('lp', 7800, 0.7))
    return y


def daegeum_synth(m, amp, r):
    """대금: 굵은 대나무 가로 피리. 숨이 많이 섞인 둥근 소리와 '청' 울림.

    사인 기본음 + 2·3·4배음, 거기에 숨소리(넓은 대역 잡음 + 음 주기에 묶인 잡음),
    소리를 낼 때 '푸' 하는 숨 첫머리(세기가 오를 때 잡음을 더),
    그리고 대금만의 갈대청(청공에 붙인 얇은 막)이 떨며 내는 지잉— 하는 높은 배음 버즈:
    세고 높은 음일수록 강하게(세기²·음높이에 비례).
    """
    n = len(m)
    f = midi_hz(m)
    ph = phase_of(f)
    tone = np.sin(ph) + 0.24 * np.sin(2 * ph + 0.4) + 0.1 * np.sin(3 * ph + 1.1) + 0.035 * np.sin(4 * ph)
    breath = filt(white(n, r), ('hp', 1300, 0.6), ('lp', 7500, 0.6))
    breath /= np.std(breath) + 1e-12
    pbreath = filt(white(n, r), ('lp', 3000, 0.6)) * (0.5 + 0.5 * np.cos(ph))
    pbreath /= np.std(pbreath) + 1e-12
    rise = np.maximum(np.gradient(amp) * SR, 0)
    chiff = np.clip(moving_avg(rise, nsamp(0.02)) / 12.0, 0, 1)
    # 청 울림: 소리를 세게 일그러뜨려 생긴 홀수 배음을 3 kHz 둘레로만 남기고 거칠게 흔든다
    buzz = filt(np.tanh(5 * tone), ('bp', 3300, 0.9))
    flutter = 1 + 0.35 * filt(white(n, r), ('lp', 160, 0.7)) / 0.1
    buzz = buzz / (np.std(buzz) + 1e-12) * np.clip(flutter, 0.2, 2.0)
    bz = 0.15 * amp ** 2 * smooth01((f - 380) / 500)
    y = tone * amp + (0.06 * amp + 0.25 * chiff * amp) * breath + 0.06 * amp * pbreath + bz * buzz
    return filt(y, ('hp', 140, 0.7), ('peak', 650, 1.0, -1.5), ('lp', 9000, 0.7))


def taepyeongso_synth(m, amp, r):
    """태평소(날라리): 겹서(두 겹 갈대 혀)로 부는 아주 크고 쨍한 소리.

    배음이 천천히 줄어드는(1/k^0.55) 밝은 파형 → tanh 포화로 리드 떨림의 거친 맛
    → 나팔(동팔랑) 공명 세 개(1.1 · 2.7 · 4 kHz). 숨·혀 잡음 조금.
    """
    f = midi_hz(m)
    ph = phase_of(f)
    y = band_saw(ph, f, rolloff=0.55, maxf=12000, kmax=40)
    y = y / (np.std(y) + 1e-12)
    y = np.tanh(1.5 * y * amp) / np.tanh(1.5)
    nz = filt(white(len(m), r), ('bp', 2200, 0.7)) * amp * 0.05 / 0.15
    y = y + nz
    return filt(y, ('hp', 320, 0.7), ('peak', 1100, 1.2, 6), ('peak', 2700, 2.0, 5),
                ('peak', 4000, 3.0, 3), ('lp', 9500, 0.7))


LEG_SYNTH = {'haegeum': haegeum_synth, 'daegeum': daegeum_synth, 'taepyeongso': taepyeongso_synth}


def render_phrase(inst, notes, r):
    m, amp = legato_curves(notes, LEG_CFG[inst], r)
    return LEG_SYNTH[inst](m, amp, r)


# ── 3-3. 타악기 ────────────────────────────────────────────────────
def janggu_kung(r, vel=1.0):
    """장구 궁편(왼쪽 넓은 가죽) '쿵': 쳤을 때 팽팽했다 풀리며 내려앉는 둥근 저음 + 가죽 '퍽'."""
    n = nsamp(0.6)
    t = tvec(n)
    f = 108 * r.uniform(0.97, 1.03) + 80 * np.exp(-t / 0.045)
    ph = phase_of(f)
    y = np.sin(ph) * np.exp(-t / 0.27) + 0.32 * np.sin(1.59 * ph) * np.exp(-t / 0.11)
    y += 0.12 * np.sin(2.4 * ph) * np.exp(-t / 0.06)
    y *= 1 - np.exp(-t / 0.0012)
    y += burst(n, r, 0.022, ('lp', 750, 0.7), amp=0.45)
    return y * vel


def janggu_deok(r, vel=1.0):
    """장구 채편(오른쪽 얇은 가죽) '덕': 열채(대나무 채)로 치는 날카롭고 짧은 소리."""
    n = nsamp(0.32)
    t = tvec(n)
    f0 = 430 * r.uniform(0.97, 1.04)
    f = f0 * (1 + 0.12 * np.exp(-t / 0.01))
    ph = phase_of(f)
    y = np.sin(ph) * np.exp(-t / 0.065) + 0.5 * np.sin(1.6 * ph) * np.exp(-t / 0.04)
    y += 0.3 * np.sin(2.33 * ph) * np.exp(-t / 0.025)
    y *= 1 - np.exp(-t / 0.0006)
    br = 0.6 + 0.4 * vel
    y += burst(n, r, 0.011, ('bp', 3600, 0.8), amp=0.95 * br)
    y += burst(n, r, 0.0015, ('hp', 6000, 0.7), amp=0.55 * br)
    y += modal(n, [(2150 * r.uniform(0.97, 1.03), 0.18, 0.02)])
    return y * vel


def janggu(kind, r, vel):
    if kind == 'kung':
        return janggu_kung(r, vel)
    if kind == 'deok':
        return janggu_deok(r, vel)
    if kind == 'deong':  # 덩 = 궁편 + 채편 함께(합장단)
        a = janggu_kung(r, vel)
        b = janggu_deok(r, vel * 0.85)
        y = np.zeros(max(len(a), len(b)))
        y[: len(a)] += a
        y[: len(b)] += b
        return y
    if kind == 'giduk':  # 기덕: 앞 꾸밈(약하게) + 덕 — 열채가 튕기듯 두 번
        y = np.zeros(nsamp(0.4))
        place(y, janggu_deok(r, vel * 0.5), 0)
        place(y, janggu_deok(r, vel), nsamp(0.042))
        return y
    if kind == 'roll':  # 더러러: 열채를 굴리는 잔 소리
        y = np.zeros(nsamp(0.5))
        for i in range(6):
            place(y, janggu_deok(r, vel * (0.32 + 0.1 * i)), nsamp(i * 0.032))
        return y
    raise ValueError(kind)


def buk(r, vel=1.0):
    """북: 큰 통에 두 가죽 — 깊게 '둥' 하고 내려앉는 저음 + 북채가 가죽을 치는 소리."""
    n = nsamp(1.3)
    t = tvec(n)
    f = 72 * r.uniform(0.97, 1.03) + 42 * np.exp(-t / 0.06)
    ph = phase_of(f)
    y = np.sin(ph) * np.exp(-t / 0.38) + 0.35 * np.sin(1.52 * ph) * np.exp(-t / 0.18)
    y += 0.15 * np.sin(2.31 * ph) * np.exp(-t / 0.09)
    y *= 1 - np.exp(-t / 0.002)
    y += burst(n, r, 0.04, ('lp', 420, 0.7), amp=0.55)
    y += burst(n, r, 0.005, ('bp', 2000, 1.0), amp=0.25 * vel)
    return y * vel


def gong_partials(r, f0, n, parts, glide=0.025, glide_t=0.35, att=0.012):
    """쇠(징·꽹과리) 공통: 비조화 배음들의 합. 짝지은 배음은 몇 Hz 어긋나 맥놀이(웅웅)를 만든다.
    징은 친 직후 음이 살짝 높았다가 내려앉는다(glide)."""
    t = tvec(n)
    g = 1 + glide * np.exp(-t / glide_t)
    y = np.zeros(n)
    for ratio, a, tau in parts:
        if f0 * ratio > 0.45 * SR:
            continue
        y += a * np.exp(-t / tau) * np.sin(phase_of(f0 * ratio * g) + r.uniform(0, TAU))
    return y * (1 - np.exp(-t / att))


def jing(r, vel=1.0, f0=150.0, length=6.0):
    """징: 큰 놋쇠 징을 솜방망이 채로 — 낮고 길게 '지이잉~' 맥놀이하며 울린다."""
    n = nsamp(length)
    parts = [(1.0, 1.0, 4.6), (1.009, 0.8, 4.2), (2.03, 0.5, 3.1), (2.05, 0.34, 2.8), (2.97, 0.3, 2.1),
             (2.99, 0.2, 2.0), (3.92, 0.22, 1.5), (4.95, 0.14, 1.0), (6.1, 0.1, 0.7), (7.4, 0.06, 0.5)]
    y = gong_partials(r, f0 * r.uniform(0.99, 1.01), n, parts, glide=0.03, att=0.014)
    y += burst(n, r, 0.05, ('lp', 220, 0.7), amp=0.35)  # 솜방망이 '퉁'
    return y * vel


def kkwaeng(r, vel=1.0, damped=False):
    """꽹과리: 작은 놋쇠 쇠를 나무채로 — 쨍하고 날카로운 비조화 배음.
    damped=True 면 왼손으로 막아 짧게 '깻'(막음 소리)."""
    n = nsamp(0.18 if damped else 0.9)
    f0 = 820 * r.uniform(0.985, 1.015)
    ratios = [1.0, 1.47, 1.98, 2.61, 3.22, 3.95, 4.67, 5.5, 6.4, 7.6, 8.7, 10.1]
    amps = [0.45, 0.7, 0.9, 1.0, 1.0, 0.95, 0.85, 0.7, 0.55, 0.45, 0.32, 0.22]  # 2~6 kHz 가 쨍하게
    taus = [0.55, 0.5, 0.45, 0.4, 0.35, 0.3, 0.26, 0.22, 0.18, 0.14, 0.11, 0.09]
    sc = 0.1 if damped else 1.0
    parts = []
    for q, a, tau in zip(ratios, amps, taus):
        parts.append((q, a, tau * sc))
        parts.append((q * 1.0045, a * 0.6, tau * sc * 0.9))
    y = gong_partials(r, f0, n, parts, glide=0.0, att=0.0006)
    y = y / (np.max(np.abs(y)) + 1e-12)
    y = np.tanh(1.6 * y)
    y += burst(n, r, 0.003, ('hp', 4000, 0.7), amp=0.5)
    if damped:
        y += burst(n, r, 0.012, ('bp', 2500, 1.0), amp=0.3)
    return y * vel


def perc(kind, r, vel):
    if kind in ('kung', 'deok', 'deong', 'giduk', 'roll'):
        return janggu(kind, r, vel)
    if kind == 'buk':
        return buk(r, vel)
    if kind == 'jing':
        return jing(r, vel)
    if kind == 'kkwaeng':
        return kkwaeng(r, vel)
    if kind == 'kkwaeng_d':
        return kkwaeng(r, vel, damped=True)
    raise ValueError(kind)


PERC_STEM = {'kung': 'janggu', 'deok': 'janggu', 'deong': 'janggu', 'giduk': 'janggu', 'roll': 'janggu',
             'buk': 'buk', 'jing': 'jing', 'kkwaeng': 'kkwaeng', 'kkwaeng_d': 'kkwaeng'}


# ════════════════════════════════════════════════════════════════════
# 4. 악보 → 소리 (장단·선법·프레이즈)
# ════════════════════════════════════════════════════════════════════

# 오음 음계(반음 수). 평조: 솔 라 도 레 미 / 계면조: 라 도 레 미 솔
MODES = {'pyeong': [0, 2, 5, 7, 9], 'gyemyeon': [0, 3, 5, 7, 10]}

# 장단(한 바퀴의 단위 수, [(위치, 소리, 세기)]). 덩=쿵+덕, 기덕=꾸밈 덕, 더러러=굴림
JANGDAN = {
    'semachi': (9, [(0, 'deong', 1.0), (3, 'deong', 0.75), (5, 'deok', 0.7), (6, 'kung', 0.8), (7, 'deok', 0.7)]),
    'jajin': (12, [(0, 'deong', 1.0), (3, 'kung', 0.75), (5, 'deok', 0.75), (7, 'kung', 0.75), (9, 'deok', 0.8)]),
    'hwimori': (8, [(0, 'deong', 1.0), (2, 'deok', 0.7), (4, 'kung', 0.85), (6, 'deok', 0.7)]),
    'jungmori': (24, [(0, 'deong', 1.0), (4, 'kung', 0.7), (6, 'deok', 0.6), (8, 'kung', 0.7),
                      (12, 'kung', 0.75), (16, 'deok', 0.6), (18, 'deok', 0.55), (20, 'kung', 0.7)]),
    'jinyang': (12, [(0, 'deong', 1.0), (4, 'kung', 0.6), (6, 'deok', 0.6), (9, 'kung', 0.65), (10, 'giduk', 0.6)]),
}
FILLS = {
    'semachi': [(0, 'deong', 1.0), (3, 'kung', 0.8), (5, 'giduk', 0.8), (6, 'deok', 0.8), (7, 'roll', 0.75)],
    'jajin': [(0, 'deong', 1.0), (3, 'kung', 0.8), (5, 'deok', 0.8), (6, 'giduk', 0.8), (8, 'deok', 0.7),
              (9, 'kung', 0.85), (10, 'roll', 0.8)],
    'hwimori': [(0, 'deong', 1.0), (2, 'giduk', 0.8), (4, 'deong', 0.9), (5, 'deok', 0.7), (6, 'roll', 0.85)],
    'jungmori': [(0, 'deong', 1.0), (4, 'kung', 0.7), (6, 'deok', 0.6), (8, 'kung', 0.7), (12, 'kung', 0.75),
                 (16, 'giduk', 0.65), (18, 'deok', 0.6), (20, 'kung', 0.7), (22, 'roll', 0.6)],
    'jinyang': [(0, 'deong', 1.0), (4, 'kung', 0.6), (6, 'giduk', 0.65), (8, 'deok', 0.6), (9, 'kung', 0.7),
                (10, 'roll', 0.7)],
}

TOK = re.compile(r'^(r|-?\d+(?:\+-?\d+)*):(\d+(?:\.\d+)?)([vV/\\^>.]*)$')

# 악기 기본 섞음값: 소리 종류 · 좌우 · 목표 음량(lu: 줄기마다 문턱 음량을 이 값에 맞춤 — 귀 대신 숫자로
# 악기 사이 균형을 잡는다) · 잔향 보내기 · 다듬는 필터. 곡마다 Song.mix 로 덮어쓴다.
INST = {
    'gayageum': dict(kind='pluck', pan=-0.32, lu=-2.0, send=0.32,
                     eq=[('peak', 230, 1.2, 2.5), ('hshelf', 3500, 0.7, 2.0)]),
    'gayageum2': dict(kind='pluck', pan=0.36, lu=-10.0, send=0.3,
                      eq=[('peak', 230, 1.2, 2.0), ('hshelf', 3500, 0.7, 1.0)]),
    'geomungo': dict(kind='pluck', pan=0.18, lu=-7.0, send=0.28, eq=[('lshelf', 160, 0.7, 2.0)]),
    'haegeum': dict(kind='legato', pan=0.14, lu=0.0, send=0.3, eq=[]),
    'daegeum': dict(kind='legato', pan=-0.08, lu=0.0, send=0.36, eq=[]),
    'taepyeongso': dict(kind='legato', pan=0.24, lu=-3.0, send=0.26, eq=[]),
    'janggu': dict(kind='perc', pan=0.08, lu=-7.0, send=0.16, eq=[]),
    'buk': dict(kind='perc', pan=-0.06, lu=-9.0, send=0.18, eq=[('hp', 48, 0.7), ('peak', 1800, 1.0, 2.0)]),
    'kkwaeng': dict(kind='perc', pan=0.4, lu=-10.0, send=0.15, eq=[('lp', 12000, 0.7)]),
    'jing': dict(kind='perc', pan=-0.22, lu=-9.0, send=0.25, eq=[]),
}
PLUCK_FN = {'gayageum': gayageum_note, 'gayageum2': gayageum_note, 'geomungo': geomungo_note}


class Song:
    """곡 하나: 단위(박의 쪼갬) 길이 · 장단 한 바퀴의 단위 수 · 몇 바퀴 · 선법 · 으뜸음.

    play('악기', 단위위치, '도:길이꾸밈 ...') 로 음을 적는다. 음은 선법 안의 차례(0=으뜸음,
    5=한 옥타브 위, -1=아래 한 칸)로 적고, 꾸밈표 v V / \\ ^ 는 시김새, '>'는 세게, '.'는 짧게.
    'a+b:2' 는 두 줄을 함께(쌍현).
    """

    def __init__(self, name, unit, cycle, n_cycles, mode, root, loop=True, length=None):
        self.name = name
        self.unit = unit
        self.cycle = cycle
        self.n_cycles = n_cycles
        self.scale = MODES[mode]
        self.root = root
        self.loop = loop
        self.L = length if length is not None else unit * cycle * n_cycles
        self.ev = []
        self.hits = []
        self.r = rng_for(name)
        self.mix = {}
        self.ambient = None
        self.wet = 1.0
        self.rt60 = 2.3
        self.eq = []  # 곡 전체에 거는 다듬기 필터(반복 곡이면 순환으로)

    def cyc(self, c):
        return c * self.cycle

    def midi(self, d):
        o, i = divmod(d, 5)
        return self.root + 12 * o + self.scale[i]

    def play(self, inst, u, text, shift=0, octave=0, vel=0.8):
        for tok in text.split():
            if tok == '|':
                continue
            mt = TOK.match(tok)
            if not mt:
                raise ValueError(f'{self.name}: 악보 토큰 오류 {tok!r}')
            degs, dur, orn = mt.group(1), float(mt.group(2)), mt.group(3)
            if degs != 'r':
                for j, ds in enumerate(degs.split('+')):
                    mid = self.midi(int(ds) + shift) + 12 * octave
                    v = vel * (1.18 if '>' in orn else 1.0) * (1 + self.r.normal(0, 0.05)) * (0.8 if j else 1.0)
                    de = dur * (0.45 if '.' in orn else 1.0)
                    self.ev.append((inst, u * self.unit, de * self.unit, mid, float(np.clip(v, 0.05, 1.2)), orn))
            u += dur
        return u

    def hit(self, kind, u, vel=0.8):
        self.hits.append((kind, u * self.unit, vel))

    def jangdan(self, name, c0, c1, vel=0.7, fill_every=4, skip=()):
        _, pat = JANGDAN[name]
        for c in range(c0, c1):
            use = FILLS[name] if fill_every and (c - c0) % fill_every == fill_every - 1 else pat
            for u, k, v in use:
                if u in skip and use is pat:
                    continue
                self.hit(k, self.cyc(c) + u, vel * v)

    def arp(self, inst, c, root, pat, octave=0, vel=0.45, step=1.0):
        """반주 가락: 한 바퀴 동안 root 기준 차례 pat 를 한 단위씩 뜯는다(None 은 쉼)."""
        u = self.cyc(c)
        toks = []
        for d in pat:
            toks.append('r:%g' % step if d is None else '%d:%g' % (root + d, step))
        self.play(inst, u, ' '.join(toks), octave=octave, vel=vel)


def hetero(text):
    """시나위식 헤테로포니: 같은 가락을 다른 악기가 잔가락을 넣어 따라간다(긴 음을 쪼개 윗음으로 꾸밈)."""
    out = []
    for tok in text.split():
        mt = TOK.match(tok)
        if not mt or mt.group(1) == 'r' or '+' in mt.group(1):
            out.append(tok)
            continue
        d, dur, orn = int(mt.group(1)), float(mt.group(2)), mt.group(3)
        if dur >= 3:
            out += ['%d:%g%s' % (d, dur - 1.5, orn.replace('\\', '')), '%d:0.5' % (d + 1), '%d:1%s' % (d, '\\' if '\\' in orn else '')]
        elif dur == 2:
            out += ['%d:1.5%s' % (d, orn), '%d:0.5' % (d + 1)]
        else:
            out.append(tok)
    return ' '.join(out)


def render_song(song):
    """악보를 소리로: 악기별 줄기(stem)에 그린 뒤 섞고, 홀 잔향을 더하고,
    반복 곡이면 끝을 넘친 꼬리(울림·잔향)를 맨 앞에 겹쳐 이음매를 없앤다."""
    r = song.r
    tail = 7.0 if song.loop else 0.0
    L = nsamp(song.L)
    n = L + nsamp(tail)
    stems = {}

    def stem(name):
        if name not in stems:
            stems[name] = np.zeros(n)
        return stems[name]

    def at(tsec):
        s = nsamp(tsec)
        return s % L if song.loop else s

    # 뜯는 악기: 음마다
    for inst, t0, d, mid, vel, orn in song.ev:
        if INST[inst]['kind'] != 'pluck':
            continue
        sig = PLUCK_FN[inst](float(midi_hz(mid)), d, vel, orn, r)
        jit = float(np.clip(r.normal(0, 0.005), -0.012, 0.012))
        place(stem(inst), sig, at(t0 + jit))
    # 이어 부는 악기: 쉼 없이 이어진 음들을 한 프레이즈로
    for inst in ('haegeum', 'daegeum', 'taepyeongso'):
        evs = sorted([e for e in song.ev if e[0] == inst], key=lambda e: e[1])
        i = 0
        while i < len(evs):
            j = i + 1
            while j < len(evs) and evs[j][1] - (evs[j - 1][1] + evs[j - 1][2]) <= 0.02:
                j += 1
            grp = evs[i:j]
            t0 = grp[0][1]
            notes = [(e[1] - t0, e[2], e[3], e[4], e[5]) for e in grp]
            place(stem(inst), render_phrase(inst, notes, r), at(t0))
            i = j
    # 타악: 같은 악기·세기 단계마다 몇 가지 변주를 미리 만들어 돌려 쓴다(같은 소리 기관총 방지)
    cache = {}
    for kind, t0, vel in song.hits:
        tier = 0 if vel < 0.55 else 1
        key = (kind, tier, int(r.integers(0, 5)))
        if key not in cache:
            cache[key] = perc(kind, r, 0.45 if tier == 0 else 0.9)
        sig = cache[key] * (vel / (0.45 if tier == 0 else 0.9))
        jit = float(np.clip(r.normal(0, 0.004), -0.01, 0.01))
        place(stem(PERC_STEM[kind]), sig, at(t0 + jit))
    # 섞기
    dry = np.zeros((n, 2))
    send = np.zeros(n)
    levels = {}
    for name, y in stems.items():
        cfg = dict(INST[name])
        cfg.update(song.mix.get(name, {}))
        if cfg['eq']:
            y = filt(y, *cfg['eq'])
        lv = lufs(y[:L])  # 소리 나는 구간만 보는 문턱 음량
        if lv > -69.0:
            y = y * 10 ** ((cfg['lu'] - lv) / 20)
        levels[name] = (lv, cfg['lu'])
        dry += pan_st(y, cfg['pan'])
        send += y * cfg['send']
    ir = make_ir(rng_for('hall'), rt60=song.rt60, predelay=0.024)
    wet = reverb_st(send, ir)[:n] * 0.55 * song.wet
    mix = dry + wet
    if song.loop:
        mix[: n - L] += mix[L:]  # 끝을 넘친 꼬리를 앞에 겹친다 = 반복했을 때 실제로 들리는 소리
        mix = mix[:L]
        if song.eq:
            mix = filt(mix, *song.eq, circular=True)
        if song.ambient is not None:
            mix += song.ambient(L, rng_for(song.name + ':amb'))
        # 파일 시작을 첫 박보다 30 ms 앞(= 끝 부분)으로 돌려 둔다: 반복이 그대로 이어지면서도
        # 파일의 첫 표본이 북·장구가 막 터지는 자리에 놓이지 않게.
        mix = np.roll(mix, nsamp(0.03), axis=0)
    else:
        mix = fade(mix[:L], fout=0.25)
    return mix, levels


# ════════════════════════════════════════════════════════════════════
# 5. 배경 음악 (반복) — 장단 · 선법 · 프레이즈
# ════════════════════════════════════════════════════════════════════

def u_of(tempo_bpm, sub):
    """박(bpm) 하나를 sub 로 쪼갠 단위의 초."""
    return 60.0 / tempo_bpm / sub


def bgm_lobby():
    """로비: 차분하고 반가운 — 대금이 부르고 가야금이 받는다(세마치, 평조 솔-라-도-레-미)."""
    s = Song('bgm_lobby', u_of(72, 3), 9, 20, 'pyeong', 67)
    A = '2:3 3:2 4:1 5:3v | 4:2 3:1 2:3 3:3'
    A2 = '2:3 3:2 4:1 6:3V | 5:2 4:1 3:3 4:3/'
    R = '5:1 4:1 3:1 2:3 1:3 | 2:2 1:1 0:6v'
    R2 = '6:1 5:1 4:1 3:2 2:1 1:3 | 0:2 1:1 2:3 0:3v'
    s.play('gayageum', s.cyc(0), '0:3 2:2 3:1 4:3 | 3:2 2:1 1:3 0:3v', octave=-1, vel=0.62)
    s.play('gayageum', s.cyc(2), '2:3 4:2 5:1 4:3 | 3:2 2:1 0:6v', octave=-1, vel=0.62)
    s.play('daegeum', s.cyc(4), A, vel=0.7)
    for c in (4, 5, 8, 9):
        s.play('gayageum2', s.cyc(c), '0+2:3 r:3 2:3', octave=-1, vel=0.35)
    s.play('gayageum', s.cyc(6), R, octave=-1, vel=0.66)
    s.play('daegeum', s.cyc(8), A2, vel=0.72)
    s.play('gayageum', s.cyc(10), R2, octave=-1, vel=0.66)
    s.play('daegeum', s.cyc(12), '7:6V 6:3 | 5:9v | 4:3 5:3 6:3 | 5:6 4:3\\', vel=0.75)
    for c, rt in zip(range(12, 16), (2, 0, 1, 0)):
        s.arp('gayageum', c, rt, [0, 2, 4, 5, 4, 2, 3, 2, 1], octave=-1, vel=0.42)
    s.play('daegeum', s.cyc(16), A, vel=0.72)
    s.play('gayageum', s.cyc(16), hetero(A), octave=-1, vel=0.55)
    s.play('daegeum', s.cyc(18), '4:3 3:2 2:1 1:3 | 0:6v r:3', vel=0.68)
    s.play('gayageum', s.cyc(18), 'r:6 0:1 2:1 3:1 | 4:3 3:3 2:3', octave=-1, vel=0.55)
    s.play('geomungo', s.cyc(0), '0:9', octave=-1, vel=0.45)
    for c in range(4, 20, 2):
        s.play('geomungo', s.cyc(c), '0:9' if c % 4 == 0 else '-3:9', octave=-1, vel=0.4)
    s.jangdan('semachi', 0, 4, vel=0.32, fill_every=0, skip=(3, 5, 7))
    s.jangdan('semachi', 4, 20, vel=0.42)
    s.mix = {'gayageum': dict(lu=-1.0), 'janggu': dict(lu=-10.0), 'geomungo': dict(lu=-11.0),
             'gayageum2': dict(lu=-11.0)}
    return s


def bgm_dustyYard():
    """1장 흙먼지 마당(마을): 밝고 가벼운 가야금 산조풍 — 세마치, 평조(으뜸 A)."""
    s = Song('bgm_dustyYard', u_of(92, 3), 9, 26, 'pyeong', 69)
    L1 = '0:1 1:1 2:1 3:3 2:2 3:1 | 4:3 3:1 2:1 1:1 2:3'
    L2 = '4:1 5:1 4:1 3:3 4:2 5:1 | 6:3v 5:2 4:1 3:3'
    L3 = '5:2 4:1 3:2 2:1 1:3 | 2:1 1:1 0:1 0+5:6v'
    L4 = '2:1 4:1 2:1 5:3 4:1 2:2 | 3:2 1:1 2:3 0:3'
    D1 = '5:3 4:3 3:3 | 2:6v r:3'
    D2 = '7:3 6:3 5:3 | 6:3 5:3 4:3\\'
    for c in (0, 1):
        s.arp('gayageum2', c, 0, [0, 2, 4, 2, 5, 4, 2, 4, 2], vel=0.4)
    plan = [(2, L1, 0), (4, L2, 0), (6, L1.replace('2:3', '2:1 3:1 2:1'), 0), (8, L3, 0),
            (12, L4, 0), (14, L4, 2), (18, L2, 0), (20, L3, 0), (22, hetero(L1), 0)]
    for c, ph, sh in plan:
        s.play('gayageum', s.cyc(c), ph, shift=sh, vel=0.78)
    s.play('daegeum', s.cyc(10), D1, vel=0.62)
    s.play('daegeum', s.cyc(16), D2, vel=0.66)
    s.play('gayageum', s.cyc(16), hetero(D2), octave=-1, vel=0.5)
    for c in (10, 11):
        s.arp('gayageum2', c, 2, [0, None, 2, 0, None, 2, 3, 2, 0], vel=0.42)
    s.play('gayageum', s.cyc(24), '5:1 4:1 3:1 2:1 1:1 0:1 1:1 2:1 3:1 | 2:3 1:3 0:3', vel=0.72)
    roots = [0, 0, 2, 0]
    for c in range(0, 26):
        rt = roots[c % 4]
        s.play('geomungo', s.cyc(c), '%d:6 %d:3' % (rt, rt + 3 if rt == 0 else rt - 2), octave=-2, vel=0.5)
    s.jangdan('semachi', 0, 26, vel=0.6)
    s.mix = {'gayageum': dict(lu=0.0), 'daegeum': dict(lu=-2.0), 'gayageum2': dict(lu=-9.0),
             'geomungo': dict(lu=-8.0), 'janggu': dict(lu=-7.0)}
    return s


def bgm_oilyTable():
    """2장 기름진 상(주막): 왁자지껄 익살 — 해금이 미끄러지며 놀고 가야금이 맞장구(자진모리, 평조 D)."""
    s = Song('bgm_oilyTable', u_of(112, 3), 12, 24, 'pyeong', 62)
    H1 = '2:2 3:1 4:2 3:1 2:1. 2:1. 3:1 4:3^ | 5:2 4:1 3:2 2:1 1:3 0:3\\'
    H2 = '4:1. 4:1. 4:1 5:3 4:1. 3:1. 2:1 3:3v | 2:2 1:1 2:2 3:1 4:6\\'
    H3 = '7:1. r:1 7:1. 6:1. r:1 5:1. 4:2 3:1 2:3/ | 1:1. 2:1. 1:1. 0:3 r:3 -1:1. 0:2'
    G1 = '5:1 4:1 5:1 3:3 2:1 3:1 4:1 2:3'
    G2 = '0:1 2:1 3:1 4:1 5:1 7:1 5:3 r:3'
    s.play('haegeum', s.cyc(1), 'r:6 0:6/', vel=0.6)
    s.play('haegeum', s.cyc(2), H1, vel=0.72)
    s.play('gayageum', s.cyc(4), G1, vel=0.7)
    s.play('haegeum', s.cyc(5), 'r:6 5:1. 4:1. 3:1. 2:3\\', vel=0.7)
    s.play('haegeum', s.cyc(6), H2, vel=0.74)
    s.play('haegeum', s.cyc(8), H1, shift=1, vel=0.74)
    s.play('haegeum', s.cyc(10), H3, vel=0.76)
    s.play('haegeum', s.cyc(12), '5:6V 4:6\\ | 3:6v 2:6/ | 4:6V 3:6\\ | 2:3 1:3 0:6v', vel=0.68)
    for c, rt in zip(range(12, 16), (2, 0, 3, 0)):
        s.arp('gayageum', c, rt, [0, 2, 4, 2, 5, 4, 2, 4, 3, 2, 1, 2], vel=0.45)
    s.play('haegeum', s.cyc(16), H2.replace('4:6\\', '5:3 4:3\\'), vel=0.74)
    s.play('gayageum', s.cyc(18), G1, vel=0.7)
    s.play('gayageum', s.cyc(19), G2, vel=0.7)
    s.play('haegeum', s.cyc(20), H1, vel=0.76)
    s.play('haegeum', s.cyc(22), H3, vel=0.76)
    # 쿵짝짝 반주: 박 머리는 거문고, 뒤 두 쪽은 가야금 짧게 뜯기
    roots = [0, 0, 3, 0, 2, 0, 3, 0]
    for c in range(24):
        rt = roots[c % 8]
        for b in range(4):
            u = s.cyc(c) + 3 * b
            s.play('geomungo', u, '%d:1.5' % (rt if b % 2 == 0 else rt + 3), octave=-1, vel=0.5)
            s.play('gayageum2', u + 1, '%d+%d:1.' % (rt + 2, rt + 4), vel=0.33)
            s.play('gayageum2', u + 2, '%d+%d:1.' % (rt + 2, rt + 4), vel=0.28)
    s.jangdan('jajin', 0, 24, vel=0.62)
    s.mix = {'gayageum': dict(lu=-3.0), 'gayageum2': dict(lu=-11.0), 'geomungo': dict(lu=-7.0)}
    return s


def bgm_turtleMarket():
    """3장 거북 장터(축제): 꽹과리·장구·북이 휘몰아치고 태평소가 장터를 부른다(휘모리풍, 평조 B♭)."""
    s = Song('bgm_turtleMarket', u_of(150, 2), 8, 32, 'pyeong', 58)
    P1 = [(0, 'kkwaeng', 1.0), (1, 'kkwaeng_d', 0.45), (2, 'kkwaeng', 0.7), (3, 'kkwaeng_d', 0.45),
          (4, 'kkwaeng', 0.85), (5, 'kkwaeng_d', 0.45), (6, 'kkwaeng', 0.7), (7, 'kkwaeng_d', 0.5)]
    P2 = [(0, 'kkwaeng', 1.0), (1, 'kkwaeng_d', 0.5), (2, 'kkwaeng', 0.8), (4, 'kkwaeng', 0.9),
          (5, 'kkwaeng_d', 0.5), (6, 'kkwaeng', 0.8), (7, 'kkwaeng_d', 0.5)]
    FILL = [(i * 0.5, 'kkwaeng_d', 0.4 + 0.04 * i) for i in range(12)] + [(6, 'kkwaeng', 1.0)]
    for b in range(32):
        pat = FILL if b % 4 == 3 else (P1 if (b // 8) % 2 == 0 else P2)
        for u, k, v in pat:
            s.hit(k, s.cyc(b) + u, v * (0.75 if b < 2 else 0.9))
        s.hit('buk', s.cyc(b), 0.85)
        s.hit('buk', s.cyc(b) + 4, 0.6)
        if b % 4 == 0:
            s.hit('jing', s.cyc(b), 0.8)
    s.jangdan('hwimori', 0, 32, vel=0.7)
    T1 = '5:2 6:2 7:3 6:1 | 5:2 4:2 5:4v'
    T2 = '7:1 8:1 7:2 6:2 5:2 | 4:2 3:2 2:4\\'
    T3 = '2:2 3:2 4:2 5:2 | 6:3 5:1 4:4v'
    T4 = '5:2 4:1 3:1 2:2 3:2 | 2:2 1:2 0:4v'
    for i, ph in enumerate((T1, T2, T3, T4)):
        s.play('taepyeongso', s.cyc(8 + 2 * i), ph, vel=0.85)
    for i, ph in enumerate((T1, T3)):
        s.play('gayageum', s.cyc(16 + 4 * i), ph, octave=-1, vel=0.72)
        s.play('gayageum', s.cyc(18 + 4 * i), hetero(ph), shift=-1, octave=-1, vel=0.66)
    for i, ph in enumerate((hetero(T1), T2, T3, T4)):
        s.play('taepyeongso', s.cyc(24 + 2 * i), ph, vel=0.88)
    s.play('gayageum2', s.cyc(24), hetero(T1), octave=-1, vel=0.4)
    s.eq = [('lshelf', 120, 0.7, -4.0)]
    s.mix = {'janggu': dict(lu=-7.0), 'buk': dict(lu=-11.0), 'kkwaeng': dict(lu=-8.0), 'jing': dict(lu=-10.0),
             'taepyeongso': dict(lu=-2.0), 'gayageum': dict(lu=-3.0), 'gayageum2': dict(lu=-10.0)}
    s.rt60 = 1.8
    return s


def bgm_kubiForest():
    """4장 구비 숲(깊은 숲, 신비): 대금이 길게 떨고 꺾으며 숲을 헤맨다. 장단은 중모리를 성기게(계면조 E)."""
    s = Song('bgm_kubiForest', u_of(84, 2), 24, 6, 'gyemyeon', 64)
    F0 = 'r:8 0:8/ 2:4 1:4\\'
    F1 = '0:4/ 1:2 2:4v 3:6V 2:2 1:2\\ 0:4'
    F2 = '3:4 4:2 5:6V 4:2 3:4v 2:2 1:4\\'
    F3 = '5:2 6:2 7:8V 6:2 5:2 3:6v 2:2'
    F4 = '3:6V 2:2 1:2 0:6v r:4 -1:2/ 0:2'
    for c, ph, sh in ((0, F0, 0), (1, F1, 0), (2, F2, 0), (3, F3, 0), (4, F2, -1), (5, F4, 0)):
        s.play('daegeum', s.cyc(c), ph, shift=sh, vel=0.72)
    # 숲의 반짝임: 높은 가야금이 드문드문(씨앗 고정이라 늘 같은 자리)
    rr = rng_for('kubi-sparkle')
    for c in range(6):
        for _ in range(3):
            u = s.cyc(c) + int(rr.integers(0, 23))
            s.play('gayageum2', u, '%d:3v' % int(rr.choice([5, 7, 8, 10])), vel=0.3)
    for c in range(6):
        s.play('geomungo', s.cyc(c), '0:12v' if c % 2 == 0 else '-1:6 0:6', octave=-1, vel=0.42)
    s.jangdan('jungmori', 0, 6, vel=0.4, fill_every=3, skip=(6, 16, 18))
    for c in range(6):
        s.hit('buk', s.cyc(c), 0.45)
    s.hit('jing', s.cyc(0), 0.4)
    s.hit('jing', s.cyc(3), 0.35)

    def wind(n, r):
        # 바람: 정확히 곡 길이마다 되풀이되는 잡음 + 그 길이에 딱 맞는 느린 출렁임 → 이음매 없음
        cyc = n / SR
        ys = []
        for ch in range(2):
            z = periodic_noise(n, r, lambda f: np.exp(-0.5 * (np.log2(np.maximum(f, 1) / 700) / 0.9) ** 2))
            t = np.arange(n) / n
            m = 0.55 + 0.25 * np.sin(TAU * 3 * t + ch) + 0.2 * np.sin(TAU * 7 * t + 2 * ch)
            ys.append(z * m)
        return np.stack(ys, axis=1) * 10 ** (-38 / 20)

    s.ambient = wind
    s.mix = {'janggu': dict(lu=-11.0), 'buk': dict(lu=-11.0), 'jing': dict(lu=-14.0),
             'geomungo': dict(lu=-9.0), 'gayageum2': dict(lu=-9.0, send=0.55)}
    s.rt60 = 3.0
    s.wet = 1.3
    return s


def bgm_logicMarble():
    """5장 이치의 구슬(서원): 의젓한 거문고가 이끌고 가야금이 받는다 — 진양풍이지만 걸음은 멈추지 않게(평조 D)."""
    s = Song('bgm_logicMarble', u_of(80, 3), 12, 17, 'pyeong', 50)
    M = {
        1: '0:3 2:2 3:1 4:4v 3:2', 2: '5:4V 4:2 3:2 2:2 3:2', 3: '4:3 3:1 2:2 1:2 0:4v',
        4: '2:2 3:2 5:2 6:4V 5:2', 5: '7:3 6:1 5:2 4:2 5:4^', 6: '4:2 3:2 2:2 3:2 0:4\\',
    }
    R1 = '5:1 4:1 3:1 2:3 3:2 2:1 0:3'
    R2 = '2:1 3:1 4:1 5:3v 4:2 3:1 2:3'
    plan = {0: M[1], 1: M[3], 2: hetero(M[1]), 4: M[2], 5: M[3], 7: M[4], 8: M[5], 9: M[6],
            14: M[1], 15: M[5], 16: M[3]}
    for c, ph in plan.items():
        s.play('geomungo', s.cyc(c), ph, vel=0.78)
    s.play('gayageum', s.cyc(3), R1, octave=1, vel=0.66)
    s.play('gayageum', s.cyc(6), R2, octave=1, vel=0.66)
    s.play('gayageum', s.cyc(14), hetero(M[1]), octave=1, vel=0.5)
    s.play('daegeum', s.cyc(10), '7:12V | 5:12v | 6:6 5:6 | 4:12\\', octave=1, vel=0.6)
    for c in range(10, 14):
        s.play('geomungo', s.cyc(c), '0:3 0:3 2:3 3:3', vel=0.6)
        s.arp('gayageum', c, (2, 0, 1, 0)[c - 10], [0, 2, 4, 5, 4, 2, 0, 2, 4, 2, 1, 2], octave=1, vel=0.4)
    s.jangdan('jinyang', 0, 17, vel=0.5)
    s.mix = {'geomungo': dict(lu=0.0, pan=0.0), 'gayageum': dict(lu=-2.0), 'daegeum': dict(lu=-4.0),
             'janggu': dict(lu=-8.0)}
    return s


def bgm_murimIce():
    """6장 무림 빙판(천하 대회): 북·징·꽹과리가 몰아치고 태평소와 해금이 장엄하게(휘모리, 평조 C)."""
    s = Song('bgm_murimIce', u_of(176, 2), 8, 36, 'pyeong', 60)
    E1 = '5:3 6:1 7:2 8:2 | 7:2 6:2 5:4v'
    E2 = '8:2 9:2 10:3 9:1 | 8:2 7:2 8:4V'
    E3 = '7:2 6:1 5:1 4:2 5:2 | 3:2 2:2 3:4\\'
    E4 = '2:1 3:1 5:2 6:2 7:2 | 8:6V r:2'
    H = '5:1 6:1 7:1 6:1 5:2 3:2 | 5:8v'
    for b in range(36):
        u = s.cyc(b)
        intro = b < 4
        for k in range(4):
            s.hit('buk', u + 2 * k, (0.95 if k == 0 else 0.7) * (0.55 + 0.1 * b if intro else 1.0))
        if b % 4 == 3:
            s.hit('buk', u + 5, 0.55)
            s.hit('buk', u + 7, 0.75)
        if b % 4 == 0 and not (16 <= b < 18):
            s.hit('jing', u, 0.9)
        if b >= 2 and not (16 <= b < 18):
            for k in range(8):
                s.hit('kkwaeng' if k % 2 == 0 else 'kkwaeng_d', u + k, 0.85 if k == 0 else 0.55)
    s.jangdan('hwimori', 0, 36, vel=0.65)
    for i, ph in enumerate((E1, E2, E3, E4)):
        s.play('taepyeongso', s.cyc(4 + 2 * i), ph, vel=0.85)
        s.play('haegeum', s.cyc(4 + 2 * i), hetero(ph), octave=-1, vel=0.5)
    s.play('haegeum', s.cyc(12), H, vel=0.75)
    s.play('taepyeongso', s.cyc(14), E3, vel=0.85)
    s.play('haegeum', s.cyc(18), '0:1 1:1 2:1 3:1 4:1 5:1 6:1 7:1 | 8:8V', vel=0.8)
    for i, ph in enumerate((hetero(E1), E2, E4, E3)):
        s.play('taepyeongso', s.cyc(20 + 2 * i), ph, shift=1 if i == 0 else 0, vel=0.9)
    s.play('haegeum', s.cyc(20), E1, shift=1, octave=-1, vel=0.6)
    climax = '10:4 9:2 8:2 | 7:8V | 8:2 7:2 6:2 5:2 | 5:8v'
    s.play('taepyeongso', s.cyc(28), climax, vel=0.92)
    s.play('haegeum', s.cyc(28), climax, octave=-1, vel=0.78)
    s.play('geomungo', s.cyc(0), ' '.join(['0:8'] * 36), octave=-1, vel=0.55)
    s.eq = [('lshelf', 120, 0.7, -3.0)]
    s.mix = {'taepyeongso': dict(lu=0.0), 'haegeum': dict(lu=-2.0), 'buk': dict(lu=-8.0), 'janggu': dict(lu=-7.0),
             'kkwaeng': dict(lu=-9.0), 'jing': dict(lu=-8.0), 'geomungo': dict(lu=-10.0)}
    s.rt60 = 2.0
    return s


def bgm_boss():
    """우두머리 대결: 팽팽하고 빠르게 — 계면조(라 도 레 미 솔) 해금이 긁고 북이 몰아붙인다."""
    s = Song('bgm_boss', u_of(184, 2), 8, 38, 'gyemyeon', 57)
    B1 = '3:3V 4:1 3:2 2:2 | 1:2 2:1 1:1 0:4v'
    B2 = '5:2 4:1 3:1 4:2 5:2 | 6:3V 5:1 3:4\\'
    B3 = '0:1. 1:1. 2:1. 3:1. 4:1. 3:1. 2:1. 1:1. | 0:2 3:2 2:2 1:2^'
    B4 = '5:4V 6:2 5:2 | 3:6v r:2'
    riff = '0:2 0:1 1:1 0:2 -1:2'
    for b in range(38):
        u = s.cyc(b)
        brk = 14 <= b < 18
        s.play('geomungo', u, riff if not brk else '0:8', octave=-1, vel=0.62)
        if brk:
            s.hit('buk', u, 0.8)
            s.hit('buk', u + 1.5, 0.55)
            continue
        for k, v in ((0, 1.0), (3, 0.7), (4, 0.85), (6, 0.7), (7, 0.6)):
            s.hit('buk', u + k, v)
        if b >= 2:
            for k in (1, 3, 5, 7):
                s.hit('kkwaeng_d', u + k, 0.5)
        if b % 8 == 2 or b == 18:
            s.hit('jing', u, 0.9)
    s.hit('jing', s.cyc(14), 0.8)
    s.jangdan('hwimori', 0, 14, vel=0.62)
    s.jangdan('hwimori', 18, 38, vel=0.66)
    seq = [(2, B1, 0), (4, B2, 0), (6, B1, 1), (8, B3, 0), (10, B4, 0), (12, B4, -1),
           (18, B2, 0), (20, B1, 0), (22, B3, 0), (24, B4, 0), (30, B1, 5), (32, B2, 0), (34, B3, 5)]
    for b, ph, sh in seq:
        s.play('haegeum', s.cyc(b), ph, shift=sh, vel=0.8)
    s.play('haegeum', s.cyc(14), '3:8V | 2:8v | 1:8V | 0:8\\', vel=0.6)
    for b in (10, 11, 12, 13):
        s.play('taepyeongso', s.cyc(b), '5:1> r:1 5:1> r:3 4:1 3:1', vel=0.8)
    for b in (26, 28):
        s.play('haegeum', s.cyc(b), '3:2 4:2 5:4V', vel=0.82)
        s.play('taepyeongso', s.cyc(b + 1), '6:2 5:2 3:4\\', vel=0.85)
    s.play('taepyeongso', s.cyc(36), '5:4V 3:4\\', vel=0.85)
    s.eq = [('lshelf', 120, 0.7, -3.0)]
    s.mix = {'haegeum': dict(lu=0.0), 'taepyeongso': dict(lu=-3.0), 'buk': dict(lu=-8.0), 'janggu': dict(lu=-7.0),
             'kkwaeng': dict(lu=-11.0), 'jing': dict(lu=-9.0), 'geomungo': dict(lu=-5.0)}
    s.rt60 = 1.7
    return s


# ── 징글(한 번 울리고 끝) ─────────────────────────────────────────
def jingle_win():
    """이겼다: 가야금이 훑어 오르고 꽹과리가 깨갱, 징과 함께 태평소가 높이 외친다."""
    s = Song('jingle_win', 0.12, 1, 1, 'pyeong', 60, loop=False, length=4.2)
    s.play('gayageum', 0, ' '.join('%d:0.5' % d for d in range(0, 10)), vel=0.7)
    for i in range(8):
        s.hit('kkwaeng_d', i * 0.5, 0.4 + 0.05 * i)
    s.hit('kkwaeng', 5, 1.0)
    s.hit('buk', 0, 0.8)
    s.hit('buk', 5, 1.0)
    s.hit('jing', 6, 0.9)
    s.hit('deong', 6, 1.0)
    s.play('taepyeongso', 6, '5:2 7:2 8:12V', vel=0.9)
    s.play('gayageum', 6, '5+10:6v', vel=0.8)
    s.hit('deong', 22, 0.9)
    s.hit('kkwaeng', 22, 0.8)
    s.mix = {'taepyeongso': dict(lu=-1.0), 'kkwaeng': dict(lu=-8.0), 'gayageum': dict(lu=-2.0)}
    return s


def jingle_lose():
    """졌다: 해금이 계면조로 흘러내리고(퇴성) 북이 낮게 한 번."""
    s = Song('jingle_lose', 0.16, 1, 1, 'gyemyeon', 57, loop=False, length=3.3)
    s.play('haegeum', 0, '4:3 3:3 2:3v 0:8\\', vel=0.72)
    s.hit('buk', 0, 0.7)
    s.hit('buk', 9, 0.6)
    s.hit('jing', 9, 0.35)
    s.play('geomungo', 9, '0:8v', octave=-1, vel=0.5)
    s.mix = {'buk': dict(lu=-5.0), 'jing': dict(lu=-12.0), 'geomungo': dict(lu=-6.0)}
    return s


def jingle_levelup():
    """솜씨가 올랐다: 가야금 빠른 오름 + 꽹과리 '깽' + 대금 높은 소리."""
    s = Song('jingle_levelup', 0.06, 1, 1, 'pyeong', 67, loop=False, length=2.6)
    s.play('gayageum', 0, ' '.join('%d:1' % d for d in range(-3, 8)), vel=0.7)
    s.hit('kkwaeng', 11, 0.9)
    s.hit('deong', 11, 0.8)
    s.play('daegeum', 11, '8:16V', vel=0.8)
    s.play('gayageum', 11, '3+8:8v', vel=0.7)
    return s


def jingle_reward():
    """보상: 가야금이 반짝 오르내리고 막은 꽹과리 하나."""
    s = Song('jingle_reward', 0.055, 1, 1, 'pyeong', 72, loop=False, length=2.1)
    s.play('gayageum', 0, ' '.join('%d:1' % d for d in (0, 2, 4, 5, 7, 9, 10, 9, 7)) + ' 5+10:6v', vel=0.7)
    s.hit('kkwaeng_d', 9, 0.6)
    s.hit('kkwaeng', 15, 0.7)
    s.mix = {'kkwaeng': dict(lu=-8.0), 'gayageum': dict(lu=0.0)}
    return s


def jingle_chapter():
    """새 장 시작: 북이 몰아 올라가다 징·북이 크게 한 번, 태평소가 외친다."""
    s = Song('jingle_chapter', 0.1, 1, 1, 'pyeong', 60, loop=False, length=3.4)
    for i in range(8):
        s.hit('buk', i * 1.0 - 0.06 * i * i * 0.1, 0.3 + 0.08 * i)
    s.hit('buk', 9, 1.0)
    s.hit('jing', 9, 1.0)
    s.hit('deong', 9, 0.9)
    s.play('taepyeongso', 10, '5:2 7:5 8:10V', vel=0.9)
    s.mix = {'taepyeongso': dict(lu=-1.0), 'jing': dict(lu=-5.0), 'buk': dict(lu=-6.0), 'janggu': dict(lu=-6.0)}
    return s


MUSIC = [bgm_lobby, bgm_dustyYard, bgm_oilyTable, bgm_turtleMarket, bgm_kubiForest,
         bgm_logicMarble, bgm_murimIce, bgm_boss]
JINGLES = [jingle_win, jingle_lose, jingle_levelup, jingle_reward, jingle_chapter]


# ════════════════════════════════════════════════════════════════════
# 6. 효과음 (모노)
# ════════════════════════════════════════════════════════════════════
_ROOM = None


def room(y, wet=0.15, rt=0.45):
    """작은 방 잔향(효과음용, 모노)."""
    global _ROOM
    if _ROOM is None or _ROOM[0] != rt:
        ir = make_ir(rng_for('room'), rt60=rt, length=rt * 1.4, predelay=0.004, n_er=10, er_span=0.03)
        _ROOM = (rt, ir.mean(axis=1) / np.sqrt(np.sum(ir.mean(axis=1) ** 2)))
    w = fft_conv(y, _ROOM[1])[: len(y)]
    return y + wet * w * np.max(np.abs(y)) / (np.max(np.abs(w)) + 1e-12)


def sweep_noise(n, r, f_start, f_peak_t, f_end, q=1.2, env=None):
    """대역 통과 잡음의 중심이 f_start → (가운데) → f_end 로 쓸려 가는 바람 소리."""
    T = n / SR

    def g(tt, ff):
        x = np.clip(tt / T, 0, 1)
        fc = np.where(x < f_peak_t[0], f_start * (f_peak_t[1] / f_start) ** (x / f_peak_t[0]),
                      f_peak_t[1] * (f_end / f_peak_t[1]) ** ((x - f_peak_t[0]) / (1 - f_peak_t[0] + 1e-9)))
        return np.exp(-0.5 * (np.log2(np.maximum(ff, 1) / fc) / (1.0 / q)) ** 2)

    y = stft_filter(white(n, r), g)
    if env is not None:
        y *= env
    return y


def sfx_touch(r):
    """손끝이 알에 닿음: 단단한 돌 알의 아주 짧은 '톡'."""
    n = nsamp(0.1)
    y = modal(n, [(2350, 1, 0.022), (5400, 0.45, 0.011), (8100, 0.22, 0.007), (1180, 0.25, 0.018)])
    y += burst(n, r, 0.0018, ('hp', 3000, 0.7), amp=0.5)
    return room(y, 0.08)


def sfx_hit_cheongok(r):
    """청옥 알끼리: 맑고 단단한 옥 '쨍그랑' — 높은 진동 모드 + 살짝 튕긴 두 번째 맞닿음."""
    n = nsamp(0.5)
    parts = [(3150, 1, 0.12), (4980, 0.6, 0.08), (7230, 0.45, 0.05), (9850, 0.25, 0.03), (2210, 0.2, 0.06)]
    y = modal(n, parts)
    y2 = np.zeros(n)
    place(y2, modal(n, [(f * 1.013, a * 0.4, d * 0.7) for f, a, d in parts]), nsamp(0.042))
    y += y2
    y += burst(n, r, 0.0015, ('hp', 4000, 0.7), amp=0.6)
    return room(y, 0.12)


def sfx_hit_wood(r):
    """나무 알: 둥글고 마른 '똑'."""
    n = nsamp(0.22)
    y = modal(n, [(620, 1, 0.045), (1180, 0.6, 0.03), (1930, 0.4, 0.02), (2900, 0.2, 0.012), (180, 0.3, 0.03)])
    y += burst(n, r, 0.004, ('bp', 2500, 0.9), amp=0.7)
    return room(y, 0.12)


def sfx_hit_hyeoncheol(r):
    """현철(검은 쇠) 알: 묵직한 쇠 '쩡' — 비조화 배음과 맥놀이, 길게 운다."""
    n = nsamp(1.1)
    parts = [(410, 1, 0.6), (413, 0.6, 0.55), (1127, 0.7, 0.45), (1131, 0.4, 0.4), (2210, 0.5, 0.3),
             (3650, 0.35, 0.2), (5400, 0.2, 0.12), (7300, 0.12, 0.08)]
    y = modal(n, parts)
    y = np.tanh(1.3 * y / (np.max(np.abs(y)) + 1e-12))
    y += burst(n, r, 0.008, ('hp', 1500, 0.7), amp=0.8)
    y += modal(n, [(130, 0.4, 0.05)])
    return room(fade(y, fout=0.1), 0.15)


def sfx_hit_ice(r):
    """얼음 알: 유리 같은 '팅' + 잘게 갈라지는 얼음 소리."""
    n = nsamp(0.7)
    y = modal(n, [(2900, 1, 0.33), (4650, 0.6, 0.24), (6900, 0.45, 0.17), (9400, 0.3, 0.1), (12500, 0.15, 0.06)])
    for _ in range(12):
        k = nsamp(r.uniform(0, 0.08))
        place(y, burst(nsamp(0.01), r, 0.0008, ('bp', r.uniform(6000, 9500), 2.0), amp=r.uniform(0.2, 0.5)), k)
    y += burst(n, r, 0.002, ('hp', 5000, 0.7), amp=0.5)
    return room(fade(y, fout=0.1), 0.15)


def exciter(y, amt=0.5, drive=4.0, lo=220.0, hi=2200.0):
    """휴대폰 작은 스피커용 '심리 저음': 저음을 일부러 일그러뜨려 생긴 배음(220 Hz~2.2 kHz)을 더한다.
    아주 낮은 소리를 못 내는 스피커에서도 귀가 빠진 기본음을 채워 '쿵'으로 듣는다."""
    pk = np.max(np.abs(y)) + 1e-12
    low = filt(y, ('lp', 200, 0.7)) / pk
    h = filt(np.tanh(drive * low / (np.max(np.abs(low)) + 1e-12)), ('hp', lo, 0.7), ('lp', hi, 0.7))
    return y + amt * pk * h / (np.max(np.abs(h)) + 1e-12)


def impact(n, r, low=150.0, lowend=60.0, ring=0.35):
    """큰 타격 공통: 내려앉는 저음 + 몸통 울림(중음) + 터지는 잡음 + 쇠 울림 + 낮은 우르릉."""
    t = tvec(n)
    f = lowend + (low - lowend) * np.exp(-t / 0.07)
    y = 0.6 * np.sin(phase_of(f)) * np.exp(-t / 0.25) * (1 - np.exp(-t / 0.002))
    y += modal(n, [(230, 0.8, 0.09), (470, 0.6, 0.06), (820, 0.45, 0.04), (1350, 0.2, 0.025)])
    y += burst(n, r, 0.03, ('bp', 2200, 0.6), amp=1.0)
    y += burst(n, r, 0.25, ('lp', 300, 0.7), amp=0.3)
    if ring > 0:
        y += ring * modal(n, [(533, 1, 0.35), (1465, 0.6, 0.25), (2873, 0.4, 0.15), (4745, 0.25, 0.08)])
    return y


def sfx_critical(r):
    """회심의 일격: 무거운 '쾅' + 쇠 울림."""
    n = nsamp(1.0)
    y = exciter(impact(n, r), 0.45)
    y = np.tanh(1.5 * y / np.max(np.abs(y)))
    return room(fade(y, fout=0.2), 0.2)


def sfx_inner(r):
    """내공을 끌어올림: 소용돌이 바람이 차오르며 음들이 함께 솟는다, 끝에 반짝."""
    n = nsamp(1.1)
    t = tvec(n)
    env = smooth01(t / 0.8) * (1 - smooth01((t - 0.9) / 0.2))
    y = sweep_noise(n, r, 400, (0.85, 4000), 3000, q=1.5, env=env) * 0.5
    for base in (261.6, 329.6, 392.0):
        f = base * 2 ** (smooth01(t / 0.9))
        y += 0.25 * np.sin(phase_of(f * (1 + 0.004 * np.sin(TAU * 6 * t)))) * env
    sp = np.zeros(n)
    for i, f in enumerate((1568, 2093, 2637)):
        place(sp, modal(nsamp(0.4), [(f, 0.3, 0.18), (f * 2.76, 0.1, 0.06)]), nsamp(0.88 + 0.03 * i))
    return room(y + sp, 0.2)


def sfx_tech_swordQi(r):
    """검기: '쉭' 하고 베는 바람 + 칼날이 '징~' 하고 우는 소리."""
    n = nsamp(1.0)
    t = tvec(n)
    env = np.exp(-((t - 0.13) / 0.07) ** 2)
    y = sweep_noise(n, r, 300, (0.13, 3500), 900, q=1.3, env=env) * 1.2
    blade = np.zeros(n)
    k = nsamp(0.11)
    tb = tvec(n - k)
    fb = 2280 * (1 - 0.03 * smooth01(tb / 0.5)) * (1 + 0.003 * np.sin(TAU * 7 * tb))
    ph = phase_of(fb)
    blade[k:] = (np.sin(ph) + 0.7 * np.sin(ph * 1.0066) + 0.4 * np.sin(ph * 2.26) * np.exp(-tb / 0.2)
                 + 0.2 * np.sin(ph * 3.46) * np.exp(-tb / 0.1)) * np.exp(-tb / 0.45) * (1 - np.exp(-tb / 0.002))
    y += 0.45 * blade
    y += np.concatenate([np.zeros(k), burst(n - k, r, 0.06, ('hp', 5000, 0.7), amp=0.4)])
    return room(fade(y, fout=0.15), 0.18)


def sfx_tech_stomp(r):
    """진각(땅 구르기): 땅이 울리는 깊은 '쿵' + 흙 부서짐 + 낮은 울림."""
    n = nsamp(1.0)
    t = tvec(n)
    f = 55 + 55 * np.exp(-t / 0.08)
    y = 0.4 * np.sin(phase_of(f)) * np.exp(-t / 0.3) * (1 - np.exp(-t / 0.003))
    y += modal(n, [(180, 0.45, 0.1), (340, 0.9, 0.08), (650, 0.7, 0.05), (1150, 0.35, 0.03)])  # 바닥 판이 울리는 몸통
    y += burst(n, r, 0.08, ('bp', 600, 0.7), amp=0.8)
    for _ in range(30):  # 흙·자갈이 부서지는 잔소리
        place(y, burst(nsamp(0.03), r, 0.006, ('bp', r.uniform(700, 3500), 1.5), amp=r.uniform(0.25, 0.6)),
              nsamp(r.uniform(0.0, 0.18)))
    br = np.cumsum(white(n, r))
    br = filt(br - np.mean(br), ('lp', 120, 0.7), ('hp', 25, 0.7))
    y += 0.25 * br / (np.max(np.abs(br)) + 1e-12) * np.exp(-t / 0.4)
    y = exciter(y, 0.9)
    y = np.tanh(1.4 * y / np.max(np.abs(y)))
    return room(fade(y, fout=0.2), 0.15)


def sfx_tech_taiji(r):
    """태극: 음양이 맞물려 도는 소용돌이 — 대역이 둥글게 오르내리는 바람 + 두 음이 엇갈려 출렁."""
    n = nsamp(1.3)
    t = tvec(n)
    T = n / SR
    env = np.sin(np.pi * np.clip(t / T, 0, 1)) ** 1.2

    def g(tt, ff):
        fc = 1100 * 2 ** (1.2 * np.sin(TAU * 2 * tt / T))
        return np.exp(-0.5 * (np.log2(np.maximum(ff, 1) / fc) / 0.6) ** 2)

    y = stft_filter(white(n, r), g) * env
    y = y / (np.max(np.abs(y)) + 1e-12)
    trem = np.sin(TAU * 3 * t)
    y += 0.35 * env * (np.sin(TAU * 440 * t) * (0.5 + 0.5 * trem) + np.sin(TAU * 659.3 * t) * (0.5 - 0.5 * trem))
    y += 0.25 * np.sin(phase_of(110 + 30 * np.sin(TAU * t / T))) * env
    return room(y, 0.2)


def sfx_tech_clone(r):
    """분신술: 한 소리가 셋으로 갈라지며 반짝 — 음이 점점 벌어지는 합창 + 잔 반짝임."""
    n = nsamp(1.0)
    t = tvec(n)
    spread = smooth01(t / 0.4)
    env = (1 - np.exp(-t / 0.01)) * np.exp(-t / 0.4)
    y = np.zeros(n)
    for c in (-1, 0, 1):
        f = 880 * 2 ** (c * 0.8 * spread / 12)
        ph = phase_of(f * (1 + 0.003 * np.sin(TAU * (5 + c) * t)))
        y += (np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)) * env
    for _ in range(10):
        f = r.choice([2637, 3136, 3520, 4186])
        place(y, modal(nsamp(0.2), [(f, 0.25, 0.06)]), nsamp(r.uniform(0.05, 0.6)))
    y += 0.5 * sweep_noise(n, r, 1500, (0.1, 5000), 2000, q=1.5, env=np.exp(-((t - 0.08) / 0.05) ** 2))
    return room(y, 0.2)


def sfx_tech_absorb(r):
    """흡성(빨아들임): 거꾸로 감기는 바람이 점점 세지다 '쑥' 들어가고 낮게 툭."""
    n = nsamp(0.9)
    t = tvec(n)
    env = (t / 0.75) ** 2.2 * (1 - smooth01((t - 0.75) / 0.03))
    y = sweep_noise(n, r, 4500, (0.5, 1500), 300, q=1.4, env=env)
    y = y / (np.max(np.abs(y)) + 1e-12)
    f = 1200 * (150 / 1200) ** np.clip(t / 0.78, 0, 1)
    y += 0.4 * np.sin(phase_of(f)) * env
    k = nsamp(0.77)
    y[k:] += 0.6 * modal(n - k, [(90, 1, 0.08), (180, 0.3, 0.04)])
    return room(y, 0.15)


def sfx_ultimate(r):
    """필살기: 짧게 빨려 오르다 '콰광' — 땅울림·폭발 잡음·징 같은 쇠 울림."""
    n = nsamp(2.3)
    t = tvec(n)
    k = nsamp(0.35)
    pre = sweep_noise(k, r, 300, (0.95, 3000), 3000, q=1.2, env=(tvec(k) / (k / SR)) ** 2)
    pre += 0.3 * np.sin(phase_of(200 * 2 ** (2 * tvec(k) / (k / SR)))) * (tvec(k) / (k / SR)) ** 2
    y = np.zeros(n)
    y[:k] = pre / (np.max(np.abs(pre)) + 1e-12) * 0.5
    m = n - k
    tm = tvec(m)
    f = 50 + 70 * np.exp(-tm / 0.1)
    boom = 0.9 * np.sin(phase_of(f)) * np.exp(-tm / 0.4) * (1 - np.exp(-tm / 0.002))

    def g(tt, ff):
        fc = 400 + 7600 * np.exp(-np.maximum(tt, 0) / 0.25)
        return 1 / (1 + (ff / fc) ** 4)

    expl = stft_filter(white(m, r), g) * np.exp(-tm / 0.5)
    expl /= np.max(np.abs(expl)) + 1e-12
    gong = jing(r, 1.0, f0=262, length=m / SR)
    gong /= np.max(np.abs(gong)) + 1e-12
    body = modal(m, [(230, 0.5, 0.1), (430, 0.8, 0.08), (760, 0.6, 0.05), (1250, 0.3, 0.03)])
    y[k:] = boom + body + 0.8 * expl + 0.3 * gong + burst(m, r, 0.02, ('bp', 2500, 0.7), amp=0.7)
    y = exciter(y, 0.8)
    y = np.tanh(1.6 * y / np.max(np.abs(y)))
    return room(fade(y, fout=0.3), 0.22, rt=0.8)


def sfx_out_thud(r):
    """알이 판 밖으로: 잠깐 떨어지다 나무 바닥에 '툭' — 작게 두 번 더 튄다."""
    n = nsamp(0.6)
    y = np.zeros(n)
    t = tvec(nsamp(0.1))
    y[: len(t)] += 0.15 * sweep_noise(len(t), r, 600, (0.5, 900), 600, q=1.0, env=np.sin(np.pi * t / t[-1]))
    for at, a in ((0.1, 1.0), (0.24, 0.42), (0.32, 0.16)):
        s = modal(nsamp(0.25), [(170, 0.6, 0.07), (330, 0.7, 0.05), (560, 0.6, 0.035), (1150, 0.3, 0.02),
                                (2400, 0.12, 0.01)])
        s += burst(len(s), r, 0.01, ('lp', 1500, 0.7), amp=0.6)
        place(y, a * s, nsamp(at))
    return room(y, 0.12)


def voice(n, r, f0, vowel_seq, start, length):
    """함성 속 한 사람 목소리: 성대 파형(배음) × 모음 공명(포먼트)을 배음마다 바로 계산."""
    y = np.zeros(n)
    k0, k1 = nsamp(start), min(n, nsamp(start + length))
    m = k1 - k0
    if m <= 0:
        return y
    t = tvec(m)
    f = f0 * (1 + 0.18 * smooth01(t / 0.15) - 0.1 * smooth01((t - length * 0.6) / (length * 0.4)))
    f *= 1 + 0.02 * np.sin(TAU * r.uniform(4, 7) * t)
    ph = phase_of(f)
    fm = np.array(vowel_seq)  # 포먼트 (F1, F2, F3)
    env = smooth01(t / 0.06) * (1 - smooth01((t - (length - 0.25)) / 0.25))
    out = np.zeros(m)
    for k in range(1, 40):
        fk = k * f
        if np.min(fk) > 5000:
            break
        a = np.zeros(m)
        for F, bw, g in ((fm[0], 90, 1.0), (fm[1], 120, 0.6), (fm[2], 160, 0.3)):
            a += g / (1 + ((fk - F) / bw) ** 2)
        out += a * np.sin(k * ph + r.uniform(0, TAU)) / k ** 0.3
    y[k0:k1] = out * env
    return y


def sfx_out_crowd(r):
    """관중 환호: 높낮이·모음이 다른 수십 명의 '와아!'(배음 × 포먼트) + 박수 + 웅성임 잡음."""
    n = nsamp(2.0)
    t = tvec(n)
    y = np.zeros(n)
    vowels = [(800, 1200, 2500), (700, 1100, 2450), (600, 1000, 2400), (750, 1300, 2600)]  # 아·와·오 언저리
    for i in range(44):
        f0 = r.uniform(110, 180) if i % 2 == 0 else r.uniform(200, 330)
        vw = vowels[int(r.integers(0, len(vowels)))]
        vw = tuple(v * r.uniform(0.92, 1.08) for v in vw)
        y += voice(n, r, f0, vw, r.uniform(0.0, 0.35), r.uniform(0.9, 1.5)) * r.uniform(0.4, 1.0)
    y /= np.max(np.abs(y)) + 1e-12
    clap = np.zeros(n)
    for _ in range(70):
        place(clap, burst(nsamp(0.03), r, 0.004, ('bp', r.uniform(1000, 2500), 1.2), amp=r.uniform(0.2, 0.6)),
              nsamp(r.uniform(0.05, 1.5)))
    wash = filt(pink(n, r), ('bp', 1000, 0.5)) * smooth01(t / 0.15) * (1 - smooth01((t - 1.2) / 0.7))
    y = y + 0.35 * clap + 0.15 * wash / (np.max(np.abs(wash)) + 1e-12)
    return room(fade(y, fout=0.25), 0.25, rt=0.9)


def sfx_clash(r):
    """두 기운이 맞부딪힘: 맥놀이하는 불협 음 + 지지직 튀는 잔 불꽃 + 우르릉, 한동안 버틴다."""
    n = nsamp(1.4)
    t = tvec(n)
    env = smooth01(t / 0.03) * (1 - smooth01((t - 1.0) / 0.4))
    y = np.zeros(n)
    for f, a in ((330, 0.4), (349, 0.4), (660, 0.2), (698, 0.2)):
        y += a * np.sin(TAU * f * t + r.uniform(0, TAU))
    y *= env * (0.7 + 0.3 * np.sin(TAU * 13 * t))
    crack = np.zeros(n)
    times = np.cumsum(r.exponential(1 / 70, 200))
    for tm in times[times < 1.3]:
        place(crack, burst(nsamp(0.012), r, r.uniform(0.0008, 0.003), ('bp', r.uniform(2000, 8000), 1.5),
                           amp=r.uniform(0.3, 1.0)), nsamp(tm))
    buzz = filt(band_saw(TAU * 110 * t, np.full(n, 110.0), kmax=30), ('bp', 1000, 1.0))
    flick = np.clip(filt(white(n, r), ('lp', 30, 0.7)) * 8, 0, 1)
    br = np.cumsum(white(n, r))
    br = filt(br - np.mean(br), ('lp', 180, 0.7), ('hp', 25, 0.7))
    y += 0.6 * crack * env + 0.15 * buzz / (np.max(np.abs(buzz)) + 1e-12) * flick * env
    y += 0.5 * br / (np.max(np.abs(br)) + 1e-12) * env
    return room(y, 0.15)


def sfx_finisher(r):
    """마무리 일격: '쾅' 하자마자 큰 징이 길게 운다."""
    n = nsamp(2.8)
    y = np.zeros(n)
    hitn = nsamp(1.0)
    h = exciter(impact(hitn, r, ring=0.2), 0.45)
    place(y, np.tanh(1.4 * h / np.max(np.abs(h))), 0)
    g = jing(r, 1.0, f0=150, length=(n - nsamp(0.04)) / SR)
    place(y, 0.75 * g / np.max(np.abs(g)), nsamp(0.04))
    return room(fade(y, fout=0.4), 0.2, rt=0.8)


def sfx_terrain_gong(r):
    """지형 징(작은 징): 밝게 '징~'."""
    n = nsamp(2.0)
    parts = [(1.0, 1.0, 1.6), (1.011, 0.7, 1.4), (2.02, 0.5, 1.0), (2.04, 0.3, 0.9), (2.95, 0.3, 0.7),
             (3.9, 0.22, 0.5), (5.0, 0.15, 0.35), (6.2, 0.1, 0.25)]
    y = gong_partials(r, 240, n, parts, glide=0.02, att=0.004)
    y += burst(n, r, 0.004, ('bp', 2500, 0.8), amp=0.3)
    return room(fade(y, fout=0.3), 0.15)


def sfx_terrain_mine(r):
    """지뢰 폭발: 낮은 '쾅' + 막혀 가는 폭발 잡음 + 흩어지는 파편."""
    n = nsamp(1.6)
    t = tvec(n)
    f = 50 + 65 * np.exp(-t / 0.08)
    y = 0.45 * np.sin(phase_of(f)) * np.exp(-t / 0.35) * (1 - np.exp(-t / 0.002))
    y += modal(n, [(210, 0.5, 0.1), (400, 0.8, 0.07), (720, 0.6, 0.05), (1200, 0.3, 0.03)])

    def g(tt, ff):
        fc = 300 + 9000 * np.exp(-np.maximum(tt, 0) / 0.18)
        return 1 / (1 + (ff / fc) ** 4)

    ex = stft_filter(white(n, r), g) * np.exp(-t / 0.4)
    y += 0.9 * ex / (np.max(np.abs(ex)) + 1e-12)
    for _ in range(30):
        place(y, burst(nsamp(0.02), r, 0.003, ('bp', r.uniform(1200, 5000), 1.5), amp=r.uniform(0.1, 0.4)),
              nsamp(r.uniform(0.08, 1.0)))
    y = exciter(y, 0.8)
    y = np.tanh(1.7 * y / np.max(np.abs(y)))
    return room(fade(y, fout=0.3), 0.2, rt=0.8)


def sfx_slide(r):
    """알이 판 위를 미끄러짐(2초 반복): 오돌토돌한 마찰 잡음. 잡음·출렁임 모두 정확히 2초 주기라 이음매가 없다."""
    n = nsamp(2.0)
    grit = periodic_noise(n, r, lambda f: np.exp(-0.5 * (np.log2(np.maximum(f, 1) / 2600) / 1.0) ** 2))
    rumble = periodic_noise(n, r, lambda f: np.exp(-0.5 * (np.log2(np.maximum(f, 1) / 260) / 0.7) ** 2))
    rough = periodic_noise(n, r, lambda f: ((f > 15) & (f < 70)).astype(float))
    am = 0.75 + 0.25 * np.tanh(rough)
    tn = np.arange(n) / n
    slow = 0.9 + 0.1 * np.sin(TAU * 2 * tn) * np.sin(TAU * 3 * tn + 1)
    return (grit * am * 0.8 + 0.45 * rumble) * slow


def sfx_ui_tap(r):
    """누름: 부드러운 나무 '톡'."""
    n = nsamp(0.08)
    y = modal(n, [(1850, 1, 0.012), (3300, 0.4, 0.006), (950, 0.3, 0.01)])
    y += burst(n, r, 0.0015, ('bp', 3000, 0.8), amp=0.3)
    return y


def sfx_ui_back(r):
    """돌아가기: 내려가는 나무 두 번 '톡·톡'."""
    n = nsamp(0.16)
    y = np.zeros(n)
    place(y, modal(nsamp(0.06), [(1500, 1, 0.012), (2700, 0.35, 0.006)]), 0)
    place(y, 0.8 * modal(nsamp(0.08), [(1150, 1, 0.015), (2100, 0.35, 0.007)]), nsamp(0.055))
    return y


def sfx_ui_open(r):
    """창 열기: 가볍게 '휙' 열리며 맑은 울림 하나."""
    n = nsamp(0.4)
    t = tvec(n)
    y = sweep_noise(n, r, 800, (0.6, 3500), 3000, q=1.5, env=np.sin(np.pi * np.clip(t / 0.3, 0, 1)) ** 2) * 0.6
    place(y, modal(nsamp(0.28), [(1320, 0.5, 0.1), (2640, 0.15, 0.05)]), nsamp(0.1))
    return y


def sfx_coin(r):
    """엽전 몇 닢이 짤랑."""
    n = nsamp(0.65)
    y = np.zeros(n)
    for at in (0.0, 0.07, 0.12, 0.21):
        f0 = r.uniform(2600, 3400)
        parts = [(f0 * q, a, d) for q, a, d in ((1, 1, 0.25), (1.58, 0.7, 0.2), (2.35, 0.5, 0.15),
                                                  (3.2, 0.35, 0.1), (4.1, 0.2, 0.07))]
        c = modal(nsamp(0.4), parts) + burst(nsamp(0.4), r, 0.0015, ('hp', 5000, 0.7), amp=0.4)
        place(y, c * r.uniform(0.6, 1.0), nsamp(at))
    return room(y, 0.12)


def sfx_reward(r):
    """보상 반짝임: 오음계로 빠르게 오르는 방울 소리 + 높은 반짝 잡음."""
    n = nsamp(0.9)
    t = tvec(n)
    y = np.zeros(n)
    for i, f in enumerate((1046.5, 1174.7, 1396.9, 1568.0, 1760.0, 2093.0, 2349.3)):
        place(y, modal(nsamp(0.45), [(f, 0.6, 0.28), (f * 2.76, 0.18, 0.08), (f * 5.4, 0.06, 0.03)]), nsamp(i * 0.035))
    y += 0.08 * filt(white(n, r), ('hp', 6000, 0.7)) * np.exp(-t / 0.25) * smooth01(t / 0.03)
    return room(y, 0.15)


def sfx_star(r):
    """별 하나: 맑게 한 번 '딩'(별 개수만큼 1~3번 울린다)."""
    n = nsamp(0.9)
    y = modal(n, [(1760, 1, 0.6), (1765, 0.5, 0.55), (4860, 0.35, 0.25), (9500, 0.15, 0.1)])
    y += burst(n, r, 0.0012, ('hp', 5000, 0.7), amp=0.3)
    return room(y, 0.12)


def sfx_unlock(r):
    """잠금 풀림: 쇠 걸쇠 '찰칵' 두 번 + 올라가는 두 음."""
    n = nsamp(0.75)
    y = np.zeros(n)
    for at, f in ((0.0, 4200), (0.06, 3500)):
        place(y, burst(nsamp(0.03), r, 0.004, ('bp', f, 2.0), amp=0.7) + modal(nsamp(0.03), [(f * 0.6, 0.3, 0.008)]),
              nsamp(at))
    for at, f in ((0.12, 1318.5), (0.24, 1975.5)):
        place(y, modal(nsamp(0.5), [(f, 0.6, 0.3), (f * 2.0, 0.15, 0.12), (f * 3.0, 0.06, 0.06)]), nsamp(at))
    return room(y, 0.12)


def sfx_error(r):
    """안 됨: 낮고 부드러운 '부부' 두 번."""
    n = nsamp(0.4)
    t = tvec(n)
    y = np.zeros(n)
    for at in (0.0, 0.2):
        k = nsamp(0.14)
        tk = tvec(k)
        sq = sum(np.sin(TAU * 220 * h * tk) / h for h in (1, 3, 5, 7))
        env = smooth01(tk / 0.01) * (1 - smooth01((tk - 0.11) / 0.03))
        place(y, sq * env, nsamp(at))
    return filt(y, ('lp', 1400, 0.7))


def sfx_tutorial_ok(r):
    """잘했어요: 솔-도-미 맑은 방울 셋 + 가야금 한 줄."""
    n = nsamp(0.95)
    y = np.zeros(n)
    for i, f in enumerate((783.99, 1046.5, 1318.5)):
        place(y, modal(nsamp(0.6), [(f, 0.6, 0.35), (f * 2.0, 0.2, 0.15), (f * 3.0, 0.08, 0.08)]), nsamp(i * 0.09))
    g = gayageum_note(1318.5 / 2, 0.5, 0.7, '', r)
    place(y, 0.5 * g / np.max(np.abs(g)), nsamp(0.18))
    return room(y, 0.15)


def sfx_whoosh(r):
    """빠르게 휘두름: '휙'."""
    n = nsamp(0.3)
    t = tvec(n)
    return sweep_noise(n, r, 400, (0.45, 2500), 600, q=1.3, env=np.sin(np.pi * t / t[-1]) ** 2)


def sfx_countdown(r):
    """초읽기: 장구 채편 테두리 '똑' + 짧은 높은 음."""
    n = nsamp(0.18)
    y = 0.8 * janggu_deok(r, 0.6)[:n]
    t = tvec(n)
    y += 0.25 * np.sin(TAU * 1046.5 * t) * np.exp(-t / 0.05) * (1 - np.exp(-t / 0.002))
    return fade(y, fout=0.03)


def sfx_go(r):
    """시작!: 징과 북이 한 번에, 태평소가 짧게 '빠아~'."""
    n = nsamp(1.4)
    y = np.zeros(n)
    g = jing(r, 1.0, f0=200, length=1.4)
    y += 0.6 * g / np.max(np.abs(g))
    b = buk(r, 1.0)
    place(y, 0.8 * b / np.max(np.abs(b)), 0)
    tp = render_phrase('taepyeongso', [(0.0, 0.12, 79, 0.9, ''), (0.12, 0.55, 84, 1.0, 'v')], r)
    place(y, 0.55 * tp / np.max(np.abs(tp)), nsamp(0.02))
    return room(fade(y, fout=0.3), 0.15)


def sfx_clash_ready(r):
    """내공 겨루기 준비(2.2초): 낮게 깔리는 울림이 차오르고, 북이 심장처럼 두 번씩 뛰며 빨라진다."""
    n = nsamp(2.2)
    t = tvec(n)
    y = np.zeros(n)
    # 낮은 울림: 55Hz 와 58Hz 가 맥놀이하며 커진다.
    swell = smooth01(t / 1.9)
    drone = (np.sin(TAU * 55 * t) + 0.8 * np.sin(TAU * 58.3 * t + 1.0) + 0.3 * np.sin(TAU * 110 * t))
    y += 0.35 * drone * swell
    # 올라가는 바람(쉬익).
    y += 0.5 * sweep_noise(n, r, 200, (1.95, 3000), 2500, q=1.4, env=swell ** 2)
    # 심장 박동: 쿵-쿵, 간격이 줄어든다.
    for tm in (0.05, 0.75, 1.3, 1.72, 2.02):
        b = buk(r, 0.9)
        place(y, 0.9 * b / np.max(np.abs(b)), nsamp(tm))
        b2 = buk(r, 0.6)
        place(y, 0.5 * b2 / np.max(np.abs(b2)), nsamp(tm + 0.16))
    return room(fade(y, fout=0.05), 0.18, rt=0.9)


def sfx_clash_beat(r):
    """셋·둘·하나: 큰 북 한 번 + 막힌 꽹과리."""
    n = nsamp(0.7)
    y = np.zeros(n)
    b = buk(r, 1.0)
    place(y, b / np.max(np.abs(b)), 0)
    k = kkwaeng(r, 0.7, damped=True)
    place(y, 0.35 * k / np.max(np.abs(k)), 0)
    return room(fade(y, fout=0.2), 0.15, rt=0.7)


def sfx_clash_tap(r):
    """연타 한 번: 짧고 단단한 기운 부딪힘 '탁'."""
    n = nsamp(0.14)
    t = tvec(n)
    y = burst(n, r, 0.012, ('bp', 1800, 1.0), amp=1.0)
    y += 0.6 * np.sin(TAU * 140 * t) * np.exp(-t / 0.03)
    return fade(y, fout=0.04)


def sfx_clash_win(r):
    """겨루기 이김: 쾅 + 높은 징."""
    n = nsamp(1.6)
    y = np.zeros(n)
    h = exciter(impact(nsamp(0.8), r, ring=0.25), 0.45)
    place(y, np.tanh(1.3 * h / np.max(np.abs(h))), 0)
    g = jing(r, 1.0, f0=240, length=1.5)
    place(y, 0.6 * g / np.max(np.abs(g)), nsamp(0.03))
    return room(fade(y, fout=0.35), 0.18, rt=0.8)


def sfx_clash_lose(r):
    """겨루기 밀림: 둔하게 '퉁' 하고 낮게 꺼진다."""
    n = nsamp(1.0)
    t = tvec(n)
    y = np.zeros(n)
    b = buk(r, 0.8)
    place(y, b / np.max(np.abs(b)), 0)
    f = 180 * np.exp(-t / 0.4) + 60
    y += 0.4 * np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / 0.35)
    return room(fade(y, fout=0.3), 0.15, rt=0.7)


LOOP_SFX = {'slide'}  # 반복 재생되는 효과음

# 이름 → (만들기, 꼭대기 dBFS, 펀치 dB)
SFX = {
    'touch': (sfx_touch, -3.0, 0.0), 'hit_cheongok': (sfx_hit_cheongok, -1.5, 1.0),
    'hit_wood': (sfx_hit_wood, -1.5, 1.0), 'hit_hyeoncheol': (sfx_hit_hyeoncheol, -1.5, 1.5),
    'hit_ice': (sfx_hit_ice, -1.5, 1.0), 'critical': (sfx_critical, -1.5, 2.0),
    'inner': (sfx_inner, -2.0, 1.0), 'tech_swordQi': (sfx_tech_swordQi, -1.5, 1.5),
    'tech_stomp': (sfx_tech_stomp, -1.5, 2.0), 'tech_taiji': (sfx_tech_taiji, -2.0, 1.0),
    'tech_clone': (sfx_tech_clone, -2.0, 1.0), 'tech_absorb': (sfx_tech_absorb, -2.0, 1.0),
    'ultimate': (sfx_ultimate, -1.5, 2.5), 'out_thud': (sfx_out_thud, -1.5, 1.5),
    'out_crowd': (sfx_out_crowd, -2.0, 2.0), 'clash': (sfx_clash, -1.5, 1.5),
    'finisher': (sfx_finisher, -1.5, 2.0), 'terrain_gong': (sfx_terrain_gong, -1.5, 1.0),
    'terrain_mine': (sfx_terrain_mine, -1.5, 2.5), 'slide': (sfx_slide, -3.0, 0.0),
    'ui_tap': (sfx_ui_tap, -3.0, 0.0), 'ui_back': (sfx_ui_back, -3.0, 0.0),
    'ui_open': (sfx_ui_open, -3.0, 0.0), 'coin': (sfx_coin, -2.0, 0.5),
    'reward': (sfx_reward, -2.0, 0.5), 'star': (sfx_star, -2.0, 0.5),
    'unlock': (sfx_unlock, -2.0, 0.5), 'error': (sfx_error, -3.0, 0.0),
    'tutorial_ok': (sfx_tutorial_ok, -2.0, 0.5), 'whoosh': (sfx_whoosh, -2.5, 0.5),
    'countdown': (sfx_countdown, -3.0, 0.0), 'go': (sfx_go, -1.5, 1.5),
    'clash_ready': (sfx_clash_ready, -1.5, 1.5), 'clash_beat': (sfx_clash_beat, -1.5, 1.5),
    'clash_tap': (sfx_clash_tap, -3.0, 0.5), 'clash_win': (sfx_clash_win, -1.5, 2.0),
    'clash_lose': (sfx_clash_lose, -2.0, 1.0),
}


# ════════════════════════════════════════════════════════════════════
# 7. 인코딩 · 디코딩 · 측정
# ════════════════════════════════════════════════════════════════════

def encode(path, x, q):
    x = np.ascontiguousarray(x, dtype=np.float32)
    ch = 1 if x.ndim == 1 else x.shape[1]
    cmd = [FFMPEG, '-hide_banner', '-loglevel', 'error', '-y', '-f', 'f32le', '-ar', str(SR), '-ac', str(ch),
           '-i', 'pipe:0', '-fflags', '+bitexact', '-flags:a', '+bitexact', '-map_metadata', '-1',
           '-c:a', 'libvorbis', '-q:a', str(q), path]
    subprocess.run(cmd, input=x.tobytes(), check=True)


def decode(path, ch, expect_len, ref=None):
    """ffmpeg 로 다시 풀어 본다.

    ffmpeg 기본 Vorbis 디코더는 (컨테이너 길이는 정확한데도) 일부 파일에서 맨 끝 128 표본을 덜
    내놓는 버릇이 있다. 그래서 끝 자르기를 끈 디코드(skip_manual)도 받아, 원본과 맞춰 본 시작점부터
    컨테이너 길이(=원본 길이)만큼 잘라 쓴다 — granule 위치를 지키는 실제 재생기와 같은 결과.
    반환: (표본, 기본 디코드 성공 여부, 기본 디코드 길이, 오류 문자열)
    """
    p1 = subprocess.run([FFMPEG, '-v', 'error', '-i', path, '-f', 'f32le', '-ac', str(ch), 'pipe:1'],
                        capture_output=True)
    err = p1.stderr.decode('utf-8', 'replace').strip()
    y1 = np.frombuffer(p1.stdout, np.float32).reshape(-1, ch)
    if len(y1) == expect_len:
        return y1, p1.returncode == 0 and not err, len(y1), err
    p2 = subprocess.run([FFMPEG, '-v', 'error', '-flags2', '+skip_manual', '-i', path, '-f', 'f32le',
                         '-ac', str(ch), 'pipe:1'], capture_output=True)
    y2 = np.frombuffer(p2.stdout, np.float32).reshape(-1, ch)
    K = max(64, min(4096, len(y1) // 2))
    a = y1[:K, 0].astype(np.float64)
    best, bo = 1e9, 0
    for o in range(0, max(1, min(4096, len(y2) - K))):
        e = np.mean((y2[o: o + K, 0] - a) ** 2)
        if e < best:
            best, bo = e, o
    y = y2[bo: bo + expect_len]
    return y, p1.returncode == 0 and not err and len(y) == expect_len, len(y1), err


def ebur128(path):
    p = subprocess.run([FFMPEG, '-hide_banner', '-nostats', '-i', path, '-af', 'ebur128=peak=true',
                        '-f', 'null', '-'], capture_output=True, text=True)
    out = p.stderr
    summ = out[out.rfind('Summary:'):]
    mi = re.search(r'I:\s+(-?[\d.]+|-inf)\s+LUFS', summ)
    mp = re.search(r'Peak:\s+(-?[\d.]+|-inf)\s+dBFS', summ)
    return (float(mi.group(1)) if mi else float('nan'), float(mp.group(1)) if mp else float('nan'))


def container_samples(path):
    p = subprocess.run([FFPROBE, '-v', 'error', '-select_streams', 'a:0', '-show_entries', 'stream=duration_ts',
                        '-of', 'csv=p=0', path], capture_output=True, text=True)
    try:
        return int(p.stdout.strip())
    except ValueError:
        return -1


def seam_metrics(y, x):
    """반복 이음매 측정(y = 다시 푼 소리, x = 인코딩 전 소리).

    - 끝→처음 표본 차: 다시 푼 것 vs 인코딩 전(인코딩 전 값은 반복이 이어질 때 원래 있는 자연스러운 변화)
      그리고 그 차가 곡 안 이웃 표본 차 분포에서 몇 백분위인지
    - 이음매 둘레 10 ms 실효값 vs 주변 10 ms 창들(±250 ms)
    - 인코딩 오차(y-x)의 이음매 10 ms 실효값 vs 곡 전체 10 ms 창 오차의 중앙값 — 이음매에서만 깨지면 크게 튄다
    """
    d = np.abs(np.diff(y, axis=0)).max(axis=1)
    jump = float(np.max(np.abs(y[-1] - y[0])))
    jump_src = float(np.max(np.abs(x[-1] - x[0])))
    pct = float(np.mean(d < jump) * 100)
    w = nsamp(0.005)

    def ring(a, k):  # 이음매를 가운데 둔 2k 표본
        return np.concatenate([a[-k:], a[:k]])

    rs = math.sqrt(np.mean(ring(y, w) ** 2))
    neigh = []
    c = nsamp(0.6)
    yy = ring(y, c)
    for off in range(-25, 26):
        if abs(off) < 2:
            continue
        a0 = c + off * 2 * w - w
        neigh.append(math.sqrt(np.mean(yy[a0: a0 + 2 * w] ** 2)))
    nm = float(np.mean(neigh))
    e = y - x
    seam_err = math.sqrt(np.mean(ring(e, w) ** 2))
    nwin = len(e) // (2 * w)
    errs = np.sqrt(np.mean(e[: nwin * 2 * w].reshape(nwin, 2 * w, -1) ** 2, axis=(1, 2)))
    db = lambda v: 20 * math.log10(v + 1e-12)
    return dict(jump=jump, jump_src=jump_src, p99=float(np.percentile(d, 99)), p50=float(np.median(d)), pct=pct,
                seam_rms_db=db(rs), neigh_db=db(nm), neigh_min_db=db(min(neigh)), neigh_max_db=db(max(neigh)),
                err_seam_db=db(seam_err), err_med_db=db(float(np.median(errs))), err_p95_db=db(float(np.percentile(errs, 95))))


def spectrum_summary(y):
    mono = y.mean(axis=1) if y.ndim == 2 else y
    X = np.abs(np.fft.rfft(mono * np.hanning(len(mono)))) ** 2
    f = np.fft.rfftfreq(len(mono), 1 / SR)
    tot = X.sum() + 1e-20
    cen = float((X * f).sum() / tot)
    bands = [(0, 200), (200, 2000), (2000, 8000), (8000, SR / 2)]
    return cen, [float(X[(f >= a) & (f < b)].sum() / tot * 100) for a, b in bands]


# ════════════════════════════════════════════════════════════════════
# 8. 만들기
# ════════════════════════════════════════════════════════════════════

def build(job):
    """소리 하나를 만들어 ogg 로 쓰고 측정값을 돌려준다(프로세스마다 따로 돈다)."""
    kind, name = job
    t0 = time.time()
    path = os.path.join(OUT_DIR, name + '.ogg')
    info = {'name': name, 'kind': kind}
    if kind in ('music', 'jingle'):
        fn = {f.__name__: f for f in MUSIC + JINGLES}[name]
        song = fn()
        raw, levels = render_song(song)
        info['stems'] = levels
        target = -18.0 if kind == 'music' else -16.0
        ceiling, q = -1.5, (3 if kind == 'music' else 4)
        circ = kind == 'music'
        mk = lambda c: master_music(raw, target, c, circ)
    else:
        fn, pk, drive = SFX[name]
        raw = fn(rng_for(name))
        ceiling, q = pk, 4
        mk = lambda c: master_sfx(raw, pk, drive, c, circular=(name in LOOP_SFX))
    ch = 1 if raw.ndim == 1 else raw.shape[1]
    for attempt in range(5):
        x = mk(ceiling)
        encode(path, x, q)
        y, ok, dlen, err = decode(path, ch, len(x))
        peak = 20 * math.log10(float(np.max(np.abs(y))) + 1e-12)
        lf, tp = ebur128(path)
        worst = max(peak, tp)  # 다시 푼 표본 최대치와 ffmpeg 참 최대치(true peak) 둘 다 -1 dBFS 아래로
        if worst <= -1.0 - 0.05:
            break
        ceiling -= (worst + 1.0) + 0.3  # Vorbis 가 꼭대기를 살짝 넘길 수 있다 → 천장을 낮춰 다시
    xs = (x if x.ndim == 2 else x[:, None]).astype(np.float32).astype(np.float64)
    info['snr'] = 10 * math.log10(np.sum(xs ** 2) / (np.sum((y.astype(np.float64) - xs) ** 2) + 1e-20))
    info.update(dur=len(x) / SR, ch=ch, peak=peak, ceiling=ceiling, attempts=attempt + 1,
                lufs_py=lufs(y.astype(np.float64)), decode_ok=ok, decode_len_default=dlen,
                container_len=container_samples(path), expect_len=len(x), err=err,
                size=os.path.getsize(path))
    info['lufs_ff'], info['tp_ff'] = lf, tp
    info['cen'], info['bands'] = spectrum_summary(y.astype(np.float64))
    if kind == 'music' or name == 'slide':
        info['seam'] = seam_metrics(y.astype(np.float64), (x if x.ndim == 2 else x[:, None]).astype(np.float32).astype(np.float64))
    info['secs'] = time.time() - t0
    return info


def main():
    args = sys.argv[1:]
    only = None
    jobs_n = min(4, os.cpu_count() or 1)
    if '--only' in args:
        only = set(args[args.index('--only') + 1].split(','))
    if '--jobs' in args:
        jobs_n = int(args[args.index('--jobs') + 1])
    os.makedirs(OUT_DIR, exist_ok=True)
    jobs = [('music', f.__name__) for f in MUSIC] + [('jingle', f.__name__) for f in JINGLES]
    jobs += [('sfx', k) for k in SFX]
    if only:
        jobs = [j for j in jobs if j[1] in only]
    t0 = time.time()
    if jobs_n > 1:
        with ProcessPoolExecutor(max_workers=jobs_n) as ex:
            results = list(ex.map(build, jobs))
    else:
        results = [build(j) for j in jobs]
    total = time.time() - t0

    print('\n%-18s %-6s %6s %4s %8s %8s %8s %8s %6s %7s  %s' % (
        '이름', '종류', '길이s', '채널', '최대dBFS', 'LUFS(ff)', 'TP(ff)', 'LUFS(py)', 'KB', '중심Hz',
        '대역%(<200/<2k/<8k/>8k)'))
    for i in results:
        lf = 'n/a' if i['lufs_ff'] <= -69.9 else '%.1f' % i['lufs_ff']
        lp = 'n/a' if i['lufs_py'] <= -69.9 else '%.1f' % i['lufs_py']
        print('%-18s %-6s %6.2f %4d %8.2f %8s %8.2f %8s %6.0f %7.0f  %s%s' % (
            i['name'], i['kind'], i['dur'], i['ch'], i['peak'], lf, i['tp_ff'], lp,
            i['size'] / 1024, i['cen'], '/'.join('%.0f' % b for b in i['bands']),
            '' if i['decode_ok'] else '  ⚠ 디코드 확인필요(%s)' % i['err']))
    print('\n[디코드·길이] (원본 표본 수 / 컨테이너 표본 수 / ffmpeg 기본 디코더가 내놓은 수) · SNR = 인코딩 전 대비 다시 푼 소리의 신호대오차')
    for i in results:
        flag = '' if i['container_len'] == i['expect_len'] else '  ⚠ 컨테이너 길이 다름'
        dd = i['expect_len'] - i['decode_len_default']
        note = '' if dd == 0 else '  (기본 디코더가 %d 표본 %s 냄 — 정렬 디코드로 측정)' % (abs(dd), '덜' if dd > 0 else '더')
        print('  %-18s %8d / %8d / %8d  SNR %5.1f dB  시도 %d  천장 %.2f dB%s%s' % (
            i['name'], i['expect_len'], i['container_len'], i['decode_len_default'], i['snr'], i['attempts'],
            i['ceiling'],
            flag, note))
    print('\n[반복 이음매] 끝→처음 표본 차(다시 푼 것 / 인코딩 전) · 곡 안 이웃 표본 차 중앙값·99백분위 · 그 차의 백분위 ·'
          ' 이음매 10ms 실효값 vs 주변 ±250ms 의 10ms 창(평균·최소~최대) · 인코딩 오차 10ms: 이음매 vs 곡 전체 중앙값(95%)')
    for i in results:
        if 'seam' in i:
            s = i['seam']
            print('  %-18s 차 %.5f / %.5f (중앙 %.5f · 99%% %.5f · %.1f백분위)  실효 %.1f dB vs %.1f dB (%.1f~%.1f)'
                  '  오차 %.1f dB vs %.1f dB (%.1f)' % (
                      i['name'], s['jump'], s['jump_src'], s['p50'], s['p99'], s['pct'], s['seam_rms_db'],
                      s['neigh_db'], s['neigh_min_db'], s['neigh_max_db'], s['err_seam_db'], s['err_med_db'],
                      s['err_p95_db']))
    print('\n[줄기 음량] 악기 줄기의 문턱 음량(LUFS, 소리 나는 구간 기준) → 맞춘 목표(LU, 섞기 전 상대값)')
    for i in results:
        if 'stems' in i:
            print('  %-18s %s' % (i['name'], '  '.join('%s %.1f→%.0f' % (k, v[0], v[1])
                                                       for k, v in sorted(i['stems'].items()))))
    size = sum(os.path.getsize(os.path.join(OUT_DIR, f)) for f in os.listdir(OUT_DIR) if f.endswith('.ogg'))
    print('\nogg 합계 %.2f MB (%d 파일) · 걸린 시간 %.1f 초 (작업 %d 개 동시)' % (
        size / 1048576, len([f for f in os.listdir(OUT_DIR) if f.endswith('.ogg')]), total, jobs_n))
    print('파일별 만들기 시간(초): ' + ', '.join('%s %.1f' % (i['name'], i['secs']) for i in results))


if __name__ == '__main__':
    main()
