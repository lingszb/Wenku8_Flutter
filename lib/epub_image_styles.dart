import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart' as ast;
import 'package:html/dom.dart';
import 'local_image_layout.dart';
import 'reader_block_spacing.dart';

/// Only image dimensions are carried into the text reader, not a second HTML
/// renderer. csslib and html handle declarations and matching selectors.
Map<Element, LocalImageLayout> epubImageStyles(
  Document document,
  String? Function(String) readStylesheet,
) {
  final properties = epubStyleProperties(document, readStylesheet);
  return {
    for (final image in document.querySelectorAll('img, image'))
      image: LocalImageLayout.fromProperties(properties[image] ?? {}),
  };
}

Map<Element, Map<String, String>> epubStyleProperties(
  Document document,
  String? Function(String) readStylesheet, {
  bool conditionalRules = true,
}) {
  const supportedProperties = {
    'width',
    'height',
    'max-width',
    'max-height',
    'text-align',
    'writing-mode',
    '-epub-writing-mode',
    'font-weight',
    'font-style',
    'text-decoration',
    'opacity',
    'display',
    'break-before',
    'break-after',
    'page-break-before',
    'page-break-after',
    'margin',
    'margin-top',
    'margin-right',
    'margin-bottom',
    'margin-left',
    'margin-block',
    'margin-block-start',
    'margin-block-end',
    'padding',
    'padding-top',
    'padding-right',
    'padding-bottom',
    'padding-left',
    'padding-block',
    'padding-block-start',
    'padding-block-end',
    'list-style',
    'list-style-type',
  };
  final images = document.querySelectorAll('*');
  final values =
      <Element, Map<String, ({String value, bool important, int specificity})>>{
        for (final image in images)
          image: {
            for (final name in ['width', 'height'])
              if (image.attributes[name] case final value?)
                name: (value: value, important: false, specificity: -1),
          },
      };
  void apply(
    Element image,
    ast.DeclarationGroup group,
    int specificity, {
    required bool allowDisplay,
  }) {
    for (final declaration in group.declarations.whereType<ast.Declaration>()) {
      final name = declaration.property.toLowerCase();
      if (!supportedProperties.contains(name) ||
          (name == 'display' && !allowDisplay)) {
        continue;
      }
      final expression = declaration.expression;
      if (expression == null) continue;
      final printer = ast.CssPrinter();
      expression.visit(printer);
      final value = printer.toString().trim().toLowerCase();
      if ((['width', 'height', 'max-width', 'max-height'].contains(name) &&
          value != 'auto' &&
          value != 'none' &&
          LocalImageLayout.length(value) == null)) {
        continue;
      }
      final expanded = <String, String>{};
      if (name == 'margin' || name == 'padding') {
        final parts = value.split(RegExp(r'\s+'));
        if (parts.isEmpty ||
            parts.length > 4 ||
            parts.any(
              (p) =>
                  ReaderBlockSpacing.length(p) == null &&
                  !(name == 'margin' && p == 'auto'),
            )) {
          continue;
        }
        expanded.addAll({
          '$name-top': parts[0],
          '$name-right': parts.length > 1 ? parts[1] : parts[0],
          '$name-bottom': parts.length > 2 ? parts[2] : parts[0],
          '$name-left': parts.length > 3
              ? parts[3]
              : parts.length > 1
              ? parts[1]
              : parts[0],
        });
      } else if (name == 'margin-block' || name == 'padding-block') {
        final parts = value.split(RegExp(r'\s+'));
        if (parts.isEmpty ||
            parts.length > 2 ||
            parts.any((p) => ReaderBlockSpacing.length(p) == null)) {
          continue;
        }
        expanded.addAll({'$name-start': parts.first, '$name-end': parts.last});
      } else if (name == 'list-style') {
        // Only the marker type is used by the text reader. Position and image
        // markers have no inline equivalent and are intentionally ignored.
        for (final part in value.split(RegExp(r'\s+'))) {
          if (_listStyleTypes.contains(part)) {
            expanded['list-style-type'] = part;
            break;
          }
        }
      } else if (name == 'list-style-type') {
        if (!_listStyleTypes.contains(value)) continue;
        expanded[name] = value;
      } else {
        expanded[name] = value;
      }
      for (final entry in expanded.entries) {
        final old = values[image]![entry.key];
        if (old != null &&
            (old.important && !declaration.important ||
                old.important == declaration.important &&
                    old.specificity > specificity)) {
          continue;
        }
        values[image]![entry.key] = (
          value: entry.value,
          important: declaration.important,
          specificity: specificity,
        );
      }
    }
  }

  for (final source in document.querySelectorAll(
    'style, link[rel~="stylesheet"]',
  )) {
    final text = source.localName == 'style'
        ? source.text
        : readStylesheet(source.attributes['href'] ?? '');
    if (text == null || text.isEmpty) continue;
    for (final (rule, allowDisplay) in _styleRules(
      text,
      supportedProperties,
      conditionalRules: conditionalRules,
    )) {
      if (!rule.declarationGroup.declarations.whereType<ast.Declaration>().any(
        (d) => supportedProperties.contains(d.property.toLowerCase()),
      )) {
        continue;
      }
      for (final selector
          in rule.selectorGroup?.selectors ?? <ast.Selector>[]) {
        final query = selector.span?.text;
        if (query == null) continue;
        final specificity = selector.simpleSelectorSequences.fold<int>(
          0,
          (sum, s) =>
              sum +
              switch (s.simpleSelector) {
                ast.IdSelector() => 1000000,
                ast.ClassSelector() ||
                ast.AttributeSelector() ||
                ast.PseudoClassSelector() => 1000,
                ast.ElementSelector() => 1,
                _ => 0,
              },
        );
        try {
          for (final image
              in document.querySelectorAll(query).where(values.containsKey)) {
            apply(
              image,
              rule.declarationGroup,
              specificity,
              allowDisplay: allowDisplay,
            );
          }
        } on FormatException {
          /* An unsupported selector does not discard the chapter. */
        } on UnimplementedError {
          // html's selector evaluator throws this for valid CSS it cannot
          // match, such as :hover, :target, :nth-of-type and ::marker.
          // Keep processing the remaining selectors and declarations.
        }
      }
    }
  }
  for (final image in images) {
    final inline = image.attributes['style'];
    if (inline == null) continue;
    for (final (rule, allowDisplay) in _styleRules(
      'img{$inline}',
      supportedProperties,
      conditionalRules: false,
    )) {
      apply(
        image,
        rule.declarationGroup,
        1000000000,
        allowDisplay: allowDisplay,
      );
    }
  }
  return {
    for (final image in images)
      image: values[image]!.map((key, value) => MapEntry(key, value.value)),
  };
}

