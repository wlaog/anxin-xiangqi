import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/game_record.dart';
import '../domain/xiangqi.dart';

/// A review owns the record captured when it opens, even if play continues.
class GameReviewDialog extends StatefulWidget {
  const GameReviewDialog({
    super.key,
    required this.record,
    required this.boardBuilder,
  });
  final GameRecord record;
  final Widget Function(Position position, Move? lastMove) boardBuilder;

  @override
  State<GameReviewDialog> createState() => _GameReviewDialogState();
}

class _GameReviewDialogState extends State<GameReviewDialog> {
  late int step = widget.record.moves.length;
  final entriesScroll = ScrollController(), contentScroll = ScrollController();
  double entryExtent = 80;
  bool positionedList = false;
  String? copyMessage;
  final copyNoticeKey = GlobalKey();
  final boardSectionKey = GlobalKey();

  void _goTo(int target, {bool showBoard = false, bool fromList = false}) {
    setState(() => step = target);
    if (!fromList) _revealEntry();
    if (showBoard) {
      // Only move the outer review; retain the selected entry's list position.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final board = boardSectionKey.currentContext;
        if (board != null) Scrollable.ensureVisible(board);
      });
    }
  }

  void _revealEntry() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !entriesScroll.hasClients) return;
      entriesScroll.jumpTo(
        ((step - 1) * entryExtent).clamp(
          0.0,
          entriesScroll.position.maxScrollExtent,
        ),
      );
    });
  }

  void _copied(String message) {
    setState(() => copyMessage = message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notice = copyNoticeKey.currentContext;
      if (notice != null) Scrollable.ensureVisible(notice);
    });
  }

  @override
  void dispose() {
    entriesScroll.dispose();
    contentScroll.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.record.toText()));
      if (mounted) _copied('棋谱已复制，可以粘贴到记事本保存。');
    } catch (_) {
      if (mounted) _copied('暂时无法复制棋谱，请稍后再试。');
    }
  }

  Widget _board({required bool compact}) => Column(
    key: boardSectionKey,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Center(
        child: SizedBox(
          width: math.min(480, MediaQuery.sizeOf(context).height * .46),
          child: widget.boardBuilder(
            widget.record.positions[step],
            step == 0 ? null : widget.record.moves[step - 1],
          ),
        ),
      ),
      const SizedBox(height: 12),
      if (compact) ...[
        if (MediaQuery.sizeOf(context).height < 500)
          Text('回看', style: Theme.of(context).textTheme.titleLarge),
        Text(
          '$step / ${widget.record.moves.length} 步',
          semanticsLabel: '第 $step 步，共 ${widget.record.moves.length} 步',
        ),
        const SizedBox(height: 12),
      ],
      Semantics(
        liveRegion: true,
        child: Text(
          step == 0 ? '开局，红方先走' : widget.record.entries[step - 1].description,
        ),
      ),
      if (compact)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('这是打开回看时的棋局，返回后可继续下。'),
        ),
    ],
  );

  Widget _navigation() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton(
        onPressed: step > 0 ? () => _goTo(0) : null,
        child: const Text('开局'),
      ),
      OutlinedButton(
        onPressed: step > 0 ? () => _goTo(step - 1) : null,
        child: const Text('上一步'),
      ),
      OutlinedButton(
        onPressed: step < widget.record.moves.length
            ? () => _goTo(step + 1)
            : null,
        child: const Text('下一步'),
      ),
      OutlinedButton(
        onPressed: step < widget.record.moves.length
            ? () => _goTo(widget.record.moves.length)
            : null,
        child: const Text('最后一步'),
      ),
    ],
  );

  Widget _entries({required bool alongside}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('走棋记录 · 点任一步查看'),
      SizedBox(
        height: alongside ? 420 : 240,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: Scrollbar(
            controller: entriesScroll,
            thumbVisibility: true,
            child: ListView.builder(
              key: const ValueKey('review-move-list'),
              controller: entriesScroll,
              itemCount: widget.record.entries.length,
              itemExtent: entryExtent,
              itemBuilder: (context, index) {
                final entry = widget.record.entries[index];
                return ListTile(
                  key: ValueKey('review-step-${entry.ply}'),
                  selected: step == entry.ply,
                  selectedTileColor: Theme.of(context)
                      .colorScheme
                      .secondaryContainer,
                  title: Text(
                    '${entry.ply}. ${entry.side == Side.red ? '红方' : '黑方'} ${entry.notation}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () =>
                      _goTo(entry.ply, showBoard: !alongside, fromList: true),
                );
              },
            ),
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final size = MediaQuery.sizeOf(context);
    final compact =
        (size.width < 700 || size.height < 500) && scaler.scale(22) > 33;
    entryExtent = math.max(72, scaler.scale(22) * 2.6 + 24);
    if (!positionedList) {
      positionedList = true;
      _revealEntry();
    }
    final content = SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                key: const ValueKey('review-content'),
                controller: contentScroll,
                padding: EdgeInsets.all(compact ? 12 : 16),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final alongside =
                        box.maxWidth >= 700 && scaler.scale(22) <= 33;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!compact || size.height >= 500)
                          Text(
                            compact
                                ? '回看'
                                : '回看棋局 · 第 $step 步 / 共 ${widget.record.moves.length} 步',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        if (!compact) const Text('这是打开回看时的棋局，返回后可继续下。'),
                        if (copyMessage != null)
                          Padding(
                            key: copyNoticeKey,
                            padding: const EdgeInsets.only(top: 12),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(copyMessage!),
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (alongside)
                          Row(
                            key: const ValueKey('review-two-columns'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _board(compact: false),
                                    const SizedBox(height: 12),
                                    _navigation(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 2,
                                child: _entries(alongside: true),
                              ),
                            ],
                          )
                        else ...[
                          _board(compact: compact),
                          const SizedBox(height: 12),
                          _navigation(),
                          const SizedBox(height: 12),
                          _entries(alongside: false),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 12 : 16),
              child: compact
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            onPressed: _copy,
                            child: const Text('复制', semanticsLabel: '复制完整棋谱'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('返回', semanticsLabel: '回到棋桌'),
                          ),
                        ),
                      ],
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _copy,
                          child: const Text('复制完整棋谱'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('回到棋桌'),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
    return compact ? Dialog.fullscreen(child: content) : Dialog(child: content);
  }
}
