// Minimal source-snapshot implementation adapted from upstream issue #43.
import 'package:flutter/material.dart';

import 'catalog.dart';
import 'library_state.dart';
import 'local_books.dart';

Future<void> openLocalBookBatch(
  BuildContext context, {
  required LocalBookStore books,
  required LibraryState library,
  Set<int>? selected,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) =>
        LocalBookBatchPage(books: books, library: library, selected: selected),
  ),
);

/// Desktop-safe batch view.
///
/// The original page merged volumes into local series. That code is not part of
/// the public snapshot, so selection is shown read-only and the page never
/// mutates book records.
class LocalBookBatchPage extends StatefulWidget {
  const LocalBookBatchPage({
    super.key,
    required this.books,
    required this.library,
    this.selected,
  });

  final LocalBookStore books;
  final LibraryState library;
  final Set<int>? selected;

  @override
  State<LocalBookBatchPage> createState() => _LocalBookBatchPageState();
}

class _LocalBookBatchPageState extends State<LocalBookBatchPage> {
  late final _selected = {...?widget.selected};

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('批量整理本地书')),
    body: ListenableBuilder(
      listenable: widget.books,
      builder: (context, _) {
        final books = widget.books.books;
        if (books.isEmpty) {
          return const Center(child: Text('本地书库为空'));
        }
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final Novel book = books[index];
                  return CheckboxListTile(
                    value: _selected.contains(book.id),
                    title: Text(book.title),
                    subtitle: book.author.isEmpty ? null : Text(book.author),
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _selected.add(book.id);
                      } else {
                        _selected.remove(book.id);
                      }
                    }),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '已选择 ${_selected.length} 本。系列合并与分类批量编辑在当前源码版本暂未开放。',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
