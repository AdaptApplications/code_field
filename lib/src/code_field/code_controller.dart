import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:highlight/highlight_core.dart';

import '../code_modifiers/close_block_code_modifier.dart';
import '../code_modifiers/code_modifier.dart';
import '../code_modifiers/indent_code_modifier.dart';
import '../code_modifiers/tab_code_modifier.dart';
import '../code_theme/code_theme.dart';
import '../code_theme/code_theme_data.dart';
import 'code_auto_complete.dart';
import 'code_highlight_block.dart';
import 'editor_params.dart';

class CodeController extends TextEditingController {
  Mode? _language;
  CodeAutoComplete? autoComplete;

  /// A highlight language to parse the text with
  Mode? get language => _language;

  set language(Mode? language) {
    if (language == _language) {
      return;
    }

    if (language != null) {
      _languageId = language.hashCode.toString();
      highlight.registerLanguage(_languageId, language);
    }

    _language = language;
    notifyListeners();
  }

  List<CodeHighlightBlock>? _highlightBlocks = [];

  /// A list of specific blocks to style
  List<CodeHighlightBlock>? get highlightBlocks => _highlightBlocks;

  set highlightBlocks(List<CodeHighlightBlock>? highlightBlocks) {
    _highlightBlocks = highlightBlocks;
  }

  Map<String, TextStyle>? _stringMap;

  /// A map of specific keywords to style
  Map<String, TextStyle>? get stringMap => _stringMap;

  set stringMap(Map<String, TextStyle>? stringMap) {
    // Build styleRegExp
    final patternList = <String>[];
    if (stringMap != null) {
      patternList.addAll(stringMap.keys.map((e) => r'(\b' + e + r'\b)'));
      _styleList.addAll(stringMap.values);
    }
    if (patternMap != null) {
      patternList.addAll(patternMap!.keys.map((e) => '($e)'));
      _styleList.addAll(patternMap!.values);
    }
    _styleRegExp = RegExp(patternList.join('|'), multiLine: true);
    notifyListeners();
  }

  Map<String, TextStyle>? _patternMap;

  /// A map of specific regexes to style
  Map<String, TextStyle>? get patternMap => _patternMap;

  set patternMap(Map<String, TextStyle>? patternMap) {
    // Build styleRegExp
    final patternList = <String>[];
    if (stringMap != null) {
      patternList.addAll(stringMap!.keys.map((e) => r'(\b' + e + r'\b)'));
      _styleList.addAll(stringMap!.values);
    }
    if (patternMap != null) {
      patternList.addAll(patternMap.keys.map((e) => '($e)'));
      _styleList.addAll(patternMap.values);
    }
    _styleRegExp = RegExp(patternList.join('|'), multiLine: true);
    notifyListeners();
  }

  /// Common editor params such as the size of a tab in spaces
  ///
  /// Will be exposed to all [modifiers]
  final EditorParams params;

  /// A list of code modifiers to dynamically update the code upon certain keystrokes
  final List<CodeModifier> modifiers;

  /* Computed members */
  String _languageId = '';
  final _modifierMap = <String, CodeModifier>{};
  final _styleList = <TextStyle>[];
  RegExp? _styleRegExp;

  String get languageId => _languageId;

  CodeController({
    String? text,
    Mode? language,
    // @Deprecated('Use CodeTheme widget to provide theme to CodeField.')
    //     Map<String, TextStyle>? theme,
    patternMap,
    stringMap,
    highlightBlocks,
    this.params = const EditorParams(),
    this.modifiers = const [
      IndentModifier(),
      CloseBlockModifier(),
      TabModifier(),
    ],
  }) : super(text: text) {
    this.language = language;

    // Create modifier map
    for (final el in modifiers) {
      _modifierMap[el.char] = el;
    }

    // set string map
    stringMap = stringMap;
    patternMap = patternMap;
    this.highlightBlocks = highlightBlocks;
  }

  /// Sets a specific cursor position in the text
  void setCursor(int offset) {
    selection = TextSelection.collapsed(offset: offset);
  }

  /// Replaces the current [selection] by [str]
  void insertStr(String str) {
    final sel = selection;
    text = text.replaceRange(selection.start, selection.end, str);
    final len = str.length;

    selection = sel.copyWith(
      baseOffset: sel.start + len,
      extentOffset: sel.start + len,
    );
  }

  /// Remove the char just before the cursor or the selection
  void removeChar() {
    if (selection.start < 1) {
      return;
    }

    final sel = selection;
    text = text.replaceRange(selection.start - 1, selection.start, '');

    selection = sel.copyWith(
      baseOffset: sel.start - 1,
      extentOffset: sel.start - 1,
    );
  }

  /// Remove the selected text
  void removeSelection() {
    final sel = selection;
    text = text.replaceRange(selection.start, selection.end, '');

    selection = sel.copyWith(
      baseOffset: sel.start,
      extentOffset: sel.start,
    );
  }

  /// Remove the selection or last char if the selection is empty
  void backspace() {
    if (selection.start < selection.end) {
      removeSelection();
    } else {
      removeChar();
    }
  }

