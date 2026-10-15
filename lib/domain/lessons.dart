import 'notation.dart';
import 'xiangqi.dart';

enum LessonGroup { endgame, tactic, tutorial }

/// Hand-authored positions and explanations; no third-party puzzle assets.
class ChessLesson {
  const ChessLesson(
    this.id,
    this.group,
    this.title,
    this.instruction,
    this.hint,
    this.explanation,
    this.fen, {
    this.answer,
    this.capture,
  });
  final String id, title, instruction, hint, explanation, fen;
  final LessonGroup group;
  final String? answer;
  final int? capture;
  Position get position => fromFen(fen);
  bool accepts(Position before, Move move) {
    if (group == LessonGroup.endgame) {
      final after = before.play(move);
      return after.legalMoves().isEmpty;
    }
    if (capture case final target?) {
      return move.to == target && before.board[target] != null;
    }
    return move == parseMove(answer!);
  }
}

const lessons = <ChessLesson>[
  ChessLesson(
    'mate-rooks-left',
    LessonGroup.endgame,
    '双车封住宫门',
    '红先，走一步使黑方无棋可走。',
    '一辆车封住退路，另一辆车压到底线。',
    '两辆车各守一条线，黑将既不能逃，也不能吃掉宫外的车。',
    '3k5/2R1R4/9/9/4P4/9/9/9/9/4K4 w - - 0 1',
  ),
  ChessLesson(
    'mate-rooks-right',
    LessonGroup.endgame,
    '换一边再看',
    '红先，走一步结束棋局。',
    '黑将在右侧九宫，观察底线与下一行。',
    '同一种封锁在另一边也能使用，先看将的逃路。',
    '5k3/4R1R2/9/9/4P4/9/9/9/9/4K4 w - - 0 1',
  ),
  ChessLesson(
    'mate-black',
    LessonGroup.endgame,
    '换执黑方',
    '黑先，走一步使红方无棋可走。',
    '黑车也可以用相同的两线封锁。',
    '判断要看棋子配合，不要只记红方的方向。',
    '4k4/9/9/9/4p4/9/9/9/2r1r4/3K5 b - - 0 1',
  ),
  ChessLesson(
    'tactic-cannon',
    LessonGroup.tactic,
    '炮隔一子吃车',
    '红先，用炮吃掉同路的黑车。',
    '炮吃子时，中间恰好隔一个棋子。',
    '红兵是炮架。炮越过一个炮架，才能吃到黑车。',
    '4k4/9/r8/9/9/P3P4/9/C8/9/4K4 w - - 0 1',
    capture: 18,
  ),
  ChessLesson(
    'tactic-horse',
    LessonGroup.tactic,
    '马跳日吃炮',
    '红先，用马吃掉黑炮。',
    '先看马腿有没有被挡住，再看日字的另一端。',
    '马腿畅通，红马跳到黑炮的位置完成吃子。',
    '4k4/9/9/9/9/2c1P4/9/1N7/9/4K4 w - - 0 1',
    capture: 47,
  ),
  ChessLesson(
    'tactic-check',
    LessonGroup.tactic,
    '先应将再吃子',
    '红方正被将军，吃掉黑车解除将军。',
    '看帅能否直接吃掉身边没有保护的车。',
    '被将军时必须先解决将军；这里帅可以安全吃车。',
    '3k5/9/9/9/9/9/9/9/4r4/4K4 w - - 0 1',
    capture: 76,
  ),
  ChessLesson(
    'learn-king',
    LessonGroup.tutorial,
    '帅：九宫一步',
    '请把红帅向前走一格。',
    '点红帅，再点正前方的空位。',
    '将帅每次直走一格，始终留在九宫内。',
    initialFen,
    answer: 'e0e1',
  ),
  ChessLesson(
    'learn-advisor',
    LessonGroup.tutorial,
    '仕：九宫斜走',
    '请把左侧红仕走到九宫中心。',
    '仕沿九宫斜线走一格。',
    '仕不能走出九宫，也不能直走。',
    initialFen,
    answer: 'd0e1',
  ),
  ChessLesson(
    'learn-elephant',
    LessonGroup.tutorial,
    '相：走田不过河',
    '请把左侧红相走到左边线的空位。',
    '相走田字，田字中央不能被堵住。',
    '相不能过河；相眼被堵时不能走。',
    initialFen,
    answer: 'c0a2',
  ),
  ChessLesson(
    'learn-horse',
    LessonGroup.tutorial,
    '马：走日看马腿',
    '请把左侧红马跳到左炮右边的空位。',
    '先直一格，再斜一格，合起来像日字。',
    '马不是直线走；相邻的马腿有子时，对应方向不能跳。',
    initialFen,
    answer: 'b0c2',
  ),
  ChessLesson(
    'learn-rook',
    LessonGroup.tutorial,
    '车：直线通行',
    '请把左侧红车向前走一格。',
    '车沿横线或竖线走，不能越子。',
    '车可以一次走多格，只要中间没有棋子。',
    initialFen,
    answer: 'a0a1',
  ),
  ChessLesson(
    'learn-cannon',
    LessonGroup.tutorial,
    '炮：平走与炮架',
    '请把左侧红炮平移到中路。',
    '不吃子时，炮像车一样走直线。',
    '炮只有在吃子时才需要隔一个炮架。',
    initialFen,
    answer: 'b2e2',
  ),
  ChessLesson(
    'learn-pawn',
    LessonGroup.tutorial,
    '兵：向前不过退',
    '请把最左边的红兵向前走一格。',
    '红方朝棋盘上方前进。',
    '兵卒每次走一格，过河后还能横走，始终不能后退。',
    initialFen,
    answer: 'a3a4',
  ),
];
