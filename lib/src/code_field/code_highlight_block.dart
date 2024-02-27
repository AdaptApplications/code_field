import 'package:flutter/material.dart';

class CodeHighlightBlock {
  final int startPosition;
  final int endPosition;
  final TextStyle textStyle;

  CodeHighlightBlock({
    required this.startPosition,
    required this.endPosition,
    required this.textStyle,
  });
}
