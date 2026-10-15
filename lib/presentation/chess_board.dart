import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/xiangqi.dart';
import 'palette.dart';

class ChessBoard extends StatefulWidget {
  const ChessBoard({
    super.key,
    required this.position,
    required this.selected,
    required this.targets,
    required this.lastMove,
    required this.onTap,
    required this.enabled,
    this.flipped = false,
    this.suggestionMove,
    this.onCancelSelection,
  });
  final Position position;
  final int? selected;
  final Set<int> targets;
  final Move? lastMove;
  final ValueChanged<int> onTap;
  final bool enabled;
  final bool flipped;
  final Move? suggestionMove;
  final VoidCallback? onCancelSelection;

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {
  final boardFocus = FocusNode(debugLabel: '棋盘');
  final squareKeys = List.generate(90, (_) => GlobalKey());
  late int cursor =
      widget.selected ??
      widget.position.board.indexWhere(
        (piece) =>
            piece?.side == widget.position.turn && piece?.kind == Kind.pawn,
      );
  Position get position => widget.position;
  int? get selected => widget.selected;
  Set<int> get targets => widget.targets;
  Move? get lastMove => widget.lastMove;
  Move? get suggestionMove => widget.suggestionMove;
  bool get enabled => widget.enabled;
  bool get flipped => widget.flipped;

  @override
  void initState() {
    super.initState();
    if (cursor < 0) cursor = 0;
  }

  @override
  void dispose() {
    boardFocus.dispose();
    super.dispose();
  }

  void _revealCursor({bool towardStart = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !boardFocus.hasFocus) return;
      final target = squareKeys[cursor].currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignmentPolicy: towardStart
              ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
              : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape &&
        enabled &&
        selected != null &&
        widget.onCancelSelection != null) {
      widget.onCancelSelection?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      if (enabled && event is KeyDownEvent) widget.onTap(cursor);
      return KeyEventResult.handled;
    }
    final (dr, dc) = switch (key) {
      LogicalKeyboardKey.arrowUp => (-1, 0),
      LogicalKeyboardKey.arrowDown => (1, 0),
      LogicalKeyboardKey.arrowLeft => (0, -1),
      LogicalKeyboardKey.arrowRight => (0, 1),
      _ => (0, 0),
    };
    if (dr == 0 && dc == 0) return KeyEventResult.ignored;
    final visual = flipped ? 89 - cursor : cursor;
    final row = (visual ~/ 9 + dr).clamp(0, 9);
    final col = (visual % 9 + dc).clamp(0, 8);
    setState(() => cursor = flipped ? 89 - (row * 9 + col) : row * 9 + col);
    _revealCursor(towardStart: dr < 0 || dc < 0);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: boardFocus,
    onFocusChange: (_) {
      setState(() {});
    },
    onKeyEvent: _key,
    child: AspectRatio(
      aspectRatio: 9 / 10,
      child: LayoutBuilder(
        builder: (context, box) {
          final cell = box.maxWidth / 9;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFE8CEA3),
              image: const DecorationImage(
                image: AssetImage('assets/art/elm-wood.png'),
                fit: BoxFit.cover,
                opacity: 0.48,
              ),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF70502E), width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x35000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _BoardPainter())),
                for (var i = 0; i < 90; i++)
                  Positioned(
                    left: (flipped ? 89 - i : i) % 9 * cell,
                    top: (flipped ? 89 - i : i) ~/ 9 * cell,
                    width: cell,
                    height: cell,
                    child: Semantics(
                      key: squareKeys[i],
                      button: true,
                      enabled: enabled,
                      selected: selected == i,
                      focused: boardFocus.hasFocus && cursor == i,
                      label:
                          '${i ~/ 9 + 1}行${i % 9 + 1}列，${position.board[i] == null ? '空位' : '${position.board[i]!.side == Side.red ? '红方' : '黑方'}${position.board[i]!.label}'}${targets.contains(i) ? '，可走' : ''}${lastMove?.to == i ? '，上一步落点' : ''}${suggestionMove?.to == i ? '，建议落点' : ''}',
                      child: Tooltip(
                        message: '${i ~/ 9 + 1}行${i % 9 + 1}列',
                        child: InkWell(
                          canRequestFocus: false,
                          onTap: enabled
                              ? () {
                                  setState(() => cursor = i);
                                  boardFocus.requestFocus();
                                  widget.onTap(i);
                                }
                              : null,
                          child: AnimatedContainer(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 140),
                            margin: EdgeInsets.all(cell * 0.035),
                            decoration: BoxDecoration(
                              border: boardFocus.hasFocus && cursor == i
                                  ? Border.all(
                                      color: const Color(0xFF145AA3),
                                      width: 4,
                                    )
                                  : selected == i
                                  ? Border.all(
                                      color: const Color(0xFF155D46),
                                      width: 4,
                                    )
                                  : (lastMove?.to == i || lastMove?.from == i)
                                  ? Border.all(
                                      color: const Color(0xFF796020),
                                      width: 2,
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (position.board[i] != null)
                                  Container(
                                    width: cell * 0.84,
                                    height: cell * 0.84,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const RadialGradient(
                                        center: Alignment(-0.2, -0.3),
                                        colors: [
                                          Color(0xFFFFEBC5),
                                          Color(0xFFEAC58C),
                                          Color(0xFFD3AA6A),
                                        ],
                                        stops: [0, 0.82, 1],
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x65000000),
                                          offset: Offset(0, 2),
                                          blurRadius: 2,
                                        ),
                                      ],
                                      border: Border.all(
                                        color:
                                            position.board[i]!.side == Side.red
                                            ? red
                                            : ink,
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: ExcludeSemantics(
                                        child: Text(
                                          position.board[i]!.label,
                                          textScaler: TextScaler.noScaling,
                                          style: TextStyle(
                                            fontFamily: 'Microsoft YaHei',
                                            fontFamilyFallback: const [
                                              'Noto Sans CJK SC',
                                              'sans-serif',
                                            ],
                                            fontSize: cell * 0.57,
                                            height: 1,
                                            fontWeight: FontWeight.w800,
                                            color:
                                                position.board[i]!.side ==
                                                    Side.red
                                                ? red
                                                : ink,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (targets.contains(i))
                                  Container(
                                    width: position.board[i] == null
                                        ? cell * 0.23
                                        : cell * 0.9,
                                    height: position.board[i] == null
                                        ? cell * 0.23
                                        : cell * 0.9,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: position.board[i] == null
                                          ? const Color(0xFF155D46)
                                          : null,
                                      border: position.board[i] == null
                                          ? null
                                          : Border.all(
                                              color: const Color(0xFF155D46),
                                              width: 4,
                                            ),
                                    ),
                                  ),
                                if (suggestionMove?.from == i ||
                                    suggestionMove?.to == i)
                                  Positioned(
                                    right: 2,
                                    top: 2,
                                    child: Icon(
                                      Icons.lightbulb,
                                      size: cell * .28,
                                      color: const Color(0xFF145AA3),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _BoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 9;
    final pen = Paint()
      ..color = const Color(0xFF76512D)
      ..strokeWidth = 1.3;
    Offset at(double col, double row) =>
        Offset((col + 0.5) * cell, (row + 0.5) * cell);
    for (var row = 0; row < 10; row++) {
      canvas.drawLine(at(0, row.toDouble()), at(8, row.toDouble()), pen);
    }
    for (var col = 0; col < 9; col++) {
      if (col == 0 || col == 8) {
        canvas.drawLine(at(col.toDouble(), 0), at(col.toDouble(), 9), pen);
      } else {
        canvas.drawLine(at(col.toDouble(), 0), at(col.toDouble(), 4), pen);
        canvas.drawLine(at(col.toDouble(), 5), at(col.toDouble(), 9), pen);
      }
    }
    for (final row in [0.0, 7.0]) {
      canvas.drawLine(at(3, row), at(5, row + 2), pen);
      canvas.drawLine(at(5, row), at(3, row + 2), pen);
    }
    final label = TextPainter(
      text: TextSpan(
        text: '楚 河        汉 界',
        style: TextStyle(
          fontFamily: 'Microsoft YaHei',
          fontSize: cell * 0.38,
          color: ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset((size.width - label.width) / 2, 5 * cell - label.height / 2),
    );
  }

  @override
  bool shouldRepaint(_BoardPainter oldDelegate) => false;
}
