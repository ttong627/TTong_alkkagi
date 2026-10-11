// 효과음·배경 음악을 직접 합성해 assets/sounds/ 에 WAV 로 쓴다(설계서 §16.5 — 저작권 걱정 없게).
//
// 실행: dart run tool/make_sounds.dart   (같은 씨앗이라 몇 번 돌려도 같은 파일이 나온다)
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int rate = 22050;
const String outDir = 'assets/sounds';
final _r = math.Random(20261011);

typedef Buf = Float64List;

Buf buf(double seconds) => Float64List((seconds * rate).round());

double noise() => _r.nextDouble() * 2 - 1;

/// 빠르게 사라지는 지수 꼬리.
double env(double t, double decay) => math.exp(-t / decay);

/// 처음 [a] 초 동안 올라오는 문턱.
double attack(double t, double a) => t >= a ? 1 : t / a;

/// 맑은 쇳소리·옥 소리: 배음마다 따로 사라지는 사인.
Buf bell(
  double seconds,
  List<(double freq, double amp, double decay)> partials, {
  double att = 0.002,
}) {
  final b = buf(seconds);
  for (var i = 0; i < b.length; i++) {
    final t = i / rate;
    var v = 0.0;
    for (final (f, a, d) in partials) {
      v += a * math.sin(2 * math.pi * f * t) * env(t, d);
    }
    b[i] = v * attack(t, att);
  }
  return b;
}

/// 한 극 저역 통과(부드럽게).
Buf lowpass(Buf x, double cutoff) {
  final a = 1 - math.exp(-2 * math.pi * cutoff / rate);
  final y = Float64List(x.length);
  var s = 0.0;
  for (var i = 0; i < x.length; i++) {
    s += a * (x[i] - s);
    y[i] = s;
  }
  return y;
}

Buf highpass(Buf x, double cutoff) {
  final lp = lowpass(x, cutoff);
  return Float64List.fromList([
    for (var i = 0; i < x.length; i++) x[i] - lp[i],
  ]);
}

/// 띠 통과(저역 통과 두 번의 차).
Buf band(Buf x, double lo, double hi) => highpass(lowpass(x, hi), lo);

Buf noiseBuf(double seconds, double decay, {double att = 0.001}) {
  final b = buf(seconds);
  for (var i = 0; i < b.length; i++) {
    final t = i / rate;
    b[i] = noise() * env(t, decay) * attack(t, att);
  }
  return b;
}

/// 음높이가 [f0] 에서 [f1] 로 미끄러지는 북·쿵 소리.
Buf thump(double seconds, double f0, double f1, double decay) {
  final b = buf(seconds);
  var ph = 0.0;
  for (var i = 0; i < b.length; i++) {
    final t = i / rate;
    final f = f1 + (f0 - f1) * math.exp(-t / 0.04);
    ph += 2 * math.pi * f / rate;
    b[i] = math.sin(ph) * env(t, decay) * attack(t, 0.002);
  }
  return b;
}

Buf mix(List<(Buf, double)> parts, {double offset = 0}) {
  final n = parts.map((p) => p.$1.length).reduce(math.max);
  final y = Float64List(n);
  for (final (x, g) in parts) {
    for (var i = 0; i < x.length; i++) {
      y[i] += x[i] * g;
    }
  }
  return y;
}

/// [x] 를 [at] 초 뒤에 [into] 에 더한다.
void addAt(Buf into, Buf x, double at, [double g = 1]) {
  final o = (at * rate).round();
  for (var i = 0; i < x.length && o + i < into.length; i++) {
    into[o + i] += x[i] * g;
  }
}

/// 가장 큰 값이 [peak] 가 되게.
Buf normalize(Buf x, [double peak = 0.9]) {
  var m = 1e-9;
  for (final v in x) {
    m = math.max(m, v.abs());
  }
  return Float64List.fromList([for (final v in x) v / m * peak]);
}

/// 끝 [fade] 초를 줄여 딸깍 소리 없애기.
Buf fadeOut(Buf x, [double fade = 0.01]) {
  final n = (fade * rate).round();
  for (var i = 0; i < n && i < x.length; i++) {
    x[x.length - 1 - i] *= i / n;
  }
  return x;
}

