import 'package:flutter/material.dart';

import '../application/game_controller.dart';
import '../application/game_library.dart';
import '../domain/game_snapshot.dart';
import '../domain/xiangqi.dart';
import 'game_review.dart';

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title});
  final String title;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final text = TextEditingController(text: widget.title);
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('给这盘棋改个名字'),
    content: SingleChildScrollView(
      child: TextField(
        controller: text,
        autofocus: true,
        maxLength: 80,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: '棋局名称'),
      ),
    ),
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: text.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, text.text.trim()),
        child: const Text('保存名称'),
      ),
    ],
  );
}

class GameLibraryDialog extends StatefulWidget {
  const GameLibraryDialog({
    super.key,
    required this.game,
    required this.boardBuilder,
  });
  final GameController game;
  final Widget Function(Position, Move?) boardBuilder;

  @override
  State<GameLibraryDialog> createState() => _GameLibraryDialogState();
}

class _GameLibraryDialogState extends State<GameLibraryDialog> {
  GameLibrary get library => widget.game.library!;
  bool favorites = false, working = false;
  String? message;
  final scroll = ScrollController();

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<bool> _run(Future<void> Function() action, String success) async {
    setState(() {
      working = true;
      message = null;
    });
    var ok = false;
    try {
      await action();
      ok = true;
    } catch (_) {
      /* Keep the committed list, and offer a retry. */
    }
    if (mounted) {
      setState(() {
        working = false;
        message = ok ? success : '暂时无法保存这次修改，原数据已保留。请稍后再试。';
      });
      if (scroll.hasClients) scroll.jumpTo(0);
    }
    return ok;
  }

  Future<void> _review(GameSnapshot snapshot, {bool saved = true}) async {
    try {
      final record = widget.game.readRecord(snapshot);
      await showDialog<void>(
        context: context,
        builder: (_) => GameReviewDialog(
          record: record,
          boardBuilder: widget.boardBuilder,
          contextDescription: saved ? '这是保存的棋谱，查看不会改变正在下的棋。' : null,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => message = '这份棋谱暂时无法打开，原数据已保留，其他棋谱仍可查看。');
    }
  }

  Future<void> _rename(LibraryEntry entry) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(title: entry.title),
    );
    if (title != null && mounted) {
      await _run(() => library.rename(entry.id, title), '名称已保存。');
    }
  }

  Future<void> _delete(LibraryEntry entry) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这份棋谱？'),
        content: SingleChildScrollView(
          child: Text('“${entry.title}”删除后无法找回。正在下的棋不会改变。'),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await _run(() => library.remove(entry.id), '这份棋谱已删除。');
    }
  }

  Future<void> _continue(LibraryEntry entry) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('继续这盘棋？'),
        content: const SingleChildScrollView(
          child: Text('当前棋局会先保存到“我的棋局”，再打开选中的棋局。'),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续这盘'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => working = true);
    final ok = await widget.game.continueGame(entry);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        working = false;
        message = widget.game.notice;
      });
      if (scroll.hasClients) scroll.jumpTo(0);
    }
  }

  Widget _entryCard(LibraryEntry entry, bool disabled) => Card(
    key: ValueKey('library-${entry.id}'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.favorite ? '★ ' : ''}${entry.title}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            '${entry.snapshot.moves.length} 步 · 您执${entry.snapshot.side == Side.red ? '红' : '黑'}棋',
          ),
          Text(
            '保存于 ${entry.updated.toLocal().year}年${entry.updated.toLocal().month}月${entry.updated.toLocal().day}日 ${entry.updated.toLocal().hour.toString().padLeft(2, '0')}:${entry.updated.toLocal().minute.toString().padLeft(2, '0')}',
          ),
          if (entry.id == widget.game.gameId) const Text('当前棋局的保存副本；新走法可再次保存。'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: disabled ? null : () => _review(entry.snapshot),
                child: const Text('查看棋谱'),
              ),
              if (entry.id != widget.game.gameId)
                OutlinedButton(
                  onPressed: disabled ? null : () => _continue(entry),
                  child: const Text('继续这盘'),
                ),
              OutlinedButton(
                onPressed: disabled ? null : () => _rename(entry),
                child: const Text('改名'),
              ),
              OutlinedButton(
                onPressed: disabled
                    ? null
                    : () => _run(
                        () => library.favorite(entry.id, !entry.favorite),
                        entry.favorite ? '已取消收藏。' : '已收藏。',
                      ),
                child: Text(entry.favorite ? '取消收藏' : '收藏'),
              ),
              OutlinedButton(
                onPressed: disabled ? null : () => _delete(entry),
                child: const Text('删除'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([library, widget.game]),
        builder: (context, _) {
          final entries = library.entries
              .where((e) => !favorites || e.favorite)
              .toList();
          final disabled = working || library.saving;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  '我的棋局',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length + 1,
                  itemBuilder: (context, index) {
                    if (index > 0) {
                      return _entryCard(entries[index - 1], disabled);
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (message != null)
                          Semantics(liveRegion: true, child: Text(message!)),
                        if (library.notice != null) Text(library.notice!),
                        if (!library.ready) const Text('正在读取棋局库，请稍等。'),
                        const Text('棋谱只保存在这台设备上。查看旧棋不会改变正在下的棋。'),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '当前正在下 · ${widget.game.ply} 步',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                if (widget.game.ply > 0)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton(
                                        onPressed:
                                            disabled || widget.game.ply == 0
                                            ? null
                                            : () => _review(
                                                widget.game.snapshot,
                                                saved: false,
                                              ),
                                        child: const Text('回看本局'),
                                      ),
                                      FilledButton(
                                        onPressed:
                                            disabled ||
                                                widget.game.ply == 0 ||
                                                !library.writable
                                            ? null
                                            : () => _run(
                                                widget.game.saveToLibrary,
                                                '当前棋局已保存。之后的新走法可再次保存。',
                                              ),
                                        child: const Text('保存本局'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('只看收藏'),
                          value: favorites,
                          onChanged: (v) => setState(() => favorites = v!),
                        ),
                        const Text('已保存的棋谱'),
                        if (library.ready &&
                            library.writable &&
                            entries.isEmpty)
                          Text(
                            favorites ? '还没有收藏的棋局。' : '还没有保存的棋局。重新开始前会自动保存当前盘。',
                          ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: working ? null : () => Navigator.pop(context),
                  child: const Text('回到棋桌'),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
