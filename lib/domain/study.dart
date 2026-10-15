import 'dart:convert';

import 'game_record.dart';
import 'game_snapshot.dart';
import 'notation.dart';
import 'rules.dart';
import 'xiangqi.dart';

/// Validation at the custom-position boundary, before calling native code.
void validateStudyPosition(Position position) {
  const limits = [1, 2, 2, 2, 2, 2, 5];
  for (final side in Side.values) {
    final counts = List.filled(7, 0);
    for (var square = 0; square < 90; square++) {
      final piece = position.board[square];
      if (piece == null || piece.side != side) continue;
      counts[piece.kind.index]++;
      final row = side == Side.red ? 9 - square ~/ 9 : square ~/ 9;
      final col = square % 9;
      final valid = switch (piece.kind) {
        Kind.king => row <= 2 && col >= 3 && col <= 5,
        Kind.advisor => {
          (0, 3),
          (0, 5),
          (1, 4),
          (2, 3),
          (2, 5),
        }.contains((row, col)),
        Kind.elephant => {
          (0, 2),
          (0, 6),
          (2, 0),
          (2, 4),
          (2, 8),
          (4, 2),
          (4, 6),
        }.contains((row, col)),
        Kind.pawn => row >= 3 && (row >= 5 || col.isEven),
        _ => true,
      };
      if (!valid) throw FormatException('${piece.label}的位置不符合规则');
    }
    if (counts[0] != 1) throw const FormatException('红黑双方都须恰有一个将或帅');
    for (var i = 0; i < counts.length; i++) {
      if (counts[i] > limits[i]) throw const FormatException('同类棋子数量超出标准棋局');
    }
  }
  if (position.quietPly < 0 || position.quietPly > 120) {
    throw const FormatException('局面的无吃子步数不正确');
  }
  if (position.inCheck(position.turn.opposite)) {
    throw const FormatException('未轮到走棋的一方不能正在被将军；也请检查将帅是否照面');
  }
}

Position parseStudyPosition(String text) {
  final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  final fields = normalized.split(' ');
  if (normalized.length > 200 ||
      !(fields.length == 2 || fields.length == 6) ||
      (fields.length == 6 &&
          (fields[2] != '-' ||
              fields[3] != '-' ||
              !RegExp(r'^\d{1,3}$').hasMatch(fields[4]) ||
              !RegExp(r'^[1-9]\d{0,5}$').hasMatch(fields[5])))) {
    throw const FormatException('局面文字格式不正确');
  }
  final position = fromFen(normalized);
  validateStudyPosition(position);
  return position;
}

class StudyNode {
  const StudyNode(this.parent, this.move);
  final int parent;
  final Move move;
}

/// Parent indices own variation identity. No duplicated line/main-line storage.
class StudyTree {
  StudyTree(Position root, this.rules) : root = root {
    validateStudyPosition(root);
    _session = GameSession.prepare([root], [], rules);
    _sessions.add(_session);
  }
  final Position root;
  final RuleBook rules;
  final List<StudyNode> _nodes = [];
  // Derived, immutable sessions live only as long as this bounded tree.
  // A shared prefix is adjudicated once rather than replayed on every jump.
  final List<GameSession> _sessions = [];
  late GameSession _session;
  int _cursor = 0;
  int get cursor => _cursor;
  List<StudyNode> get nodes => List.unmodifiable(_nodes);
  GameSession get session => _session;
  List<int> children([int? parent]) => [
    for (var i = 0; i < _nodes.length; i++)
      if (_nodes[i].parent == (parent ?? cursor)) i + 1,
  ];
  int parent(int index) => index == 0 ? 0 : _nodes[index - 1].parent;
  GameSession _at(int index) {
    if (index < 0 || index > _nodes.length) {
      throw RangeError.index(index, _nodes);
    }
    return _sessions[index];
  }

  void jump(int index) {
    final replacement = _at(index);
    _session = replacement;
    _cursor = index;
  }

  void play(Move move) {
    final existing = children()
        .where((i) => _nodes[i - 1].move == move)
        .firstOrNull;
    if (existing != null) {
      jump(existing);
      return;
    }
    if (_nodes.length >= 512) {
      throw const FormatException('本份试走已达 512 步，请导出保存后另开一份');
    }
    final next = _session.replay([move], rules);
    _nodes.add(StudyNode(cursor, move));
    _sessions.add(next);
    _cursor = _nodes.length;
    _session = next;
  }

