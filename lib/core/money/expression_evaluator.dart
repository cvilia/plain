/// Expression evaluator: fixed-point integer arithmetic in cents.
/// See 04-5.1, PRD STORY-1.1.
library;

import 'package:plain/core/money/money.dart';

class EvalResult {
  const EvalResult({required this.money, required this.expression, required this.wasIncomplete});
  final Money money;
  final String expression;
  final bool wasIncomplete;
}

class ExpressionEvaluator {
  const ExpressionEvaluator();

  EvalResult eval(String input) {
    final normalized = _normalize(input);
    if (normalized.isEmpty) {
      return EvalResult(money: Money.zero, expression: input, wasIncomplete: false);
    }
    final tokens = _tokenize(normalized);
    if (tokens.isEmpty) {
      return EvalResult(money: Money.zero, expression: input, wasIncomplete: true);
    }
    final wasIncomplete = _isOperator(tokens.last);
    var end = tokens.length;
    while (end > 0 && _isOperator(tokens[end - 1])) {
      end--;
    }
    if (end == 0) {
      return EvalResult(money: Money.zero, expression: input, wasIncomplete: true);
    }
    return EvalResult(
      money: _evalTokens(tokens.sublist(0, end)),
      expression: input,
      wasIncomplete: wasIncomplete,
    );
  }

  String _normalize(String s) => s
      .replaceAll('\u00d7', '*')
      .replaceAll('\u00f7', '/')
      .replaceAll(' ', '')
      .replaceAll('\uff0d', '-')
      .replaceAll('\uff0b', '+');

  List<String> _tokenize(String s) {
    final tokens = <String>[];
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (_isDigit(c) || c == '.') {
        buf.write(c);
      } else {
        if (buf.isNotEmpty) {
          tokens.add(buf.toString());
          buf.clear();
        }
        if ('+-*/()'.contains(c)) tokens.add(c);
      }
    }
    if (buf.isNotEmpty) tokens.add(buf.toString());
    return tokens;
  }

  bool _isOperator(String t) => t == '+' || t == '-' || t == '*' || t == '/';
  bool _isDigit(String c) => c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;

  Money _evalTokens(List<String> tokens) {
    final output = <String>[];
    final ops = <String>[];
    var prevWasValue = false;
    for (final t in tokens) {
      if (_isDigit(t[0]) || (t.length > 1 && t[0] == '.')) {
        output.add(t);
        prevWasValue = true;
      } else if (t == '(') {
        ops.add(t);
        prevWasValue = false;
      } else if (t == ')') {
        while (ops.isNotEmpty && ops.last != '(') {
          output.add(ops.removeLast());
        }
        if (ops.isNotEmpty) ops.removeLast();
        prevWasValue = true;
      } else {
        if (t == '-' && !prevWasValue) output.add('0');
        while (ops.isNotEmpty && ops.last != '(' && _prec(ops.last) >= _prec(t)) {
          output.add(ops.removeLast());
        }
        ops.add(t);
        prevWasValue = false;
      }
    }
    while (ops.isNotEmpty) {
      output.add(ops.removeLast());
    }
    final stack = <int>[];
    for (final t in output) {
      if (_isDigit(t[0]) || (t.length > 1 && t[0] == '.')) {
        stack.add(_parseCents(t));
      } else if (stack.length >= 2) {
        final b = stack.removeLast();
        final a = stack.removeLast();
        switch (t) {
          case '+':
            stack.add(a + b);
          case '-':
            stack.add(a - b);
          case '*':
            stack.add(_mulCents(a, b));
          case '/':
            stack.add(_divCents(a, b));
        }
      }
    }
    return Money(stack.isEmpty ? 0 : stack.last);
  }

  int _prec(String op) => (op == '+' || op == '-') ? 1 : (op == '*' || op == '/') ? 2 : 0;

  int _parseCents(String yuan) {
    final parts = yuan.split('.');
    final y = parts[0].isEmpty ? 0 : int.parse(parts[0]);
    var c = parts.length == 2 ? parts[1] : '';
    if (c.length > 2) c = c.substring(0, 2);
    while (c.length < 2) {
      c = '${c}0';
    }
    return y * 100 + int.parse(c);
  }

  int _mulCents(int a, int b) {
    final product = a * b;
    return product >= 0 ? (product + 50) ~/ 100 : -((-product + 50) ~/ 100);
  }

  int _divCents(int a, int b) {
    if (b == 0) return 0;
    final scaled = a * 100;
    return scaled >= 0 ? (scaled + (b.abs() ~/ 2)) ~/ b : -((-scaled + (b.abs() ~/ 2)) ~/ b);
  }
}
