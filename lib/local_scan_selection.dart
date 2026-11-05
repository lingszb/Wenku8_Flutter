// Minimal source-snapshot implementation adapted from upstream issue #43.
import 'package:flutter/material.dart';

import 'book_documents.dart';

/// Chooses which scanned books to import.
class LocalScanSelection extends StatefulWidget {
  const LocalScanSelection({super.key, required this.snapshot});
  final BookScanSnapshot snapshot;

  @override
  State<LocalScanSelection> createState() => _LocalScanSelectionState();
}

class _LocalScanSelectionState extends State<LocalScanSelection> {
  late final _selected = {for (final book in widget.snapshot.books) book.token};

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('选择要导入的书籍（${_selected.length}）'),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            if (_selected.length == widget.snapshot.books.length) {
              _selected.clear();
            } else {
              _selected
                ..clear()
                ..addAll(widget.snapshot.books.map((book) => book.token));
            }
          }),
          child: Text(
            _selected.length == widget.snapshot.books.length ? '全不选' : '全选',
          ),
        ),
      ],
    ),
    body: widget.snapshot.books.isEmpty
        ? const Center(child: Text('没有可导入的书籍'))
        : ListView.builder(
            itemCount: widget.snapshot.books.length,
            itemBuilder: (context, index) {
              final book = widget.snapshot.books[index];
              return CheckboxListTile(
                value: _selected.contains(book.token),
                title: Text(book.name),
                subtitle:
                    widget.snapshot.details[book.token]?.folder.isNotEmpty ==
                        true
                    ? Text(widget.snapshot.details[book.token]!.folder)
                    : null,
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _selected.add(book.token);
                  } else {
                    _selected.remove(book.token);
                  }
                }),
              );
            },
          ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected),
          child: const Text('导入所选书籍'),
        ),
      ),
    ),
  );
}
