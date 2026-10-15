/// Presentation choices are optional fields in the v2 save format.
/// Invalid preferences fall back independently without discarding a sound game.
class UserPreferences {
  const UserPreferences({
    this.showTargets = true,
    this.confirmMoves = false,
    this.reduceMotion = false,
    this.textScale = 1,
    this.sound = false,
    this.speech = false,
  });
  final bool showTargets, confirmMoves, reduceMotion;
  final double textScale;
  final bool sound, speech;

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
      sound: data['sound'] is bool ? data['sound'] : false,
      speech: data['speech'] is bool ? data['speech'] : false,
    );
  }

  UserPreferences copyWith({
    bool? showTargets,
    bool? confirmMoves,
    bool? reduceMotion,
    double? textScale,
    bool? sound,
    bool? speech,
  }) => UserPreferences(
    showTargets: showTargets ?? this.showTargets,
    confirmMoves: confirmMoves ?? this.confirmMoves,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    textScale: textScale ?? this.textScale,
    sound: sound ?? this.sound,
    speech: speech ?? this.speech,
  );

  Map<String, Object> toJson() => {
    'showTargets': showTargets,
    'confirmMoves': confirmMoves,
    'reduceMotion': reduceMotion,
    'textScale': textScale,
    'sound': sound,
    'speech': speech,
  };
}