  KeyEventResult onKey(RawKeyEvent event) {
    if (autoComplete?.isShowing ?? false) {
      if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
        autoComplete!.current = (autoComplete!.current + 1) % autoComplete!.options.length;
        autoComplete!.panelSetState?.call(() {});
        return KeyEventResult.handled;
      }
      if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
        autoComplete!.current = (autoComplete!.current - 1) % autoComplete!.options.length;
        autoComplete!.panelSetState?.call(() {});
        return KeyEventResult.handled;
      }
      if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
        autoComplete!.selectCurrent();
        return KeyEventResult.handled;
      }
      if (event.isKeyPressed(LogicalKeyboardKey.tab)) {
        autoComplete!.selectCurrent();
        return KeyEventResult.handled;
      }
      if (event.isKeyPressed(LogicalKeyboardKey.escape)) {
        autoComplete!.hide();
        return KeyEventResult.handled;
      }
    }

    if (event.isKeyPressed(LogicalKeyboardKey.tab)) {
      text = text.replaceRange(selection.start, selection.end, '\t');
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  int? _insertedLoc(String a, String b) {
    final sel = selection;

    if (a.length + 1 != b.length || sel.start != sel.end || sel.start < 0) {
      return null;
    }

    return sel.start;
  }

  @override
  set value(TextEditingValue newValue) {
    final loc = _insertedLoc(text, newValue.text);

    if (loc != null) {
      final char = newValue.text[loc];
      final modifier = _modifierMap[char];
      final val = modifier?.updateString(super.text, selection, params);

      if (val != null) {
        // Update newValue
        newValue = newValue.copyWith(
          text: val.text,
          selection: val.selection,
        );
      }
    }
    super.value = newValue;
  }

  TextSpan _processPatterns(String text, TextStyle? style) {
    final children = <TextSpan>[];

    text.splitMapJoin(
      _styleRegExp!,
      onMatch: (Match m) {
        if (_styleList.isEmpty) {
          return '';
        }

        int idx;
        for (idx = 1; idx < m.groupCount && idx <= _styleList.length && m.group(idx) == null; idx++) {}

        children.add(TextSpan(
          text: m[0],
          style: _styleList[idx - 1],
        ));
        return '';
      },
      onNonMatch: (String span) {
        children.add(TextSpan(text: span, style: style));
        return '';
      },
    );

    return TextSpan(style: style, children: children);
  }

  TextSpan _processLanguage(
    String text,
    CodeThemeData? widgetTheme,
    TextStyle? style,
  ) {
    final result = highlight.parse(text, language: _languageId);

    final nodes = result.nodes;

    final children = <TextSpan>[];
    var currentSpans = children;
    final stack = <List<TextSpan>>[];

    void traverse(Node node) {
      var val = node.value;
      final nodeChildren = node.children;
      final nodeStyle = widgetTheme?.styles[node.className];

      if (val != null) {
        var child = TextSpan(text: val, style: nodeStyle);

        if (_styleRegExp != null) {
          child = _processPatterns(val, nodeStyle);
        }

        currentSpans.add(child);
      } else if (nodeChildren != null) {
        List<TextSpan> tmp = [];

        currentSpans.add(TextSpan(
          children: tmp,
          style: nodeStyle,
        ));

        stack.add(currentSpans);
        currentSpans = tmp;

        for (final n in nodeChildren) {
          traverse(n);
          if (n == nodeChildren.last) {
            currentSpans = stack.isEmpty ? children : stack.removeLast();
          }
        }
      }
    }

    if (nodes != null) {
      nodes.forEach(traverse);
    }

    return TextSpan(style: style, children: children);
  }

  TextSpan _processHighlightBlocks(String text, CodeThemeData? widgetTheme, TextStyle style) {
    final children = <TextSpan>[];
    final blocks = _highlightBlocks;
    final orderedBlocks = blocks!.toList()..sort((a, b) => a.startPosition.compareTo(b.startPosition));

    int currentPosition = 0;
    for (final block in orderedBlocks) {
      final blockStart = block.startPosition;
      final blockEnd = block.endPosition;
      final textStyle = block.textStyle;

      if (blockStart < 0 || blockEnd < 0 || blockStart > blockEnd || blockEnd > text.length) {
        continue;
      }

      children
        ..add(_processLanguage(text.substring(currentPosition, blockStart), widgetTheme, style))
        ..add(TextSpan(text: text.substring(blockStart, blockEnd), style: textStyle));
      currentPosition = blockEnd;
    }
    children.add(_processLanguage(text.substring(currentPosition), widgetTheme, style));

    return TextSpan(style: style, children: children);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool? withComposing,
  }) {
    // Return parsing
    if (_highlightBlocks != null) {
      return _processHighlightBlocks(text, CodeTheme.of(context), style!);
    }
    if (_language != null) {
      return _processLanguage(text, CodeTheme.of(context), style);
    }
    if (_styleRegExp != null) {
      return _processPatterns(text, style);
    }
    return TextSpan(text: text, style: style);
  }
}
