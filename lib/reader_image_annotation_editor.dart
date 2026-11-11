import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_ui.dart';
import 'feature_pages.dart' show confirmNovelAction;
import 'library_state.dart';
import 'reader_annotation_editor.dart';
import 'reader_bookmark_excerpt.dart';
import 'reader_underline.dart';

/// Picture-first annotation pad for image bookmarks.
///
/// Text typed here is painted onto the picture and can be dragged; colour and
/// long-form notes stay in the shared text annotation editor so both ways of
/// annotating an image keep working.
Future<ReaderBookmark?> showReaderImageAnnotationEditor(
  BuildContext context, {
  required LibraryState state,
  required int novelId,
  required ReaderBookmark bookmark,
  Widget Function(Widget)? surfaceWrapper,
}) {
  if (!bookmark.isImage) {
    return showReaderAnnotationEditor(
      context,
      state: state,
      novelId: novelId,
      bookmark: bookmark,
      surfaceWrapper: surfaceWrapper,
    );
  }
  return showJellySheet<ReaderBookmark>(
    context: context,
    reduceMotion: state.reduceMotion,
    guardDragDismiss: true,
    maxWidth: 620,
    maxHeight: MediaQuery.sizeOf(context).height * .9,
    surfaceWrapper: surfaceWrapper,
    builder: (_) => ReaderImageAnnotationEditor(
      state: state,
      novelId: novelId,
      bookmark: bookmark,
    ),
  );
}

class ReaderImageAnnotationEditor extends StatefulWidget {
  const ReaderImageAnnotationEditor({
    super.key,
    required this.state,
    required this.novelId,
    required this.bookmark,
  });

  final LibraryState state;
  final int novelId;
  final ReaderBookmark bookmark;

  @override
  State<ReaderImageAnnotationEditor> createState() =>
      _ReaderImageAnnotationEditorState();
}