const _listStyleTypes = {
  'disc',
  'circle',
  'square',
  'decimal',
  'decimal-leading-zero',
  'lower-alpha',
  'upper-alpha',
  'lower-latin',
  'upper-latin',
  'lower-roman',
  'upper-roman',
  'none',
};

/// Publisher styles commonly sit inside `@media screen`. Only the top-level
/// rule set was read before, so those declarations were lost wholesale.
typedef _StyleRule = (ast.RuleSet, bool);

Iterable<_StyleRule> _screenRules(
  Iterable<ast.TreeNode> nodes, {
  bool allowDisplay = true,
}) sync* {
  for (final node in nodes) {
    if (node is ast.RuleSet) {
      yield (node, allowDisplay);
    } else if (node is ast.MediaDirective) {
      if (_appliesToScreen(node)) {
        // Width, orientation and other viewport features are unknown on import.
        final knownScreen = node.mediaQueries.any(
          (query) =>
              !(query.hasUnary && query.unary == 'NOT') &&
              query.hasMediaType &&
              const {'all', 'screen'}.contains(query.mediaType.toLowerCase()) &&
              query.expressions.isEmpty,
        );
        yield* _screenRules(
          node.rules,
          allowDisplay: allowDisplay && knownScreen,
        );
      }
    } else if (node is ast.SupportsDirective) {
      // A negated condition describes the fallback branch. The reader already
      // ignores unsupported properties; applying that branch would override
      // the authored supported rules instead.
      if (node.condition is ast.SupportsNegation) continue;
      // The reader implements a fixed subset of CSS; keep authored rules and
      // let the supported-property filter discard what it cannot render.
      yield* _screenRules(node.groupRuleBody, allowDisplay: false);
    }
  }
}

