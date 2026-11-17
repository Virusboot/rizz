import 'package:flutter_test/flutter_test.dart';
import 'package:rizz/models.dart';

void main() {
  test('ageFrom counts full years only', () {
    final now = DateTime.now();
    expect(ageFrom(DateTime(now.year - 20, now.month, now.day)), 20);
    // One day before the 20th birthday.
    expect(ageFrom(DateTime(now.year - 20, now.month, now.day + 1)), 19);
  });

  test('wants matches gender to interest', () {
    expect(wants('men', 'man'), isTrue);
    expect(wants('men', 'woman'), isFalse);
    expect(wants('women', 'woman'), isTrue);
    expect(wants('women', 'nonbinary'), isFalse);
    expect(wants('everyone', 'nonbinary'), isTrue);
  });

  test('intent compatibility', () {
    expect(intentCompatible(LookingFor.dating, LookingFor.dating), isTrue);
    expect(intentCompatible(LookingFor.dating, LookingFor.casual), isFalse);
    expect(intentCompatible(LookingFor.both, LookingFor.casual), isTrue);
    expect(intentCompatible(LookingFor.dating, LookingFor.both), isTrue);
  });

  test('intentFrom falls back to both', () {
    expect(intentFrom('dating'), LookingFor.dating);
    expect(intentFrom('casual'), LookingFor.casual);
    expect(intentFrom(null), LookingFor.both);
    expect(intentFrom('nonsense'), LookingFor.both);
  });
}
