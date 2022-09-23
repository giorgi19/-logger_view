// ignore_for_file: constant_identifier_names, avoid_multiple_declarations_per_line, prefer_final_locals

import 'package:flutter/material.dart';

class AnsiParser {
  AnsiParser({
    this.dark = true,
  });

  final bool dark;

  static const int TEXT = 0;
  static const int BRACKET = 1;
  static const int CODE = 2;

  Color? foreground;
  List<TextSpan>? spans;

  void parse(String s) {
    spans = <TextSpan>[];
    int state = TEXT;
    late StringBuffer buffer;
    final StringBuffer text = StringBuffer();
    int code = 0;
    late List<int> codes;

    for (int i = 0, n = s.length; i < n; i++) {
      final String c = s[i];

      switch (state) {
        case TEXT:
          if (c == '\u001b') {
            state = BRACKET;
            buffer = StringBuffer(c);
            code = 0;
            codes = <int>[];
          } else {
            text.write(c);
          }
          break;

        case BRACKET:
          buffer.write(c);
          if (c == '[') {
            state = CODE;
          } else {
            state = TEXT;
            text.write(buffer);
          }
          break;

        case CODE:
          buffer.write(c);
          final int codeUnit = c.codeUnitAt(0);
          if (codeUnit >= 48 && codeUnit <= 57) {
            code = code * 10 + codeUnit - 48;
            continue;
          } else if (c == ';') {
            codes.add(code);
            code = 0;
            continue;
          } else {
            if (text.isNotEmpty) {
              spans?.add(createSpan(text.toString()));
              text.clear();
            }
            state = TEXT;
            if (c == 'm') {
              codes.add(code);
              handleCodes(codes);
            } else {
              text.write(buffer);
            }
          }

          break;
      }
    }

    spans?.add(createSpan(text.toString()));
  }

  void handleCodes(List<int> codes) {
    if (codes.isEmpty) {
      codes.add(0);
    }

    switch (codes[0]) {
      case 0:
        foreground = getColor(0, foreground: true);
        // background = getColor(0, false);
        break;
      case 38:
        foreground = getColor(codes[2], foreground: true);
        break;
      case 39:
        foreground = getColor(0, foreground: true);
        break;
      case 48:
        // background = getColor(codes[2], false);
        break;
      case 49:
      // background = getColor(0, false);
    }
  }

  Color getColor(
    int colorCode, {
    required bool foreground,
  }) {
    switch (colorCode) {
      case 0:
        return foreground ? Colors.white : Colors.transparent;
      case 12:
        return dark ? Colors.lightBlue.shade300 : Colors.indigo.shade700;
      case 208:
        return dark ? Colors.orange.shade300 : Colors.orange.shade700;
      case 196:
        return dark ? Colors.red.shade300 : Colors.red.shade700;
      case 199:
        return dark ? Colors.pink.shade300 : Colors.pink.shade700;
      default:
        return Colors.white;
    }
  }

  TextSpan createSpan(String text) {
    return TextSpan(
      text: text,
      style: TextStyle(
        color: foreground ?? (dark ? Colors.white : Colors.black),
      ),
    );
  }
}
