import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_interactions.dart';
import 'app_ui.dart';
import 'catalog.dart';
import 'local_platform.dart';

class BookShareAction extends StatelessWidget {
  const BookShareAction({super.key, required this.novel});

  final Novel novel;

  Future<void> _share(BuildContext context) async {
    final text = '${novel.title}\n${novel.author}';
    try {
      if (LocalPlatform.android) {
        await LocalPlatform.shareText(text);
      } else {
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) showNovelFeedback(context, '图书信息已复制');
      }
    } catch (_) {
      if (context.mounted) showNovelFeedback(context, '分享未完成，请重试');
    }
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: GlassTextButton(
      key: const ValueKey('detail-share'),
      compact: true,
      onPressed: () => _share(context),
      child: const AppText('分享'),
    ),
  );
}