/// 뜯는 현(가야금·거문고): Karplus–Strong.
Buf pluck(
  double freq,
  double seconds, {
  double damp = 0.996,
  double bright = 0.5,
}) {
  final p = math.max(2, (rate / freq).round());
  final line = Float64List.fromList([
    for (var i = 0; i < p; i++)
      noise() * (1 - bright) + (i < p / 2 ? bright : -bright),
  ]);
  final b = buf(seconds);
  var idx = 0;
  for (var i = 0; i < b.length; i++) {
    final cur = line[idx];
    final next = line[(idx + 1) % p];
    line[idx] = damp * 0.5 * (cur + next);
    b[i] = cur;
    idx = (idx + 1) % p;
  }
  return fadeOut(b, 0.02);
}

/// 활로 켜는 소리(해금): 떨림 있는 톱니를 부드럽게.
Buf bowed(double freq, double seconds, {double vib = 5.5}) {
  final b = buf(seconds);
  var ph = 0.0;
  for (var i = 0; i < b.length; i++) {
    final t = i / rate;
    final f =
        freq * (1 + 0.012 * math.sin(2 * math.pi * vib * t) * attack(t, 0.25));
    ph += f / rate;
    final saw = 2 * (ph - ph.floorToDouble()) - 1;
    b[i] =
        saw * attack(t, 0.08) * (t > seconds - 0.08 ? (seconds - t) / 0.08 : 1);
  }
  return lowpass(b, 1800);
}

/// 부는 소리(대금·태평소): 사인 + 숨소리, [nasal] 이면 네모파(태평소).
Buf blown(double freq, double seconds, {bool nasal = false}) {
  final b = buf(seconds);
  var ph = 0.0;
  for (var i = 0; i < b.length; i++) {
    final t = i / rate;
    final f =
        freq * (1 + 0.008 * math.sin(2 * math.pi * 5 * t) * attack(t, 0.3));
    ph += f / rate;
    final x = ph - ph.floorToDouble();
    final tone = nasal
        ? (x < 0.3 ? 1.0 : -0.45)
        : math.sin(2 * math.pi * x) + 0.25 * math.sin(4 * math.pi * x);
    final breath = noise() * (nasal ? 0.05 : 0.18);
    b[i] =
        (tone + breath) *
        attack(t, nasal ? 0.03 : 0.12) *
        (t > seconds - 0.1 ? (seconds - t) / 0.1 : 1);
  }
  return lowpass(b, nasal ? 3500 : 2500);
}

/// 북(장구·북): 낮은 쿵 + 가죽 잡음.
Buf drum(double f, {double decay = 0.25, double skin = 0.3}) => mix([
  (thump(0.6, f * 1.8, f, decay), 1),
  (lowpass(noiseBuf(0.15, 0.03), 1200), skin),
]);

/// 꽹과리: 높은 쇳소리 잡음.
Buf gong({double decay = 0.18}) => mix([
  (band(noiseBuf(0.5, decay), 2500, 7000), 0.9),
  (
    bell(0.5, [
      (3150, 0.4, decay),
      (4470, 0.3, decay * 0.8),
      (6020, 0.2, decay * 0.6),
    ]),
    1,
  ),
]);

// 우리 음계(평조 다섯 음): 황·태·중·임·남 ≈ 도·레·파·솔·라.
const pent = [261.6, 293.7, 349.2, 392.0, 440.0];
double note(int step, [int octave = 0]) {
  final o = step ~/ 5 + octave + (step < 0 && step % 5 != 0 ? -1 : 0);
  return pent[step % 5] * math.pow(2, o);
}

/// 배경 음악 한 마디 반복. [beats] 박, [bpm].
Buf loopTrack({
  required double bpm,
  required int beats,
  required void Function(Buf song, double beat) compose,
}) {
  final beat = 60 / bpm;
  final song = buf(beats * beat);
  compose(song, beat);
  // 끝과 처음을 부드럽게 잇는다.
  final n = (0.03 * rate).round();
  for (var i = 0; i < n; i++) {
    song[i] *= i / n;
    song[song.length - 1 - i] *= i / n;
  }
  return normalize(song, 0.7);
}

/// 장단(점 = 친다, 숫자 = 세기).
void rhythm(
  Buf song,
  double beat,
  List<double> pattern,
  Buf Function(double strength) hit, {
  double div = 2,
}) {
  final step = beat / div;
  final total = song.length / rate;
  var t = 0.0;
  var i = 0;
  while (t < total - 1e-6) {
    final s = pattern[i % pattern.length];
    if (s > 0) addAt(song, hit(s), t, s);
    t += step;
    i++;
  }
}

