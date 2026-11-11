import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'library_state.dart';
import 'reader_mark_style.dart';
import 'reader_illustrations.dart';

/// Shared quote/thought hierarchy for reader and library bookmark rows.
/// The surrounding page keeps ownership of its panel, metadata and actions.
class ReaderBookmarkExcerpt extends StatelessWidget {
  const ReaderBookmarkExcerpt({
    super.key,
    required this.mark,
    this.quoteMaxLines = 5,
    this.noteMaxLines = 3,
    this.compact = false,
    this.onNoteTap,
  });

  final ReaderBookmark mark;
  final int quoteMaxLines, noteMaxLines;
  final bool compact;

  /// Opens the excerpt's note, or the editor when it has none.
  final VoidCallback? onNoteTap;

  Widget _quote(BuildContext context) {
    final theme = Theme.of(context);
    final ink = readerMarkInk(
      mark.annotation.color,
      theme.colorScheme.onSurface,
      dark: theme.brightness == Brightness.dark,
    );
    return DecoratedBox(
      key: ValueKey('bookmark-quote-${mark.id}'),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: ink.withValues(alpha: .64), width: 2),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(left: compact ? 10 : 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(context, compact ? '摘录' : '原文摘录', ink),
            SizedBox(height: compact ? 4 : 8),
            _quoteText(context, ink),
          ],
        ),
      ),
    );
  }

  Widget _quoteText(BuildContext context, Color ink) {
    final style = TextStyle(
      fontSize: compact ? 15 : 16,
      height: compact ? 1.5 : 1.8,
    );
    final onNoteTap = this.onNoteTap;
    if (onNoteTap == null) {
      return AppText(
        mark.quote,
        maxLines: quoteMaxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return Text.rich(
      TextSpan(
        text: appText(context, mark.quote),
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Semantics(
                button: true,
                label: mark.note.isEmpty ? '添加批注' : '查看批注',
                child: JellyTapSurface(
                  key: ValueKey('bookmark-note-entry-${mark.id}'),
                  onTap: onNoteTap,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ink.withValues(
                        alpha: mark.note.isEmpty ? .10 : .18,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: ArchiveIcon(
                      mark.note.isEmpty
                          ? CupertinoIcons.bookmark
                          : CupertinoIcons.bookmark_fill,
                      size: 12,
                      color: ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      maxLines: quoteMaxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }

  Widget _heading(BuildContext context, String label, Color ink) => Row(
    children: [
      Expanded(
        child: AppText(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      Flexible(
        child: Align(
          alignment: Alignment.centerRight,
          child: AppText(
            mark.kindLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: ink),
          ),
        ),
      ),
    ],
  );

  Widget _image(BuildContext context) {
    final theme = Theme.of(context);
    final ink = readerMarkInk(
      mark.annotation.color,
      theme.colorScheme.onSurface,
      dark: theme.brightness == Brightness.dark,
    );
    return DecoratedBox(
      key: ValueKey('bookmark-image-${mark.id}'),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: ink.withValues(alpha: .64), width: 2),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(left: compact ? 10 : 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(context, compact ? '图片' : '图片摘录', ink),
            SizedBox(height: compact ? 6 : 10),
            ReaderBookmarkImage(
              url: mark.imageUrl,
              compact: compact,
              note: mark.annotation.imageNote,
              noteX: mark.annotation.imageNoteX,
              noteY: mark.annotation.imageNoteY,
            ),
          ],
        ),
      ),
    );
  }

  Widget _thought(BuildContext context) => compact
      ? Padding(
          key: ValueKey('bookmark-note-${mark.id}'),
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                '批注',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.8,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  mark.note,
                  maxLines: noteMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ],
          ),
        )
      : Padding(
          key: ValueKey('bookmark-note-${mark.id}'),
          padding: const EdgeInsets.only(left: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText(
                '个人批注',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 7),
              AppText(
                mark.note,
                maxLines: noteMaxLines,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.75),
              ),
            ],
          ),
        );

  @override
  Widget build(BuildContext context) {
    final hasQuote = mark.quote.isNotEmpty, hasNote = mark.note.isNotEmpty;
    if (!mark.isImage && !hasQuote && !hasNote) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mark.isImage) _image(context),
        if (mark.isImage && (hasQuote || hasNote))
          SizedBox(height: compact ? 8 : 20),
        if (hasQuote) _quote(context),
        if (hasQuote && hasNote) SizedBox(height: compact ? 8 : 20),
        if (hasNote) _thought(context),
      ],
    );
  }
}

/// A bounded thumbnail shared by the reader panel and the bookmark library.
/// Loading and failure states come from the reader's illustration cache.
class ReaderBookmarkImage extends StatelessWidget {
  const ReaderBookmarkImage({
    super.key,
    required this.url,
    this.compact = false,
    this.note = '',
    this.noteX = .5,
    this.noteY = .82,
    this.height,
    this.onNoteMoved,
  });

  final String url;
  final bool compact;

  /// Text painted over the picture; empty keeps the bare thumbnail.
  final String note;
  final double noteX, noteY;
  final double? height;

  /// Receives a normalised replacement position while the note is dragged.
  final ValueChanged<Offset>? onNoteMoved;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: note.isEmpty ? '图片摘录' : '带批注的图片摘录',
    excludeSemantics: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(ArchiveDesign.panelRadius),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: SizedBox(
          width: double.infinity,
          height: height ?? (compact ? 96 : 168),
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              fit: StackFit.expand,
              children: [
                ReaderIllustration(
                  url: url,
                  cache: ReaderIllustrationCache.shared,
                  fitPage: true,
                ),
                if (note.isNotEmpty)
                  Align(
                    alignment: Alignment(noteX * 2 - 1, noteY * 2 - 1),
                    child: GestureDetector(
                      onPanUpdate: onNoteMoved == null
                          ? null
                          : (details) {
                              final size = constraints.biggest;
                              if (size.isEmpty) return;
                              onNoteMoved!(
                                Offset(
                                  (noteX + details.delta.dx / size.width)
                                      .clamp(.06, .94),
                                  (noteY + details.delta.dy / size.height)
                                      .clamp(.06, .94),
                                ),
                              );
                            },
                      child: FractionallySizedBox(
                        widthFactor: .86,
                        child: Text(
                          note,
                          textAlign: TextAlign.center,
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 11 : 14,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            shadows: const [
                              Shadow(blurRadius: 6, color: Colors.black87),
                              Shadow(blurRadius: 2, color: Colors.black),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
