import 'package:flutter/widgets.dart';

import 'app_ui.dart';
import 'blocked_tags_editor.dart';
import 'library_state.dart';
import 'novel_feed_controller.dart';

Future<void> showBlockedTagsSettings(
  BuildContext context, {
  required LibraryState state,
  required NovelFeedController feed,
}) => showJellySheet<void>(
  context: context,
  reduceMotion: state.reduceMotion,
  heightFactor: .75,
  builder: (_) => BlockedTagsEditor(
    books: feed.allItems,
    availableTags: feed.tagSuggestions,
    blockedTags: state.blockedTags,
    onBlockedTagsChanged: (tags) async {
      await state.setBlockedTags(tags);
      feed.setBlockedTags(state.blockedTags);
    },
  ),
);

class BlockedTagsButton extends StatelessWidget {
  const BlockedTagsButton({
    super.key,
    required this.state,
    required this.feed,
    this.label = '屏蔽标签',
    this.compact = false,
  });
  final LibraryState state;
  final NovelFeedController feed;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) => GlassTextButton(
    compact: compact,
    onPressed: () => showBlockedTagsSettings(context, state: state, feed: feed),
    child: AppText(label),
  );
}
