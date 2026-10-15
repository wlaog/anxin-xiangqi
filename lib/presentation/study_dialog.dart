import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/game_controller.dart';
import '../application/study_notebook.dart';
import '../domain/game_record.dart';
import '../domain/lessons.dart';
import '../domain/rules.dart';
import '../domain/study.dart';
import '../domain/xiangqi.dart';
import '../infrastructure/audio_feedback.dart';
import 'chess_board.dart';
import 'game_review.dart';

class StudyDialog extends StatefulWidget {
  const StudyDialog({super.key, required this.game, required this.notebook});
  final GameController game;
  final StudyNotebook notebook;
  @override
  State<StudyDialog> createState() => _StudyDialogState();
}

class _StudyDialogState extends State<StudyDialog> {
  late StudyTree tree;
  ChessLesson? lesson;
  bool solved = false, busy = false, flipped = false;
  String message = '可以回看实盘、试走两边，也可以选择小题或摆棋。实盘会保留。';
  int? selected;
  Move? suggestion;
  List<Piece?>? editing;
  Side editTurn = Side.red;
  Piece? brush = const Piece(Side.red, Kind.rook);
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    tree = StudyTree(Position.initial(), widget.game.rules);
    // A long live game remains readable in the main review; the demo has a
    // separate, explicit variation limit.
    try {
      tree = StudyTree.fromRecord(_liveRecord(), widget.game.rules);
    } catch (_) {
      message = '当前实盘未能载入研究区，可在棋桌回看；这里仍可练习和摆棋。';
    }
    widget.notebook.addListener(_changed);
    widget.notebook.initialize();
  }

  GameRecord _liveRecord() => GameRecord.fromHistory(
    positions: widget.game.history,
    moves: widget.game.moves,
    playerSide: widget.game.playerSide,
    level: widget.game.level,
    outcome: widget.game.result,
  );
  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (busy) {
      if (widget.game.engine case final HistoryAiEngine native) native.stop();
    }
    widget.notebook.removeListener(_changed);
    AudioFeedback().stop();
    scroll.dispose();
    super.dispose();
  }

  Position get position => editing == null
      ? tree.session.history.last
      : Position(editing!, turn: editTurn);
  void _revealBoard() {
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void _changedBoard([String? text]) {
    selected = null;
    suggestion = null;
    if (text != null) message = text;
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (mounted) setState(() => message = success);
    } catch (_) {
      if (mounted) setState(() => message = '暂时未能完成，当前棋盘和原记录均保留，请重试。');
    }
  }

  Future<void> _tap(int square) async {
    if (busy) return;
    if (editing != null) {
      setState(() {
        editing![square] = brush;
        message = '摆好后点“开始试走”，会先检查局面。';
      });
      return;
    }
    if (solved) return;
    final before = position;
    if (before.board[square]?.side == before.turn) {
      setState(() {
        selected = selected == square ? null : square;
        suggestion = null;
      });
      return;
    }
    if (selected == null) return;
    final move = Move(selected!, square);
    if (tree.session.verdict.result != Outcome.playing ||
        !tree.session.verdict.legal.contains(move)) {
      setState(() => message = '这里不能走，请选择标出的可走位置。');
      return;
    }
    if (lesson != null && !lesson!.accepts(before, move)) {
      setState(() {
        message = '这步合法，还没有达到题目目标。棋盘保留，请再试试；也可以看提示。';
        suggestion = null;
      });
      await _record(false);
      return;
    }
    try {
      tree.play(move);
      final after = position;
      final playedTree = tree;
      final audioResult = AudioFeedback().move(
        before,
        move,
        after,
        widget.game.preferences,
      );
      setState(() {
        _changedBoard(
          lesson == null
              ? studySummary(tree.record, tree.session.moves.length)
              : '完成了！${lesson!.explanation}',
        );
        solved = lesson != null;
      });
      if (lesson != null) await _record(true);
      final notice = await audioResult;
      if (mounted && identical(tree, playedTree) && notice != null) {
        setState(() => message += '\n$notice');
      }
    } catch (_) {
      if (mounted) setState(() => message = '这步暂时不能确认，棋盘保留；请重试或导出已有试走。');
    }
  }

  Future<void> _record(bool success) async {
    final id = lesson!.id;
    try {
      await widget.notebook.record(id, success: success);
    } catch (_) {
      if (mounted && lesson?.id == id) {
        setState(() => message += '\n本次进度没有保存，可以点“重存进度”。');
      }
    }
  }

  Future<bool> _replaceQuestion() async {
    if (tree.nodes.isEmpty && editing == null) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('换一份研究？'),
            content: const SingleChildScrollView(
              child: Text('当前试走不会影响实盘。需要保留时，请先取消并点“保存研究”或“导出棋谱”。'),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('换一份'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _choose(LessonGroup group, {bool retryOnly = false}) async {
    if (busy) return;
    final picked = await showDialog<ChessLesson>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  retryOnly ? '再练' : '选一题',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final item in lessons.where(
                      (l) => retryOnly
                          ? widget.notebook.retry.contains(l.id)
                          : l.group == group,
                    ))
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, item),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${widget.notebook.completed.contains(item.id) ? '已练过 · ' : ''}${item.title}',
                            ),
                          ),
                        ),
                      ),
                    if (retryOnly && widget.notebook.retry.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('还没有需要再练的题。答错不扣分，也不限时。'),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('返回'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted || !await _replaceQuestion() || !mounted) {
      return;
    }
    try {
      final replacement = StudyTree(picked.position, widget.game.rules);
      setState(() {
        tree = replacement;
        lesson = picked;
        editing = null;
        solved = false;
        flipped = picked.position.turn == Side.black;
        _changedBoard(picked.instruction);
      });
      _revealBoard();
    } catch (_) {
      setState(() => message = '这道题暂时不能准备，请选择其他题。');
    }
  }

  Future<void> _hint() async {
    if (lesson != null) {
      setState(() => message = lesson!.hint);
      return;
    }
    if (busy || tree.session.verdict.result != Outcome.playing) return;
    setState(() {
      busy = true;
      message = '电脑正在想，请稍等。';
    });
    try {
      final engine = widget.game.engine;
      final move = engine is HistoryAiEngine
          ? await engine.chooseGame(tree.session.history, tree.session.moves, 3)
          : await engine.choose(position, 3);
      if (!mounted) return;
      if (move == null || !tree.session.verdict.legal.contains(move)) {
        throw StateError('没有合法建议');
      }
      setState(() {
        suggestion = move;
        message =
            '可以考虑：${GameRecordEntry.fromMove(before: position, move: move, ply: tree.session.moves.length + 1).notation}。标记只作建议，不会自动走。';
      });
    } catch (_) {
      if (mounted) setState(() => message = '这次没有想好建议，可以重试。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _edit() async {
    if (!await _replaceQuestion() || !mounted) return;
    setState(() {
      editing = List.of(position.board);
      editTurn = position.turn;
      lesson = null;
      solved = false;
      _changedBoard('先选棋子或“擦除”，再点棋盘。红黑双方都须保留将帅。');
    });
    _revealBoard();
  }

  void _startEditing() {
    try {
      final replacement = StudyTree(position, widget.game.rules);
      setState(() {
        tree = replacement;
        editing = null;
        _changedBoard('局面检查通过，可以手动试走两边。');
      });
    } on FormatException catch (e) {
      setState(() => message = e.message);
    } catch (_) {
      setState(() => message = '局面暂时无法确认，请检查后重试。');
    }
  }

  Future<void> _import() async {
    final source = await showDialog<String>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );
    if (source == null || !mounted) return;
    StudyTree candidate;
    try {
      candidate = importStudy(source, widget.game.rules);
    } on FormatException catch (e) {
      setState(() => message = '未导入：${e.message}。当前研究保留。');
      return;
    } catch (_) {
      setState(() => message = '这份棋谱未能通过校验，当前研究保留。');
      return;
    }
    if (!await _replaceQuestion() || !mounted) return;
    setState(() {
      tree = candidate;
      lesson = null;
      solved = false;
      editing = null;
      _changedBoard('已导入到研究区，实盘保持原样。可回退、换路试走，再保存研究。');
    });
    _revealBoard();
  }

  void _export() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('导出棋谱'),
      content: const SingleChildScrollView(
        child: Text('完整研究保留全部分支；坐标棋谱只保留当前这条路线。复制后可粘贴到记事本保存。'),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => _run(
            () => Clipboard.setData(
              ClipboardData(text: jsonEncode(tree.toJson())),
            ),
            '完整研究已复制，包含全部分支。',
          ),
          child: const Text('复制完整研究'),
        ),
        OutlinedButton(
          onPressed: () => _run(
            () => Clipboard.setData(
              ClipboardData(text: exportCoordinateLine(tree)),
            ),
            '当前路线已复制。',
          ),
          child: const Text('复制当前路线'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('返回'),
        ),
      ],
    ),
  );
  void _review() {
    final record = tree.record;
    showDialog<void>(
      context: context,
      builder: (_) => GameReviewDialog(
        record: record,
        returnLabel: '返回研究',
        contextDescription: '只看当前这条路线。这里说明吃子、将军和无棋可走，不作大师评分。',
        boardBuilder: (p, m) => ChessBoard(
          position: p,
          selected: null,
          targets: const {},
          lastMove: m,
          onTap: (_) {},
          enabled: false,
          flipped: flipped,
        ),
      ),
    );
  }

  Future<void> _saveStudy() async {
    if (widget.notebook.draft != null &&
        jsonEncode(widget.notebook.draft) != jsonEncode(tree.toJson())) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('替换保存的研究？'),
          content: const SingleChildScrollView(
            child: Text('演示版只保存一份研究。要保留以前那份，请先取消，继续旧研究并导出到记事本。'),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('替换'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    await _run(
      () => widget.notebook.saveDraft(tree),
      '本份研究已保存，包含全部分支；下次点“继续研究”。',
    );
  }

  Widget _board() => ChessBoard(
    position: position,
    selected: selected,
    targets: selected == null || editing != null
        ? const {}
        : tree.session.verdict.legal
              .where((m) => m.from == selected)
              .map((m) => m.to)
              .toSet(),
    lastMove: editing == null ? tree.session.moves.lastOrNull : null,
    suggestionMove: suggestion,
    onTap: _tap,
    enabled: !busy && !solved,
    flipped: flipped,
    onCancelSelection: () => setState(() => selected = null),
  );
  Widget _tools() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        lesson?.title ?? (editing != null ? '自由摆棋' : '棋局研究'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (lesson != null && lesson!.instruction != message)
        Text(lesson!.instruction),
      Semantics(liveRegion: true, child: Text(message)),
      if (widget.notebook.notice case final note?) Text(note),
      const SizedBox(height: 12),
      if (editing != null) ...[
        Text(
          '放置：${brush == null ? '擦除' : '${brush!.side == Side.red ? '红' : '黑'}${brush!.label}'}',
        ),
        for (final side in Side.values)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final kind in Kind.values)
                OutlinedButton(
                  onPressed: () => setState(() => brush = Piece(side, kind)),
                  child: Text(
                    '${side == Side.red ? '红' : '黑'}${Piece(side, kind).label}',
                  ),
                ),
            ],
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => brush = null),
              child: const Text('擦除'),
            ),
            OutlinedButton(
              onPressed: () =>
                  setState(() => editing = List.of(Position.initial().board)),
              child: const Text('标准摆法'),
            ),
            OutlinedButton(
              onPressed: () => setState(() {
                editing = List.filled(90, null);
                editing![4] = const Piece(Side.black, Kind.king);
                editing![85] = const Piece(Side.red, Kind.king);
              }),
              child: const Text('只留将帅'),
            ),
          ],
        ),
        RadioGroup<Side>(
          groupValue: editTurn,
          onChanged: (v) => setState(() => editTurn = v!),
          child: const Column(
            children: [
              RadioListTile(value: Side.red, title: Text('红方先走')),
              RadioListTile(value: Side.black, title: Text('黑方先走')),
            ],
          ),
        ),
        FilledButton(onPressed: _startEditing, child: const Text('开始试走')),
        OutlinedButton(
          onPressed: () => setState(() {
            editing = null;
            _changedBoard('已取消摆棋，原研究保留。');
          }),
          child: const Text('取消摆棋'),
        ),
      ] else ...[
        Text(
          '当前 ${tree.session.moves.length} 步 · ${position.turn == Side.red ? '红' : '黑'}方走 · 共 ${tree.nodes.length} 个试走节点',
        ),
        if (tree.session.verdict.result != Outcome.playing)
          const Text('这条路线已结束，可以回退另试。'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: busy || solved ? null : _hint,
              child: Text(lesson == null ? '电脑建议' : '看提示'),
            ),
            OutlinedButton(
              onPressed: busy || tree.cursor == 0
                  ? null
                  : () => setState(() {
                      tree.jump(tree.parent(tree.cursor));
                      solved = false;
                      _changedBoard('已回退，可选择其他走法。');
                    }),
              child: const Text('回退一步'),
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      tree.jump(0);
                      solved = false;
                      _changedBoard(lesson?.instruction ?? '已回到起始位置，原分支仍然保留。');
                    }),
              child: Text(lesson == null ? '回到开头' : '再做一次'),
            ),
            OutlinedButton(
              onPressed: () => setState(() => flipped = !flipped),
              child: const Text('翻转'),
            ),
          ],
        ),
        if (lesson == null) ...[
          if (tree.children().isNotEmpty) const Text('已有后续 · 点选路线，或在棋盘另走一步：'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final index in tree.children())
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          tree.jump(index);
                          _changedBoard(
                            studySummary(
                              tree.record,
                              tree.session.moves.length,
                            ),
                          );
                        }),
                  child: Text(
                    '路线 ${tree.children().indexOf(index) + 1}：${GameRecordEntry.fromMove(before: position, move: tree.nodes[index - 1].move, ply: tree.session.moves.length + 1).notation}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(onPressed: _review, child: const Text('简洁复盘')),
              OutlinedButton(onPressed: _saveStudy, child: const Text('保存研究')),
              OutlinedButton(onPressed: _export, child: const Text('导出棋谱')),
            ],
          ),
        ],
        if (lesson != null)
          OutlinedButton(
            onPressed: () => _record(solved),
            child: const Text('重存进度'),
          ),
        const SizedBox(height: 18),
        const Text('不限时，不扣分，可以反复练。练习与研究都不改变实盘。'),
      if (lesson == null) const Text('试走不会自动保存，离开前请点“保存研究”。'),
        Text('已练过 ${widget.notebook.completed.length} / ${lessons.length} 题'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: busy ? null : () => _choose(LessonGroup.endgame),
              child: const Text('原创残局'),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => _choose(LessonGroup.tactic),
              child: const Text('战术练习'),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => _choose(LessonGroup.tutorial),
              child: const Text('互动教程'),
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => _choose(LessonGroup.tactic, retryOnly: true),
              child: const Text('错题再练'),
            ),
            OutlinedButton(
              onPressed: busy ? null : _edit,
              child: const Text('摆棋'),
            ),
            OutlinedButton(
              onPressed: busy ? null : _import,
              child: const Text('导入棋谱'),
            ),
            OutlinedButton(
              onPressed: busy || widget.notebook.draft == null
                  ? null
                  : () async {
                      StudyTree candidate;
                      try {
                        candidate = StudyTree.fromJson(
                          widget.notebook.draft,
                          widget.game.rules,
                        );
                      } catch (_) {
                        setState(() => message = '保存的研究暂时不能读出，原数据保留，可以导入其他棋谱。');
                        return;
                      }
                      if (!await _replaceQuestion() || !mounted) return;
                      setState(() {
                        tree = candidate;
                        lesson = null;
                        solved = false;
                        _changedBoard('已接着上次保存的研究。');
                      });
                      _revealBoard();
                    },
              child: const Text('继续研究'),
            ),
          ],
        ),
      ],
    ],
  );
  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('练习', style: Theme.of(context).textTheme.titleLarge),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final wide =
                    box.maxWidth >= 1000 &&
                    MediaQuery.textScalerOf(context).scale(22) < 36;
                return SingleChildScrollView(
                  key: const ValueKey('study-scroll'),
                  controller: scroll,
                  padding: const EdgeInsets.all(12),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: math.min(520, box.maxWidth * .46),
                              child: _board(),
                            ),
                            const SizedBox(width: 24),
                            Expanded(child: _tools()),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              child: SizedBox(
                                width: math.min(540, box.maxWidth - 24),
                                child: _board(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _tools(),
                          ],
                        ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();
  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final text = TextEditingController();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('粘贴棋谱'),
    content: SingleChildScrollView(
      child: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '支持本项目导出的完整研究、局面文字，或 a3a4 a6a5 形式的坐标着法。可带起始局面头。暂不支持 XQF、中文着法及带注释或分支的其他棋谱。',
            ),
            TextField(
              key: const ValueKey('study-import-text'),
              controller: text,
              minLines: 3,
              maxLines: 8,
              maxLength: 256 * 1024,
              decoration: const InputDecoration(
                labelText: '棋谱文字',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, text.text),
        child: const Text('检查并导入'),
      ),
    ],
  );
}
