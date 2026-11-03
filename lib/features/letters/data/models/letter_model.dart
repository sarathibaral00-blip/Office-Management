import '../../domain/entities/letters.dart';

class LetterModel extends Letter {
  LetterModel.fromJson(Map<String, dynamic> j)
    : super(
        j['id'] as String,
        ((j['snapshot'] as Map)['employee'] as Map)['name'] as String,
        j['kind'] as String,
        DateTime.parse(j['created_at'] as String),
      );
}