class _ReaderImageAnnotationEditorState
    extends State<ReaderImageAnnotationEditor> {
  late final TextEditingController _note;
  late ReaderBookmark _bookmark;
  late double _x, _y;
  bool _saving = false, _closing = false, _askingToClose = false;
  String? _error;

  String get _text => _note.text.trim();

  bool get _dirty {
    if (_text != _bookmark.annotation.imageNote) return true;
    if (_text.isEmpty) return false;
    return _x != _bookmark.annotation.imageNoteX ||
        _y != _bookmark.annotation.imageNoteY;
  }

  @override
  void initState() {
    super.initState();
    _bookmark = widget.bookmark;
    final annotation = _bookmark.annotation;
    _note = TextEditingController(text: annotation.imageNote);
    _note.addListener(_edited);
    _x = annotation.imageNoteX;
    _y = annotation.imageNoteY;
  }

  void _edited() {
    if (mounted) setState(() => _error = null);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_saving || _closing || _askingToClose) return;
    if (_dirty) {
      _askingToClose = true;
      final discard = await confirmNovelAction(
        context,
        title: '放弃未保存的图片批注？',
        message: '已保存在书签里的文字批注不会改变。',
        confirmLabel: '放弃修改',
        reduceMotion: widget.state.reduceMotion,
      );
      _askingToClose = false;
      if (!discard) return;
    }
    if (!mounted) return;
    _finish();
  }

  void _finish([ReaderBookmark? result]) {
    setState(() => _closing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, result);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.state.updateBookmarkImageNote(
        widget.novelId,
        _bookmark.id,
        text: _text,
        x: _x,
        y: _y,
      );
      if (!mounted) return;
      _finish(result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is FormatException ? error.message : '图片批注未保存，请重试';
        });
      }
    }
  }

  Future<void> _openTextAnnotation() async {
    if (_saving || _closing) return;
    FocusScope.of(context).unfocus();
    final result = await showReaderAnnotationEditor(
      context,
      state: widget.state,
      novelId: widget.novelId,
      bookmark: _bookmark,
    );
    if (!mounted || result == null) return;
    setState(() => _bookmark = result);
  }

  Future<void> _delete() async {
    if (_saving ||
        !await confirmNovelAction(
          context,
          title: '删除这条图片书签与批注？',
          message: '原书和阅读进度不会改变。',
          confirmLabel: '删除记录',
          reduceMotion: widget.state.reduceMotion,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.state.removeBookmark(widget.novelId, _bookmark.id);
      if (!mounted) return;
      _finish();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '记录未删除，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final inputStyle = theme.textTheme.bodyMedium!.copyWith(
      inherit: false,
      fontFamily:
          widget.state.appFontFamily ??
          theme.typography.black.bodyMedium?.fontFamily,
      fontSize: 15,
      height: 1.65,
      leadingDistribution: TextLeadingDistribution.even,
      fontWeight: FontWeight.w400,
      color: scheme.onSurface,
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(ArchiveDesign.panelRadius),
      borderSide: BorderSide.none,
    );
    final textNote = _bookmark.note;
    return PopScope<ReaderBookmark>(
      canPop: _closing || !_saving && !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              key: const ValueKey('reader-image-annotation-scroll'),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: ArchiveSection(
                          title: '图片批注',
                          code: 'IMAGE / ANNOTATION',
                        ),
                      ),
                      GlassIconButton(
                        icon: CupertinoIcons.xmark,
                        label: '关闭图片批注',
                        onPressed: _saving ? null : _close,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ReaderBookmarkImage(
                    key: const ValueKey('reader-image-annotation-preview'),
                    url: _bookmark.imageUrl,
                    height: 300,
                    note: _note.text,
                    noteX: _x,
                    noteY: _y,
                    onNoteMoved: (offset) => setState(() {
                      _x = offset.dx;
                      _y = offset.dy;
                    }),
                  ),
                  const SizedBox(height: 10),
                  AppText(
                    _text.isEmpty
                        ? '写下会出现在图片上的文字，保存后可以拖动位置。'
                        : '按住图片上的文字即可拖动位置。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DefaultSelectionStyle.merge(
                    cursorColor: scheme.primary,
                    selectionColor: scheme.onSurface.withValues(alpha: .18),
                    child: TextField(
                      key: const ValueKey('reader-image-annotation-note'),
                      controller: _note,
                      enabled: !_saving,
                      minLines: 2,
                      maxLines: 5,
                      maxLength: ReaderAnnotationData.maxImageNoteLength,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(
                          ReaderAnnotationData.maxImageNoteLength,
                        ),
                      ],
                      textCapitalization: TextCapitalization.sentences,
                      style: inputStyle,
                      keyboardAppearance: theme.brightness,
                      decoration: InputDecoration(
                        hint: Text(
                          '写一句会显示在图片上的话…',
                          style: inputStyle.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                        isDense: true,
                        filled: true,
                        fillColor: scheme.onSurface.withValues(alpha: .045),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: inputBorder,
                        disabledBorder: inputBorder,
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GlassTextButton(
                    key: const ValueKey('image-annotation-text-mode'),
                    onPressed: _saving ? null : _openTextAnnotation,
                    child: AppText(
                      textNote.isEmpty
                          ? '改用文本批注'
                          : '文本批注 · 已写 ${textNote.length} 字',
                    ),
                  ),
                  const SizedBox(height: 4),
                  AppText(
                    '文本批注沿用摘录批注：可设置标记方式、颜色，并写长批注。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: AppText(
                        _error!,
                        style: TextStyle(color: scheme.error, height: 1.5),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassPillButton(
                  icon: CupertinoIcons.checkmark,
                  label: _saving ? '正在保存…' : '保存图片批注',
                  onPressed: _saving ? null : _save,
                ),
                const SizedBox(height: 8),
                GlassTextButton(
                  onPressed: _saving ? null : _delete,
                  child: const AppText('删除这条记录'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
