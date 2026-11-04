// Minimal source-snapshot implementation adapted from upstream issue #43.
import 'package:flutter/material.dart';

import 'reading_widget_reference.dart';
import 'reading_widget_skin.dart';
import 'reading_widget_snapshot.dart';

/// Horizontal skin chooser used by the widget settings page.
class ReadingWidgetSkinPicker extends StatelessWidget {
  const ReadingWidgetSkinPicker({
    super.key,
    required this.previewBuilder,
    required this.value,
    required this.size,
    required this.snapshot,
    required this.onChanged,
  });

  final Widget Function(ReadingWidgetSkin skin) previewBuilder;
  final ReadingWidgetSkin value;
  final ReadingDesktopSize size;
  final ReadingWidgetSnapshot snapshot;
  final ValueChanged<ReadingWidgetSkin>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: size.previewHeight + 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ReadingWidgetSkin.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final skin = ReadingWidgetSkin.values[index];
          final selected = skin == value;
          return Semantics(
            button: true,
            selected: selected,
            label: '${skin.label}，本周 ${widgetMinutes(snapshot.weekSeconds)} 分钟',
            child: GestureDetector(
              onTap: onChanged == null ? null : () => onChanged!(skin),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? scheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: previewBuilder(skin),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      skin.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
