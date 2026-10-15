import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'application/game_controller.dart';
import 'domain/xiangqi.dart';
import 'infrastructure/game_store.dart';
import 'infrastructure/pikafish.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final runtime = await PikafishRuntime.open();
    runApp(
      AnxinApp(
        controller: GameController(
          store: PreferencesGameStore(),
          engine: runtime,
          rules: runtime,
        ),
      ),
    );
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: SelectableText(
                '本地棋力文件未准备好。\n请完整解压安装包后再打开，或按 README 准备引擎与模型。',
                style: TextStyle(fontSize: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const ink = Color(0xFF3E2E22);
const paper = Color(0xFFF1E8D8);
const red = Color(0xFF9D2927);

class AnxinApp extends StatelessWidget {
  const AnxinApp({super.key, required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      title: '安心象棋',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final media = MediaQuery.of(context),
            preferences = controller.preferences;
        return MediaQuery(
          data: media.copyWith(
            textScaler: _EnlargedTextScaler(
              media.textScaler,
              preferences.textScale,
            ),
            disableAnimations:
                media.disableAnimations || preferences.reduceMotion,
          ),
          child: child!,
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: ink, surface: paper),
        scaffoldBackgroundColor: paper,
        fontFamily: 'Microsoft YaHei',
        fontFamilyFallback: const [
          'Microsoft YaHei',
          'Noto Sans CJK SC',
          'sans-serif',
        ],
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 22, color: ink),
          bodyLarge: TextStyle(fontSize: 24, color: ink),
          titleMedium: TextStyle(fontSize: 22, color: ink),
          bodySmall: TextStyle(fontSize: 22, color: ink),
          titleLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: ink,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(56, 60),
            textStyle: const TextStyle(
              fontFamily: 'Microsoft YaHei',
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
            foregroundColor: ink,
            side: const BorderSide(color: ink),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(56, 60),
            textStyle: const TextStyle(
              fontFamily: 'Microsoft YaHei',
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      home: ChessPage(controller: controller),
    ),
  );
}

class _EnlargedTextScaler extends TextScaler {
  const _EnlargedTextScaler(this.system, this.factor);
  final TextScaler system;
  final double factor;
  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;
  @override
  double get textScaleFactor => scale(14) / 14;
}

class ChessPage extends StatefulWidget {
  const ChessPage({super.key, this.controller});
  final GameController? controller;
  @override
  State<ChessPage> createState() => _ChessPageState();
}

class _ChessPageState extends State<ChessPage> {
  late final GameController game;
  int? selected;
  bool get showTargets => game.preferences.showTargets;
  bool flipped = false;
  Move? hintMove;
  int previousPly = -1;
  final controlsScroll = ScrollController();
  @override
  void initState() {
    super.initState();
    game = widget.controller ?? (throw StateError('请先准备本地引擎，再创建棋桌'));
    game.addListener(_changed);
    flipped = game.playerSide == Side.black;
    if (!game.ready) game.initialize();
  }

  void _changed() {
    if (previousPly < 0 && game.ready) flipped = game.playerSide == Side.black;
    if (previousPly != game.ply) {
      previousPly = game.ply;
      selected = null;
      hintMove = null;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    game.removeListener(_changed);
    controlsScroll.dispose();
    if (widget.controller == null) game.dispose();
    super.dispose();
  }

  Future<void> _tap(int index) async {
    if (!game.ready ||
        game.busy ||
        game.position.turn != game.playerSide ||
        game.result != Outcome.playing) {
      return;
    }
    if (game.position.board[index]?.side == game.playerSide) {
      setState(() {
        selected = selected == index ? null : index;
        hintMove = null;
      });
      return;
    }
    if (selected == null) return;
    final move = Move(selected!, index);
    if (game.legalMoves.contains(move)) {
      if (game.preferences.confirmMoves) {
        final before = game.position;
        final moving = before.board[move.from]!,
            captured = before.board[move.to];
        final yes = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('这步确定走吗？'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '这是落子后的样子。框中的${moving.label}是您准备走的棋子。'
                      '${captured == null ? '' : '\n这步会吃掉对方的${captured.label}。'}',
                    ),
                    const SizedBox(height: 12),
                    ChessBoard(
                      position: before.applyUnchecked(move),
                      selected: move.to,
                      targets: const {},
                      lastMove: move,
                      flipped: flipped,
                      onTap: (_) {},
                      enabled: false,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('再想想'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确定落子'),
              ),
            ],
          ),
        );
        if (!mounted || yes != true || !identical(before, game.position)) {
          return;
        }
      }
      setState(() {
        selected = null;
        hintMove = null;
      });
      game.play(move);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              game.forbiddenMoves.contains(move)
                  ? '这步会构成长将或长捉，请换一种走法。'
                  : showTargets
                  ? '这里不能走，请选有圆点的位置。'
                  : '这步不符合走棋规则，请重新选择位置。',
              style: const TextStyle(fontSize: 22),
            ),
          ),
        );
    }
  }

  void _settings() => showDialog<void>(
    context: context,
    builder: (context) => ListenableBuilder(
      listenable: game,
      builder: (context, _) => AlertDialog(
        title: const Text('使用设置'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '文字大小',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              RadioGroup<double>(
                groupValue: game.preferences.textScale,
                onChanged: (v) => game.setPreferences(
                  game.preferences.copyWith(textScale: v),
                ),
                child: const Column(
                  children: [
                    RadioListTile<double>(value: 1, title: Text('标准大字')),
                    RadioListTile<double>(value: 1.2, title: Text('再大一些')),
                    RadioListTile<double>(value: 1.4, title: Text('更大文字')),
                  ],
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('落子前再确认'),
                subtitle: const Text('选好位置后，确认才落子'),
                value: game.preferences.confirmMoves,
                onChanged: (v) => game.setPreferences(
                  game.preferences.copyWith(confirmMoves: v),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('减少动效'),
                value: game.preferences.reduceMotion,
                onChanged: (v) => game.setPreferences(
                  game.preferences.copyWith(reduceMotion: v),
                ),
              ),
              const Text('设置会自动保存。文字会继续跟随系统放大。'),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('设置好了'),
          ),
        ],
      ),
    ),
  );

  Future<void> _restart() async {
    var side = game.playerSide;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('重新开始一盘？'),
          content: SingleChildScrollView(
            child: RadioGroup<Side>(
              groupValue: side,
              onChanged: (v) => update(() => side = v!),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('当前棋局会被新的一盘替换。', style: TextStyle(fontSize: 22)),
                  RadioListTile<Side>(
                    title: const Text('我执红，先走'),
                    value: Side.red,
                  ),
                  RadioListTile<Side>(
                    title: const Text('我执黑，后走'),
                    value: Side.black,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('接着下'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('重新开始'),
            ),
          ],
        ),
      ),
    );
    if (yes == true && mounted) {
      setState(() {
        selected = null;
        hintMove = null;
        flipped = side == Side.black;
      });
      await game.newGame(side: side);
    }
  }

  void _help() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('慢慢下，不着急'),
      content: const SingleChildScrollView(
        child: Text(
          '红棋先走。先点自己的棋子，再点有圆点的位置。新开局时可选执红或执黑。\n\n'
          '“悔一步”会回到您上次落子前。关闭后自动续局，不需要登录或联网。\n\n'
          '将死或无棋可走均判负。长将、长捉由本地引擎判断：违规一方需要换走法，不能换时判负。双方允许不变的重复局面才判和棋。采用公开 Pikafish 的规则口径，未宣称与腾讯或所有竞赛规则完全一致。\n\n'
          '五档电脑都在本机思考。“帮我想想”只提示，不代您落子。“回看棋局”不改变当前棋局。小屏手机建议横向放大或使用平板。',
          style: TextStyle(fontSize: 22),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    ),
  );

  Future<void> _hint() async {
    final move = await game.hint();
    if (mounted && move != null) {
      setState(() {
        selected = move.from;
        hintMove = move;
      });
    }
  }

  void _largeBoard() => showDialog<void>(
    context: context,
    builder: (context) => _LargeBoard(
      game: game,
      onTap: _tap,
      boardBuilder: (onTap) => _board(onTap: onTap),
    ),
  );

  void _review() {
    final positions = game.history, moves = game.moves;
    var step = positions.length - 1;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '回看棋局 · 第 $step 步',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ChessBoard(
                    position: positions[step],
                    selected: null,
                    targets: const {},
                    lastMove: step == 0 ? null : moves[step - 1],
                    onTap: (_) {},
                    enabled: false,
                    flipped: flipped,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: step > 0
                            ? () => update(() => step = 0)
                            : null,
                        child: const Text('开局'),
                      ),
                      OutlinedButton(
                        onPressed: step > 0 ? () => update(() => step--) : null,
                        child: const Text('上一步'),
                      ),
                      OutlinedButton(
                        onPressed: step < positions.length - 1
                            ? () => update(() => step++)
                            : null,
                        child: const Text('下一步'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('回到棋桌'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls({bool compact = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!compact) ...[
        Text('人机对弈', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          '您执${game.playerSide == Side.red ? '红' : '黑'}棋 · 本地对弈',
          style: const TextStyle(fontSize: 22),
        ),
        const SizedBox(height: 20),
        Semantics(
          liveRegion: true,
          child: Text(
            game.ready ? game.status : '正在准备棋盘…',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: ink,
            ),
          ),
        ),
      ],
      if (game.notice != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(game.notice!, style: const TextStyle(fontSize: 22)),
        ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: game.canUndo
                  ? () {
                      setState(() => selected = null);
                      game.undo();
                    }
                  : null,
              child: const Text('悔一步'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed:
                  game.ready &&
                      !game.busy &&
                      game.position.turn == game.playerSide &&
                      game.result == Outcome.playing
                  ? _hint
                  : null,
              child: const Text('帮我想想'),
            ),
          ),
        ],
      ),
      if (!game.busy &&
          game.position.turn != game.playerSide &&
          game.result == Outcome.playing)
        OutlinedButton(
          onPressed: game.retryComputer,
          child: const Text('继续思考'),
        ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: game.ready ? _restart : null,
        child: const Text('重新开始'),
      ),
      const SizedBox(height: 20),
      const Text(
        '陪练难度',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 1; i <= 5; i++)
            Semantics(
              selected: game.level == i,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: game.level == i
                      ? const Color(0xFFE5D0AD)
                      : null,
                  side: BorderSide(color: ink, width: game.level == i ? 3 : 1),
                ),
                onPressed: game.ready ? () => game.setLevel(i) : null,
                child: Text(['入门', '轻松', '日常', '挑战', '高手'][i - 1]),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('显示可走位置', style: TextStyle(fontSize: 22)),
        value: showTargets,
        onChanged: (v) =>
            game.setPreferences(game.preferences.copyWith(showTargets: v)),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: game.ply > 0 ? _review : null,
              child: const Text('回看棋局'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => flipped = !flipped),
              child: const Text('翻转棋盘'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: _largeBoard, child: const Text('放大棋盘')),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: _settings, child: const Text('使用设置')),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: _help, child: const Text('怎么下棋')),
    ],
  );

  Widget _board({ValueChanged<int>? onTap}) {
    final targets = selected == null
        ? <int>{}
        : game.legalMoves
              .where((m) => m.from == selected)
              .map((m) => m.to)
              .toSet();
    return ChessBoard(
      position: game.position,
      selected: selected,
      targets: hintMove != null
          ? {hintMove!.to}
          : showTargets
          ? targets
          : {},
      lastMove: hintMove ?? game.lastMove,
      flipped: flipped,
      onTap: onTap ?? _tap,
      enabled:
          game.ready &&
          !game.busy &&
          game.position.turn == game.playerSide &&
          game.result == Outcome.playing,
    );
  }

  @override
  Widget build(BuildContext context) {
    final board = _board();
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= 1000;
            return SingleChildScrollView(
              padding: EdgeInsets.all(wide ? 28 : 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 24,
                        runSpacing: 8,
                        children: [
                          const Text(
                            '安心象棋',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          if (box.maxWidth > 500)
                            const Text(
                              '无广告 · 不联网',
                              style: TextStyle(fontSize: 22, color: ink),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Center(
                                child: SizedBox(
                                  width: math.min(
                                    660,
                                    math.max(360, box.maxHeight - 170) * 0.9,
                                  ),
                                  child: board,
                                ),
                              ),
                            ),
                            const SizedBox(width: 32),
                            SizedBox(
                              width: 320,
                              height: math.max(200, box.maxHeight - 170),
                              child: ScrollConfiguration(
                                behavior: ScrollConfiguration.of(context)
                                    .copyWith(scrollbars: false),
                                child: Scrollbar(
                                  controller: controlsScroll,
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: controlsScroll,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: _controls(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            game.ready ? game.status : '正在准备棋盘…',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 620),
                            child: board,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _controls(compact: true),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        '点自己的棋子，再点要走的位置。',
                        style: TextStyle(fontSize: 22),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LargeBoard extends StatefulWidget {
  const _LargeBoard({
    required this.game,
    required this.boardBuilder,
    required this.onTap,
  });
  final GameController game;
  final Widget Function(ValueChanged<int>) boardBuilder;
  final Future<void> Function(int) onTap;
  @override
  State<_LargeBoard> createState() => _LargeBoardState();
}

class _LargeBoardState extends State<_LargeBoard> {
  final horizontal = ScrollController(), vertical = ScrollController();
  double zoom = 1;
  @override
  void dispose() {
    horizontal.dispose();
    vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: widget.game,
          builder: (context, _) => Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('回到棋桌'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: zoom > 1
                          ? () => setState(() => zoom -= 0.25)
                          : null,
                      child: const Text('缩小'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('${(zoom * 100).round()}%'),
                    ),
                    OutlinedButton(
                      onPressed: zoom < 2
                          ? () => setState(() => zoom += 0.25)
                          : null,
                      child: const Text('放大'),
                    ),
                    const SizedBox(width: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(widget.game.status),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '滚轮上下移动，拖动底部滚动条左右移动棋盘。',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final width =
                        math.max(540.0, math.min(720.0, box.maxWidth - 32)) *
                        zoom;
                    return Scrollbar(
                      controller: horizontal,
                      thumbVisibility: true,
                      thickness: 14,
                      scrollbarOrientation: ScrollbarOrientation.bottom,
                      notificationPredicate: (n) =>
                          n.metrics.axis == Axis.horizontal,
                      child: Scrollbar(
                        controller: vertical,
                        thumbVisibility: true,
                        thickness: 14,
                        notificationPredicate: (n) =>
                            n.metrics.axis == Axis.vertical,
                        child: SingleChildScrollView(
                          controller: horizontal,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: math.max(width + 32, box.maxWidth),
                            height: box.maxHeight,
                            child: SingleChildScrollView(
                              controller: vertical,
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              child: Center(
                                child: SizedBox(
                                  width: width,
                                  child: widget.boardBuilder((index) async {
                                    await widget.onTap(index);
                                    if (mounted) setState(() {});
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ChessBoard extends StatelessWidget {
  const ChessBoard({
    super.key,
    required this.position,
    required this.selected,
    required this.targets,
    required this.lastMove,
    required this.onTap,
    required this.enabled,
    this.flipped = false,
  });
  final Position position;
  final int? selected;
  final Set<int> targets;
  final Move? lastMove;
  final ValueChanged<int> onTap;
  final bool enabled;
  final bool flipped;
  @override
  Widget build(BuildContext context) => AspectRatio(
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
                    button: true,
                    enabled: enabled,
                    selected: selected == i,
                    label:
                        '${i ~/ 9 + 1}行${i % 9 + 1}列，${position.board[i] == null ? '空位' : '${position.board[i]!.side == Side.red ? '红方' : '黑方'}${position.board[i]!.label}'}${targets.contains(i) ? '，可走' : ''}',
                    child: Tooltip(
                      message: '${i ~/ 9 + 1}行${i % 9 + 1}列',
                      child: InkWell(
                        onTap: enabled ? () => onTap(i) : null,
                        child: AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 140),
                          margin: EdgeInsets.all(cell * 0.035),
                          decoration: BoxDecoration(
                            border: selected == i
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
                                      color: position.board[i]!.side == Side.red
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
