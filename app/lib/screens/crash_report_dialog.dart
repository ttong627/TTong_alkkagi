import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/theme.dart';

/// 「지난번에 앱이 갑자기 꺼졌어요」 창: 까닭 글을 보여 주고 복사하게 한다(2026-10-14 형 「자꾸 튕기는 증상」).
Future<void> showCrashReport(BuildContext context, String report) =>
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        key: const Key('crash-report'),
        title: const Text('지난번에 앱이 갑자기 꺼졌어요'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('아래 글을 「복사」해서 보내 주시면 원인을 찾아 고칠게요.'),
              const SizedBox(height: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black26,
                  child: SingleChildScrollView(
                    child: SelectableText(
                      report,
                      style: const TextStyle(fontSize: 12, color: Palette.dim),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('닫기'),
          ),
          FilledButton(
            key: const Key('crash-copy'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report));
              if (c.mounted) {
                ScaffoldMessenger.maybeOf(c)
                    ?.showSnackBar(const SnackBar(content: Text('복사했어요')));
                Navigator.pop(c);
              }
            },
            child: const Text('복사'),
          ),
        ],
      ),
    );
