import 'package:flutter/cupertino.dart';
import 'app_ui.dart';
import 'app_search_field.dart';
import 'catalog.dart';
import 'tag_catalogue.dart';

class BlockedTagsEditor extends StatefulWidget {
  const BlockedTagsEditor({
    super.key,
    required this.books,
    this.availableTags = const [],
    this.blockedTags = const {},
    this.onBlockedTagsChanged,
  });
  final List<Novel> books;
  final Iterable<String> availableTags;
  final Set<String> blockedTags;
  final Future<void> Function(Set<String>)? onBlockedTagsChanged;
  @override
  State<BlockedTagsEditor> createState() => _BlockedTagsEditorState();
}

class _BlockedTagsEditorState extends State<BlockedTagsEditor> {
  late final blocked = {...widget.blockedTags};
  final query = TextEditingController();
  bool _saving = false;
  String? _saveError;
  Set<String> get _editing => blocked;
  bool _isSelected(String tag) =>
      blocked.any((value) => _tagKey(value) == _tagKey(tag));
  String _tagKey(String value) => value.trim().toLowerCase();
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  void addTags(String value) {
    final tags = tagSearchTerms(value);
    setState(() {
      for (final tag in tags) {
        if (!_isSelected(tag)) _editing.add(tag);
      }
      query.clear();
      _saveError = null;
    });
  }

  Future<void> _applyBlocked() async {
    if (_saving || widget.onBlockedTagsChanged == null) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.onBlockedTagsChanged!(Set.unmodifiable(blocked));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = '屏蔽标签保存失败，请重试。';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final frequency = <String, int>{
      for (final tag in [...widget.availableTags, ...blocked]) tag: 0,
    };
    for (final book in widget.books) {
      for (final tag in book.tags) {
        frequency.update(tag, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final candidates = {
      for (final tag in frequency.keys) _tagKey(tag): tag,
    }.values;
    final tags =
        candidates
            .where(
              (tag) =>
                  _isSelected(tag) ||
                  tag.toLowerCase().contains(query.text.trim().toLowerCase()),
            )
            .toList()
          ..sort((a, b) {
            final order = frequency[b]!.compareTo(frequency[a]!);
            return order == 0 ? a.compareTo(b) : order;
          });
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArchiveSection(title: '屏蔽标签', code: 'LOCAL / TAG FILTER'),
          const SizedBox(height: 16),
          Row(
            children: [
              GlassTextButton(
                key: const ValueKey('blocked-tags-clear'),
                onPressed: _editing.isEmpty || _saving
                    ? null
                    : () => setState(() {
                        _editing.clear();
                        _saveError = null;
                      }),
                child: const AppText('清空'),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GlassTextButton(
                    key: const ValueKey('blocked-tags-apply'),
                    selected: _editing.isNotEmpty,
                    onPressed: _saving
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            _applyBlocked();
                          },
                    child: AppText(
                      _saving
                          ? '保存中…'
                          : blocked.isEmpty
                          ? '解除全部屏蔽'
                          : '屏蔽 ${blocked.length} 个标签',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppSearchField(
            inputKey: const ValueKey('blocked-tag-input'),
            controller: query,
            hint: '搜索或添加屏蔽标签',
            onChanged: (_) => setState(() {}),
            onSubmitted: addTags,
            trailing: ArchiveIconButton(
              tooltip: appText(context, '加入标签'),
              icon: const ArchiveIcon(CupertinoIcons.plus, size: 18),
              onPressed: query.text.trim().isEmpty
                  ? null
                  : () => addTags(query.text),
            ),
          ),
          const SizedBox(height: 14),
          AppText('隐藏含任一所选标签的本地图书。', style: const TextStyle(fontSize: 13)),
          if (_saveError case final error?) ...[
            const SizedBox(height: 8),
            AppText(error, style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final tag in tags)
                GlassTextButton(
                  key: ValueKey('blocked-tag-$tag'),
                  compact: true,
                  selected: _isSelected(tag),
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          if (_isSelected(tag)) {
                            blocked.removeWhere(
                              (value) => _tagKey(value) == _tagKey(tag),
                            );
                          } else {
                            _editing.add(tag);
                          }
                          _saveError = null;
                        }),
                  child: AppText(tag, style: const TextStyle(fontSize: 13)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