  GameRecord get record => GameRecord.fromHistory(
    positions: session.history,
    moves: session.moves,
    playerSide: root.turn,
    level: 2,
    outcome: session.verdict.result,
  );
  Map<String, Object> toJson() => {
    'format': 'anxin-study',
    'version': 1,
    'position': toFen(root),
    'nodes': [
      for (final n in _nodes) [n.parent, n.move.from, n.move.to],
    ],
    'cursor': cursor,
  };
  factory StudyTree.fromJson(Object? data, RuleBook rules) {
    if (data is! Map ||
        data['format'] != 'anxin-study' ||
        data['version'] != 1 ||
        data['position'] is! String ||
        data['nodes'] is! List ||
        data['cursor'] is! int) {
      throw const FormatException('不是本项目的研究棋谱');
    }
    final rows = data['nodes'] as List;
    if (rows.length > 512) throw const FormatException('试走棋谱过长');
    final tree = StudyTree(parseStudyPosition(data['position']), rules);
    for (final row in rows) {
      if (row is! List ||
          row.length != 3 ||
          row.any((v) => v is! int) ||
          row[0] < 0 ||
          row[0] > tree._nodes.length ||
          row[1] < 0 ||
          row[1] >= 90 ||
          row[2] < 0 ||
          row[2] >= 90) {
        throw const FormatException('试走分支数据不正确');
      }
      tree.jump(row[0]);
      // Reject duplicates instead of silently remapping subsequent parent IDs.
      if (tree.children().any(
        (i) => tree._nodes[i - 1].move == Move(row[1], row[2]),
      )) {
        throw const FormatException('重复的试走分支');
      }
      tree.play(Move(row[1], row[2]));
    }
    if (data['cursor'] < 0 || data['cursor'] > rows.length) {
      throw const FormatException('当前试走位置超出棋谱');
    }
    tree.jump(data['cursor']);
    return tree;
  }
  factory StudyTree.fromRecord(GameRecord record, RuleBook rules) {
    final tree = StudyTree(record.positions.first, rules);
    for (final move in record.moves) {
      tree.play(move);
    }
    return tree;
  }
}

/// Explicitly supported subset: our JSON, position text, coordinate movetext.
/// Numeric/Chinese PGN, comments, variations and XQF are never guessed.
StudyTree importStudy(String text, RuleBook rules) {
  if (text.length > 256 * 1024) {
    throw const FormatException('导入文字过长，请控制在 256K 字符以内');
  }
  final source = text.trim();
  if (source.startsWith('{')) {
    return StudyTree.fromJson(jsonDecode(source), rules);
  }
  if (source.contains('/') && !source.startsWith('[')) {
    return StudyTree(parseStudyPosition(source), rules);
  }
  var body = source;
  Position root = Position.initial();
  if (body.startsWith('[')) {
    final lines = body.split('\n');
    final moves = <String>[];
    var inMoves = false, seenPosition = false;
    String? setup;
    for (final raw in lines) {
      final line = raw.trim();
      if (line.startsWith('[') && !inMoves) {
        final match = RegExp(r'^\[(\w+) "([^"\r\n]*)"\]$').firstMatch(line);
        if (match == null) throw const FormatException('棋谱头部格式不正确');
        if (match[1] == 'FEN') {
          if (seenPosition) throw const FormatException('棋谱含重复的起始局面');
          root = parseStudyPosition(match[2]!);
          seenPosition = true;
        } else if (match[1] == 'Format' && match[2] != 'ICCS') {
          throw const FormatException('此演示版只支持坐标着法格式');
        } else if (match[1] == 'SetUp') {
          if (setup != null || !{'0', '1'}.contains(match[2])) {
            throw const FormatException('起始局面声明不正确');
          }
          setup = match[2];
        } else if (!{
          'Event',
          'Site',
          'Date',
          'Round',
          'Red',
          'Black',
          'White',
          'Result',
          'Format',
          'SetUp',
        }.contains(match[1])) {
          throw const FormatException('此演示版不支持该棋谱头部');
        }
      } else if (line.isNotEmpty) {
        inMoves = true;
        moves.add(line);
      }
    }
    if ((setup == '1' && !seenPosition) || (setup == '0' && seenPosition)) {
      throw const FormatException('起始局面声明与局面文字不一致');
    }
    body = moves.join(' ');
  }
  final tokens = body.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (tokens.isEmpty) throw const FormatException('请粘贴棋谱文字');
  final tree = StudyTree(root, rules);
  var ended = false;
  for (var token in tokens) {
    if (ended) throw const FormatException('结果标记之后不能再有着法');
    if ({'*', '1-0', '0-1', '1/2-1/2'}.contains(token)) {
      ended = true;
      continue;
    }
    token = token.replaceFirst(RegExp(r'^\d+\.(?:\.\.)?'), '');
    if (token.isEmpty) continue;
    if (!RegExp(r'^[a-i][0-9][a-i][0-9]$').hasMatch(token)) {
      throw const FormatException('仅支持 a0a1 形式的坐标着法；暂不支持中文记谱、数字记谱、注释或 XQF');
    }
    tree.play(parseMove(token));
  }
  return tree;
}

String exportCoordinateLine(StudyTree tree) =>
    '[Event "Anxin study"]\n[Format "ICCS"]\n[FEN "${toFen(tree.root)}"]\n\n'
    '${tree.session.moves.map(moveName).join(' ')} *';

String studySummary(GameRecord record, int step) {
  if (step == 0) {
    return '起始局面，${record.positions.first.turn == Side.red ? '红' : '黑'}方先走。';
  }
  final entry = record.entries[step - 1], after = record.positions[step];
  final check = after.inCheck(after.turn);
  final noMoves = after.legalMoves().isEmpty;
  return '${entry.description}${check ? '这步形成将军，对方须先应将。' : ''}'
      '${noMoves ? '对方已无合法走法，本段结束。' : ''}'
      '${entry.captured == null && !check && !noMoves ? '可留意走后是否有子失去保护。' : ''}';
}
