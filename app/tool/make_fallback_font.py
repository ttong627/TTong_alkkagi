"""보충 글꼴 만들기: 본문·제목 글꼴(도현·Black Han Sans)에 없는 기호·한자만 Noto Sans KR 에서 떼어 온다.

쓰기(저장소 루트에서):
  pip install fonttools
  curl -o /tmp/NotoSansKR.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanskr/NotoSansKR%5Bwght%5D.ttf"
  python3 app/tool/make_fallback_font.py /tmp/NotoSansKR.ttf

앱 문자열(lib/**/*.dart)에 쓰인 글자 가운데 두 글꼴 어디에도 없는 것 + 흔한 문장부호·화살표를
모아 app/assets/fonts/NotoSansKR-Fallback.ttf (굵기 600 고정)로 쓴다.
새 한자·기호를 쓰면 다시 돌린다(test/fonts_test.dart 가 빠진 글자를 잡는다).
"""
import glob
import re
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

APP = 'app'
src = sys.argv[1]

chars = set()
for f in glob.glob(f'{APP}/lib/**/*.dart', recursive=True):
    text = open(f, encoding='utf-8').read()
    for m in re.finditer(r"'([^'\\\n]*(?:\\.[^'\\\n]*)*)'", text):
        chars.update(m.group(1))

have = set()
for fam in ['BlackHanSans-Regular', 'DoHyeon-Regular']:
    cmap = TTFont(f'{APP}/assets/fonts/{fam}.ttf').getBestCmap()
    have |= set(cmap) if not have else (have & set(cmap))

need = {ord(c) for c in chars if ord(c) > 32 and ord(c) not in have}
# 흔한 기호(앞으로 쓸 수 있는 것): 라틴-1 보충, 문장부호, 화살표, 수학 기호 일부, 한중일 기호.
for a, b in [(0x00A0, 0x00FF), (0x2010, 0x205E), (0x2190, 0x21FF), (0x2212, 0x2264), (0x3000, 0x303F), (0x25A0, 0x25FF), (0x2600, 0x266F)]:
    need |= set(range(a, b + 1))

font = TTFont(src)
font = instancer.instantiateVariableFont(font, {'wght': 600})
opts = subset.Options()
opts.layout_features = ['*']
opts.name_IDs = ['*']
sub = subset.Subsetter(opts)
sub.populate(unicodes=sorted(need))
sub.subset(font)
out = f'{APP}/assets/fonts/NotoSansKR-Fallback.ttf'
font.save(out)
print(f'{out}: 글자 {len(font.getBestCmap())}개')