bool _appliesToScreen(ast.MediaDirective directive) {
  for (final query in directive.mediaQueries) {
    if (query.hasUnary && query.unary == 'NOT') continue;
    if (!query.hasMediaType) return true;
    final type = query.mediaType.toLowerCase();
    if (type == 'all' || type == 'screen') return true;
  }
  return false;
}

/// A malformed optional declaration must not make the complete book unreadable.
/// csslib currently throws a TypeError for an empty hex color (`color: #;`).
/// Recover only that stylesheet, keeping valid rules and supported declarations
/// in their authored order instead of dropping all its layout information.
Iterable<_StyleRule> _styleRules(
  String text,
  Set<String> supported, {
  bool conditionalRules = true,
}) sync* {
  Iterable<_StyleRule> rules(List<ast.TreeNode> nodes) => conditionalRules
      ? _screenRules(nodes)
      : nodes.whereType<ast.RuleSet>().map((rule) => (rule, true));
  List<ast.TreeNode>? parse(String source) {
    try {
      return css.parse(source).topLevels.toList();
    } on TypeError {
      return null;
    } on FormatException {
      return null;
    }
  }

  final whole = parse(text);
  if (whole != null) {
    yield* rules(whole);
    return;
  }
  var start = 0, open = -1;
  for (final boundary in _cssBoundaries(text)) {
    if (boundary.character == '{') {
      open = boundary.offset;
    } else if (boundary.character == ';') {
      start = boundary.offset + 1;
    } else if (open >= start) {
      final end = boundary.offset;
      final rule = parse(text.substring(start, end + 1));
      if (rule != null) {
        yield* rules(rule);
      } else {
        final selector = text.substring(start, open);
        final body = text.substring(open + 1, end);
        var declarationStart = 0;
        final ends = [
          for (final part in _cssBoundaries(body))
            if (part.character == ';') part.offset,
          body.length,
        ];
        for (final declarationEnd in ends) {
          final declaration = body.substring(declarationStart, declarationEnd);
          declarationStart = declarationEnd + 1;
          // Unsupported properties never affect the reader. Do not send their
          // malformed values back through the parser while recovering a rule.
          final property = declaration
              .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
              .split(':')
              .first
              .trim()
              .toLowerCase();
          if (supported.contains(property)) {
            yield* rules(
              parse('$selector{$declaration}') ?? const <ast.TreeNode>[],
            );
          }
        }
      }
      start = end + 1;
      open = -1;
    }
  }
}

/// Separators inside strings, comments, functions and nested blocks are data,
/// not recovery boundaries (for example a data URL or quoted font name).
Iterable<({int offset, String character})> _cssBoundaries(String text) sync* {
  var quote = 0, round = 0, square = 0, braces = 0;
  for (var i = 0; i < text.length; i++) {
    final code = text.codeUnitAt(i);
    if (quote != 0) {
      if (code == 92) {
        i++;
      } else if (code == quote) {
        quote = 0;
      }
      continue;
    }
    if (code == 47 && i + 1 < text.length && text.codeUnitAt(i + 1) == 42) {
      final end = text.indexOf('*/', i + 2);
      if (end < 0) return;
      i = end + 1;
      continue;
    }
    if (code == 34 || code == 39) {
      quote = code;
      continue;
    }
    if (code == 92) {
      i++;
      continue;
    }
    if (code == 40) round++;
    if (code == 41 && round > 0) round--;
    if (code == 91) square++;
    if (code == 93 && square > 0) square--;
    if (round != 0 || square != 0) continue;
    if (code == 123) {
      if (braces == 0) yield (offset: i, character: '{');
      braces++;
    } else if (code == 125 && braces > 0) {
      braces--;
      if (braces == 0) yield (offset: i, character: '}');
    } else if (code == 59 && braces == 0) {
      yield (offset: i, character: ';');
    }
  }
}
