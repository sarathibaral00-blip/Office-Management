import '../test/support/weather_scenarios.dart';
import '../test/support/network_scenarios.dart';
import '../test/support/payroll_scenarios.dart';
import '../test/support/workflow_scenarios.dart';
import 'dart:io';
import '../test/support/scenarios.dart';
import '../test/support/fallback_scenarios.dart';

Future<void> main() async {
  final all = {
    ...scenarios,
    ...fallbackScenarios,
    ...workflowScenarios,
    ...payrollScenarios,
    ...networkScenarios,
    ...weatherScenarios,
  };
  for (final scenario in all.entries) {
    await scenario.value();
    stdout.writeln('PASS: ${scenario.key}');
  }
  stdout.writeln('${all.length} scenarios passed.');
}
