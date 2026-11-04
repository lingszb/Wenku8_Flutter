// Minimal source-snapshot implementation adapted from upstream issue #43.
import 'package:flutter/material.dart';

import 'enhancement.dart';

class ListeningEnhancementSettings extends StatelessWidget {
  const ListeningEnhancementSettings({
    super.key,
    required this.enhancement,
    required this.onChanged,
  });

  final ListeningEnhancement enhancement;
  final ValueChanged<ListeningEnhancementPreference> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = enhancement.preference;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('声音增强', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final entry in const {
              ListeningEnhancementMode.none: '原声',
              ListeningEnhancementMode.clarity: '清晰',
              ListeningEnhancementMode.warm: '温暖',
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: current.mode == entry.key,
                onSelected: null,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '当前源码版本暂不支持声音增强，听书使用原声播放。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