/// 가락: (박 위치, 음, 길이 박).
void melody(
  Buf song,
  double beat,
  List<(double at, int step, double len)> notes,
  Buf Function(double freq, double seconds) voice, {
  double gain = 1,
  int octave = 0,
}) {
  for (final (at, step, len) in notes) {
    addAt(song, voice(note(step, octave), len * beat), at * beat, gain);
  }
}

void writeWav(String name, Buf x) {
  final n = x.length;
  final data = ByteData(44 + n * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    data.setInt16(
      44 + i * 2,
      (x[i].clamp(-1.0, 1.0) * 32767).round(),
      Endian.little,
    );
  }
  File('$outDir/$name.wav')
    ..createSync(recursive: true)
    ..writeAsBytesSync(data.buffer.asUint8List());
  stdout.writeln(
    '$name.wav  ${(n / rate).toStringAsFixed(2)}초  ${(data.lengthInBytes / 1024).round()}KB',
  );
}

void sfx(String name, Buf x, [double peak = 0.9]) =>
    writeWav(name, fadeOut(normalize(x, peak)));

void main() {
  // --- 손끝·충돌 ---
  // 손끝 닿음: 짧고 마른 「딱」.
  sfx(
    'touch',
    mix([
      (highpass(noiseBuf(0.05, 0.006), 1500), 1),
      (bell(0.06, [(2400, 0.6, 0.012)]), 0.8),
    ]),
    0.8,
  );
  // 재질별 충돌: 청옥 「땅」·만년기주 「톡」·현철 「쿵」·빙백한옥 「칭」.
  sfx(
    'hit_cheongok',
    mix([
      (bell(0.4, [(1760, 1, 0.12), (4310, 0.5, 0.06), (6900, 0.25, 0.03)]), 1),
      (highpass(noiseBuf(0.03, 0.004), 2000), 0.5),
    ]),
  );
  sfx(
    'hit_wood',
    mix([
      (bell(0.15, [(620, 1, 0.035), (1480, 0.5, 0.02)]), 1),
      (band(noiseBuf(0.06, 0.01), 400, 2500), 0.7),
    ]),
  );
  sfx(
    'hit_hyeoncheol',
    mix([
      (thump(0.5, 220, 110, 0.16), 1),
      (bell(0.5, [(380, 0.5, 0.18), (930, 0.3, 0.1), (1610, 0.15, 0.06)]), 0.8),
      (lowpass(noiseBuf(0.08, 0.015), 900), 0.6),
    ]),
  );
  sfx(
    'hit_ice',
    mix([
      (bell(0.45, [(3150, 1, 0.14), (5230, 0.6, 0.09), (7480, 0.3, 0.05)]), 1),
      (highpass(noiseBuf(0.02, 0.003), 4000), 0.4),
    ]),
  );
  // 미끄러짐(반복): 낮은 마찰음.
  {
    final x = lowpass(lowpass(lowpass(noiseBuf(2.0, 1e9), 350), 350), 350);
    for (var i = 0; i < x.length; i++) {
      x[i] *= 0.7 + 0.3 * math.sin(2 * math.pi * 3 * i / rate);
    }
    final n = (0.05 * rate).round();
    for (var i = 0; i < n; i++) {
      x[i] *= i / n;
      x[x.length - 1 - i] *= i / n;
    }
    writeWav('slide', normalize(x, 0.6));
  }

  // --- 회심·내공·무공 ---
  sfx(
    'critical',
    bell(1.4, [
      (1318, 1, 0.5),
      (2637, 0.5, 0.35),
      (3951, 0.3, 0.2),
      (5274, 0.15, 0.12),
    ]),
  );
  sfx(
    'inner',
    mix([
      (drum(70, decay: 0.45, skin: 0.5), 1),
      (thump(0.8, 140, 55, 0.4), 0.7),
    ]),
  );
  {
    // 검기: 쇳소리가 위로 긁고 맑게 울림.
    final x = buf(0.7);
    var ph = 0.0;
    for (var i = 0; i < x.length; i++) {
      final t = i / rate;
      ph += 2 * math.pi * (2000 + 3000 * t / 0.7) / rate;
      x[i] = noise() * 0.4 * env(t, 0.15) + math.sin(ph) * 0.2 * env(t, 0.3);
    }
    sfx(
      'tech_swordQi',
      mix([
        (highpass(x, 1500), 1),
        (bell(0.7, [(3520, 0.6, 0.3), (5280, 0.3, 0.2)]), 0.8),
      ]),
    );
  }
  sfx(
    'tech_stomp',
    mix([
      (thump(1.0, 90, 38, 0.45), 1),
      (lowpass(noiseBuf(0.9, 0.3), 300), 0.8),
    ]),
  );
  {
    // 태극: 바람이 일었다 잦아듦.
    final x = band(noiseBuf(1.2, 1e9), 300, 2200);
    for (var i = 0; i < x.length; i++) {
      final t = i / rate;
      x[i] *= math.sin(math.pi * t / 1.2);
    }
    sfx('tech_taiji', x, 0.7);
  }
  {
    // 분신: 핑 소리가 잦아들며 되풀이(잔향).
    final x = buf(1.0);
    for (var k = 0; k < 5; k++) {
      addAt(
        x,
        bell(0.3, [(1568, 1, 0.08), (2349, 0.5, 0.05)]),
        k * 0.11,
        math.pow(0.6, k).toDouble(),
      );
    }
    sfx('tech_clone', x);
  }
  {
    // 흡성: 소리가 빨려 들어감(점점 커지며 높아지다 뚝).
    final x = buf(0.8);
    var ph = 0.0;
    for (var i = 0; i < x.length; i++) {
      final t = i / rate;
      ph += 2 * math.pi * (200 + 900 * t / 0.8) / rate;
      x[i] = (math.sin(ph) * 0.5 + noise() * 0.5) * math.pow(t / 0.8, 2);
    }
    sfx('tech_absorb', lowpass(x, 2500));
  }
  sfx(
    'ultimate',
    mix([
      (gong(decay: 0.6), 0.7),
      (drum(60, decay: 0.6, skin: 0.6), 1),
      (bell(1.5, [(659, 0.6, 0.6), (988, 0.4, 0.5)]), 0.6),
    ]),
  );

  // --- 장외: 흙바닥 「툭」 + 관중 「오오」 ---
  sfx(
    'out_thud',
    mix([
      (thump(0.3, 160, 70, 0.08), 1),
      (lowpass(noiseBuf(0.2, 0.04), 700), 0.7),
    ]),
  );
  {
    // 관중: 여러 목소리(톱니)를 「오」 꼴로 거른다.
    final x = buf(1.3);
    for (var v = 0; v < 10; v++) {
      final f0 = 140 + _r.nextDouble() * 110;
      final start = _r.nextDouble() * 0.15;
      var ph = 0.0;
      for (var i = 0; i < x.length; i++) {
        final t = i / rate - start;
        if (t < 0) continue;
        final f = f0 * (1 + 0.15 * math.sin(math.pi * math.min(t, 1.0)));
        ph += f / rate;
        final saw = 2 * (ph - ph.floorToDouble()) - 1;
        x[i] += saw * math.sin(math.pi * math.min(t / 1.1, 1.0)) * 0.1;
      }
    }
    sfx(
      'out_crowd',
      mix([(band(x, 300, 650), 1), (band(x, 700, 1100), 0.4)]),
      0.6,
    );
  }
  sfx('clash', mix([(gong(decay: 0.3), 1), (drum(90, decay: 0.3), 1)]));
  sfx(
    'finisher',
    mix([
      (gong(decay: 0.9), 0.8),
      (drum(55, decay: 0.8, skin: 0.7), 1),
      (bell(2.0, [(523, 0.5, 0.9), (784, 0.4, 0.8), (1046, 0.3, 0.6)]), 0.8),
    ]),
  );
  sfx(
    'terrain_gong',
    bell(1.6, [
      (196, 1, 0.9),
      (392, 0.6, 0.6),
      (588, 0.35, 0.4),
      (803, 0.25, 0.3),
    ]),
  );
  sfx(
    'terrain_mine',
    mix([
      (thump(0.9, 120, 40, 0.35), 1),
      (lowpass(noiseBuf(0.8, 0.25), 1500), 1),
    ]),
  );

  // --- 배경 음악: 장마다 국악 장단 짧은 반복 ---
  // 1장 마을 · 가야금(굿거리풍 12/8).
  writeWav(
    'bgm_dustyYard',
    loopTrack(
      bpm: 76,
      beats: 16,
      compose: (s, b) {
        rhythm(
          s,
          b,
          [1, 0, 0.5, 1, 0, 0.6],
          (g) => drum(110, decay: 0.15, skin: 0.4),
          div: 1.5,
        );
        melody(
          s,
          b,
          [
            (0, 0, 1.5),
            (1.5, 2, 1.5),
            (3, 3, 1.5),
            (4.5, 4, 1.5),
            (6, 3, 1),
            (7, 2, 1),
            (8, 1, 1.5),
            (9.5, 2, 1.5),
            (11, 0, 1.5),
            (12.5, -1, 1.5),
            (14, 0, 2),
          ],
          (f, d) => pluck(f, d + 0.6),
          gain: 0.9,
        );
      },
    ),
  );
  // 2장 객잔 · 해금.
  writeWav(
    'bgm_oilyTable',
    loopTrack(
      bpm: 92,
      beats: 16,
      compose: (s, b) {
        rhythm(s, b, [
          1,
          0,
          0.4,
          0,
          0.8,
          0.4,
          0,
          0.4,
        ], (g) => drum(140, decay: 0.12, skin: 0.6));
        melody(
          s,
          b,
          [
            (0, 4, 2),
            (2, 3, 1),
            (3, 2, 1),
            (4, 3, 3),
            (7, 1, 1),
            (8, 2, 2),
            (10, 0, 1),
            (11, 1, 1),
            (12, 2, 4),
          ],
          (f, d) => bowed(f, d),
          gain: 0.55,
        );
      },
    ),
  );
  // 3장 장터 · 꽹과리(자진모리풍).
  writeWav(
    'bgm_turtleMarket',
    loopTrack(
      bpm: 120,
      beats: 16,
      compose: (s, b) {
        rhythm(
          s,
          b,
          [1, 0, 0.6, 1, 0, 0.6, 1, 0.5, 0, 0.7, 0, 0.5],
          (g) => gong(decay: 0.08),
          div: 3,
        );
        rhythm(
          s,
          b,
          [1, 0, 0, 0.7, 0, 0],
          (g) => drum(100, decay: 0.15),
          div: 1.5,
        );
        melody(
          s,
          b,
          [
            (0, 5, 1),
            (1, 4, 1),
            (2, 3, 2),
            (4, 4, 1),
            (5, 5, 1),
            (6, 7, 2),
            (8, 5, 1),
            (9, 4, 1),
            (10, 3, 1),
            (11, 2, 1),
            (12, 3, 4),
          ],
          (f, d) => pluck(f, d + 0.3, damp: 0.99, bright: 0.7),
          gain: 0.6,
        );
      },
    ),
  );
  // 4장 숲 · 대금.
  writeWav(
    'bgm_kubiForest',
    loopTrack(
      bpm: 60,
      beats: 12,
      compose: (s, b) {
        rhythm(
          s,
          b,
          [1, 0, 0, 0, 0.5, 0],
          (g) => drum(80, decay: 0.3, skin: 0.2),
          div: 1.5,
        );
        melody(
          s,
          b,
          [(0, 2, 3), (3, 3, 1), (4, 4, 2), (6, 3, 1), (7, 2, 1), (8, 1, 4)],
          (f, d) => blown(f, d),
          gain: 0.6,
          octave: 1,
        );
      },
    ),
  );
  // 5장 학당 · 거문고.
  writeWav(
    'bgm_logicMarble',
    loopTrack(
      bpm: 66,
      beats: 16,
      compose: (s, b) {
        melody(
          s,
          b,
          [
            (0, -5, 2),
            (2, -3, 2),
            (4, -2, 2),
            (6, -1, 2),
            (8, -3, 2),
            (10, -5, 2),
            (12, -6, 4),
          ],
          (f, d) => pluck(f, d + 1, damp: 0.998, bright: 0.2),
          gain: 1,
        );
        rhythm(s, b, [
          1,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
        ], (g) => drum(70, decay: 0.4, skin: 0.1));
      },
    ),
  );
  // 6장 대회 · 북·태평소.
  writeWav(
    'bgm_murimIce',
    loopTrack(
      bpm: 112,
      beats: 16,
      compose: (s, b) {
        rhythm(
          s,
          b,
          [1, 0, 0.5, 0.8, 0, 0.5, 1, 0, 0.5, 0.8, 0.6, 0.6],
          (g) => drum(65, decay: 0.2, skin: 0.5),
          div: 3,
        );
        melody(
          s,
          b,
          [
            (0, 4, 1),
            (1, 5, 1),
            (2, 7, 2),
            (4, 5, 1),
            (5, 4, 1),
            (6, 3, 2),
            (8, 4, 1),
            (9, 3, 1),
            (10, 2, 1),
            (11, 3, 1),
            (12, 4, 4),
          ],
          (f, d) => blown(f, d, nasal: true),
          gain: 0.45,
        );
      },
    ),
  );
}
