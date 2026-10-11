import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../progress/daily.dart';
import '../progress/profile.dart';
import '../progress/store.dart';
import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';

/// 출석 · 일일 임무 · 업적(설계서 §16.9). 받을 것이 있으면 로비 아이콘에 빨간 점.
class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key, this.tab = 0});
  final int tab;

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 3, vsync: this, initialIndex: widget.tab);
  final _store = ProfileStore.instance;

  /// 방금 받은 보상(위로 떠오르는 연출).
  Reward? _flash;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _got(Reward? r) async {
    if (r == null) return;
    Sound.play('reward');
    Sound.play('coin', 0.7);
    setState(() => _flash = r);
    await _store.save();
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _flash = null);
  }

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    final day = today();
    return GameScaffold(
      title: '오늘의 보상',
      background: 'lobby',
      dim: 0.5,
      body: Stack(
        children: [
          Column(
            children: [
              TabBar(
                controller: _tabs,
                indicatorColor: Palette.gold,
                labelColor: Palette.gold,
                unselectedLabelColor: Palette.dim,
                labelStyle: const TextStyle(fontFamily: titleFont, fontSize: 18),
                tabs: [
                  Tab(icon: _badge('attendance', Attendance.canClaim(p, day)), text: '출석'),
                  Tab(icon: _badge('mission', Missions.hasClaimable(p, day)), text: '임무'),
                  Tab(icon: _badge('medal', Achievements.hasClaimable(p)), text: '업적'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [_attendance(p, day), _missions(p, day), _achievements(p)],
                ),
              ),
            ],
          ),
          if (_flash case final r?)
            Positioned.fill(child: IgnorePointer(child: _RewardBurst(reward: r))),
        ],
      ),
    );
  }

  Widget _badge(String icon, bool dot) => Stack(
    clipBehavior: Clip.none,
    children: [
      Image.asset(Art.icon(icon), width: 34),
      if (dot) const Positioned(right: -4, top: -2, child: RedDot(size: 11)),
    ],
  );

  Widget _attendance(Profile p, String day) {
    final next = Attendance.nextIndex(p);
    final can = Attendance.canClaim(p, day);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.78,
          children: [
            for (var i = 0; i < attendanceRewards.length; i++)
              _DayCell(
                day: i + 1,
                reward: attendanceRewards[i],
                // 이번 7일 묶음에서 이미 받은 칸.
                taken: i < next || (!can && i == (next - 1) % attendanceRewards.length),
                today: can && i == next,
                big: i == attendanceRewards.length - 1,
              ),
          ],
        ),
        const SizedBox(height: 18),
        GameButton(
          key: const Key('attend-claim'),
          label: can ? '오늘 보상 받기' : '내일 또 와요',
          icon: can ? 'chest' : null,
          color: can ? Palette.red : Palette.jade,
          height: 66,
          onTap: can ? () => _got(Attendance.claim(p, day)) : null,
        ),
        const SizedBox(height: 8),
        Center(child: Text('출석 ${p.attendCount}일', style: const TextStyle(color: Palette.dim))),
      ],
    );
  }

  Widget _missions(Profile p, String day) {
    final ms = Missions.of(day);
    final allDone = p.missionDay == day && p.missionClaimed.length >= 3;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        for (var i = 0; i < ms.length; i++)
          _TaskCard(
            icon: _deedIcon(ms[i].deed),
            title: '${ms[i].deed.label} ${ms[i].goal}',
            now: Missions.progress(p, ms[i], day),
            goal: ms[i].goal,
            reward: ms[i].reward,
            claimed: Missions.claimed(p, i, day),
            onClaim: () => _got(Missions.claim(p, i, day)),
          ),
        const SizedBox(height: 8),
        GlassPanel(
          child: Row(
            children: [
              Image.asset(Art.icon('chest'), width: 56),
              const SizedBox(width: 10),
              const Expanded(child: Text('셋 다 끝내면 덤!', style: TextStyle(fontSize: 18))),
              for (final (ic, n) in missionBonus.items) _RewardChip(icon: ic, n: n),
              const SizedBox(width: 8),
              SizedBox(
                width: 84,
                child: GameButton(
                  label: p.missionClaimed.contains(99) ? '완료' : '받기',
                  height: 44,
                  fontSize: 18,
                  color: Palette.red,
                  onTap: allDone && !p.missionClaimed.contains(99) ? () => _got(Missions.claimBonus(p, day)) : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _achievements(Profile p) => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      for (final a in [...achievements]..sort((x, y) => _rank(p, x) - _rank(p, y)))
        _TaskCard(
          icon: 'medal',
          title: a.title,
          now: a.count(p),
          goal: a.goal,
          reward: a.reward,
          claimed: p.achieved.contains(a.id),
          onClaim: () => _got(Achievements.claim(p, a)),
        ),
    ],
  );

  /// 받을 것 → 하는 중 → 받은 것 순.
  int _rank(Profile p, Achievement a) =>
      Achievements.ready(p, a) ? 0 : (p.achieved.contains(a.id) ? 2 : 1);

  String _deedIcon(Deed d) => switch (d) {
    Deed.win => 'arena',
    Deed.play => 'free',
    Deed.knock => 'campaign',
    Deed.critical => 'stats',
    Deed.train => 'training',
    Deed.inner => 'naegong',
  };
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.reward, required this.taken, required this.today, required this.big});
  final int day;
  final Reward reward;
  final bool taken;
  final bool today;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final (icon, n) = reward.items.first;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: today ? const Color(0xFF5A3A12) : Palette.panel,
        border: Border.all(color: today ? Palette.gold : Colors.white24, width: today ? 3 : 1),
        boxShadow: today ? [BoxShadow(color: Palette.gold.withValues(alpha: 0.5), blurRadius: 14)] : null,
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$day일', style: const TextStyle(fontFamily: titleFont, fontSize: 14, color: Palette.dim)),
                Image.asset(Art.icon(big ? 'chest' : icon), width: 42),
                Text('×$n', style: const TextStyle(fontFamily: titleFont, fontSize: 16)),
              ],
            ),
          ),
          if (taken)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.check_circle, color: Palette.jade, size: 40),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.icon,
    required this.title,
    required this.now,
    required this.goal,
    required this.reward,
    required this.claimed,
    required this.onClaim,
  });
  final String icon;
  final String title;
  final int now;
  final int goal;
  final Reward reward;
  final bool claimed;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final done = now >= goal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Image.asset(Art.icon(icon), width: 50),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontFamily: titleFont, fontSize: 17)),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (now / goal).clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: Colors.white12,
                      color: done ? Palette.jade : Palette.gold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text('${now.clamp(0, goal)} / $goal', style: const TextStyle(fontSize: 13, color: Palette.dim)),
                      const Spacer(),
                      for (final (ic, n) in reward.items) _RewardChip(icon: ic, n: n),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 78,
              child: GameButton(
                label: claimed ? '완료' : '받기',
                height: 44,
                fontSize: 18,
                color: Palette.red,
                onTap: done && !claimed ? onClaim : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.icon, required this.n});
  final String icon;
  final int n;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(Art.icon(icon), width: 22),
      Text('$n ', style: const TextStyle(fontFamily: titleFont, fontSize: 14)),
    ],
  );
}

/// 받은 보상이 가운데서 크게 튀어나와 위로 날아간다.
class _RewardBurst extends StatelessWidget {
  const _RewardBurst({required this.reward});
  final Reward reward;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 1300),
    builder: (_, v, _) {
      final pop = Curves.elasticOut.transform((v / 0.5).clamp(0, 1));
      final fly = v > 0.7 ? Curves.easeIn.transform(((v - 0.7) / 0.3).clamp(0.0, 1.0)) : 0.0;
      return Container(
        color: Colors.black.withValues(alpha: 0.5 * (1 - fly)),
        alignment: Alignment(0, -0.1 - fly * 1.1),
        child: Opacity(
          opacity: 1 - fly,
          child: Transform.scale(
            scale: 0.3 + 0.9 * pop,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (ic, n) in reward.items) ...[
                  Image.asset(Art.icon(ic), width: 84),
                  OutlinedText('+$n', size: 40, title: true, color: Palette.gold),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
