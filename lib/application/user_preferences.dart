/// Presentation choices are optional fields in the v2 save format.
/// Invalid preferences fall back independently without discarding a sound game.
class UserPreferences {
  const UserPreferences({
    this.showTargets = true,
    this.confirmMoves = false,
    this.reduceMotion = false,
    this.textScale = 1,
  });
  final bool showTargets, confirmMoves, reduceMotion;
  final double textScale;

  factory UserPreferences.fromJson(Object? value) {
    final data = value is Map ? value : const {};
    final scale = data['textScale'];
    return UserPreferences(
      showTargets: data['showTargets'] is bool ? data['showTargets'] : true,
      confirmMoves: data['confirmMoves'] is bool ? data['confirmMoves'] : false,
      reduceMotion: data['reduceMotion'] is bool ? data['reduceMotion'] : false,
      textScale: scale is num && const [1, 1.2, 1.4].contains(scale)
          ? scale.toDouble()
          : 1,
    );
  }

  UserPreferences copyWith({
    bool? showTargets,
    bool? confirmMoves,
    bool? reduceMotion,
    double? textScale,
  }) => UserPreferences(
    showTargets: showTargets ?? this.showTargets,
    confirmMoves: confirmMoves ?? this.confirmMoves,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    textScale: textScale ?? this.textScale,
  );

  Map<String, Object> toJson() => {
    'showTargets': showTargets,
    'confirmMoves': confirmMoves,
    'reduceMotion': reduceMotion,
    'textScale': textScale,
  };
}
