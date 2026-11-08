import 'package:flutter_test/flutter_test.dart';
import 'package:capy_energy/core/app_experience_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final controller = AppExperienceController.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await controller.reset();
  });

  tearDown(() async {
    await controller.reset();
  });

  test('the CarPlay beta is off until asked for, and then persists', () async {
    await controller.load();
    expect(controller.projectionEnabled, isFalse);

    await controller.setProjectionEnabled(true);
    await controller.load();
    expect(controller.projectionEnabled, isTrue);
  });

  test('reset clears the persisted choices', () async {
    await controller.setProjectionEnabled(true);
    await controller.setClimateBarEnabled(true);

    await controller.reset();
    await controller.load();

    expect(controller.projectionEnabled, isFalse);
    expect(controller.climateBarEnabled, isFalse);
  });

  test('the climate bar is off until asked for, and then persists', () async {
    await controller.load();
    expect(controller.climateBarEnabled, isFalse);

    await controller.setClimateBarEnabled(true);
    expect(controller.climateBarEnabled, isTrue);

    await controller.load();
    expect(controller.climateBarEnabled, isTrue);
  });
}
