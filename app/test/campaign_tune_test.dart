import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi/story/campaign.dart';
import 'package:alkkagi/story/chapters.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('쉬움은 모든 판에서 보통보다 고수가 서툴다(손 오차·시작 내공)', () {
    for (final s in campaign) {
      final e = Campaign.tune(s, easy: true), n = Campaign.tune(s);
      expect(e.errorScale, greaterThanOrEqualTo(n.errorScale), reason: s.id);
      expect(e.blunder, greaterThanOrEqualTo(n.blunder), reason: s.id);
      expect(
        e.bossQi ?? s.bossQi,
        lessThanOrEqualTo(n.bossQi ?? s.bossQi),
        reason: s.id,
      );
    }
  });

  test('2장 통통의 현철 벽: 쉬움은 청옥 돌, 보통은 내 돌도 현철(대사로 알림)', () {
    final c2 = campaign.firstWhere((s) => s.id == 'c2');
    final p = Profile();
    final easy = Campaign.configFor(p, c2, easy: true);
    expect(easy.opponentMaterial, StoneMaterial.cheongok);
    expect(Campaign.tune(c2, easy: true).note, isNotNull);
    final normal = Campaign.configFor(p, c2);
    expect(normal.opponentMaterial, StoneMaterial.hyeoncheol);
    expect(normal.myMaterial, StoneMaterial.hyeoncheol);
    expect(Campaign.tune(c2).note, isNotNull);
  });

  test('판 설정에 누그러뜨리기가 그대로 들어간다', () {
    final c1 = campaign.first;
    final cfg = Campaign.configFor(Profile(), c1, easy: true);
    expect(cfg.aiErrorScale, Campaign.tune(c1, easy: true).errorScale);
    expect(cfg.aiBlunder, Campaign.tune(c1, easy: true).blunder);
    expect(cfg.difficulty, Difficulty.easy);
  });
}
