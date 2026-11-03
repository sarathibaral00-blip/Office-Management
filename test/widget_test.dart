import 'support/weather_scenarios.dart';
import 'support/network_scenarios.dart';
import 'support/payroll_scenarios.dart';
import 'support/workflow_scenarios.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/scenarios.dart';
import 'support/fallback_scenarios.dart';

void main() {
  for (final scenario in {
    ...scenarios,
    ...fallbackScenarios,
    ...workflowScenarios,
    ...payrollScenarios,
    ...networkScenarios,
    ...weatherScenarios,
  }.entries) {
    test(scenario.key, scenario.value);
  }
}
