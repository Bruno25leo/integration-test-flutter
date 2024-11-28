import 'dart:convert';
import 'dart:io';

void main() async {
  const jsonFilePath = 'tests.jsonl';
  final jsonContent = await File(jsonFilePath).readAsString();
  final lines = jsonContent.split('\n').where((line) => line.isNotEmpty);
  final events = lines.map((line) => json.decode(line));

  List<Map<String, dynamic>> tests = [];
  Map<int, String> testNames = {};
  Map<int, String> testResults = {};
  // Map<int, double> testDurations = {};
  Map<int, List<String>> errorMessages = {};
  Map<String, String> globalSetups = {};
  int totalTests = 0, totalSuccess = 0, totalFailures = 0;

  for (var event in events) {
    switch (event['type']) {
      case 'testStart':
        if (!event['test']['name'].startsWith('loading') && event['test']['name'] != '(tearDownAll)') {
          testNames[event['test']['id']] = event['test']['name'];
          tests.add({
            'id': event['test']['id'],
            'name': event['test']['name'],
            'status': 'Running',
            'startTime': event['time']
          });
        }
        break;

      case 'testDone':
        if (testNames.containsKey(event['testID'])) {
          var test = tests.firstWhere((t) => t['id'] == event['testID']);
          test['status'] = event['result'];
          test['endTime'] = event['time'];
          test['duration'] = (test['endTime'] - test['startTime']) / 1000;
          testResults[event['testID']] = event['result'];
          
          totalTests++;
          if (event['result'] == 'success') {
            totalSuccess++;
          } else {
            totalFailures++;
            test['hasError'] = true;
          }
        }
        break;

      case 'print':
        final testID = event['testID'];
        errorMessages.putIfAbsent(testID, () => []).add(event['message']);
        break;

      case 'error':
        final testID = event['testID'];
        errorMessages.putIfAbsent(testID, () => []).add("Error: ${event['error']}\nStack Trace:\n${event['stackTrace']}");
        break;

      }
  }

  final htmlContent = generateHtmlReport(tests, errorMessages, globalSetups, totalTests, totalSuccess, totalFailures);
  const outputHtmlFile = 'test_schema_report.html';
  await File(outputHtmlFile).writeAsString(htmlContent);

  print('Relatório HTML gerado: $outputHtmlFile');
}

String generateHtmlReport(List<Map<String, dynamic>> tests, Map<int, List<String>> errorMessages, Map<String, String> globalSetups, int totalTests, int totalSuccess, int totalFailures) {
  final buffer = StringBuffer();
  buffer.writeln('''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Test Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f4; color: #333; }
        .summary { padding: 20px; text-align: center; background-color: #2c3e50; color: #ecf0f1; }
        table { width: 80%; margin: 20px auto; border-collapse: collapse; box-shadow: 0px 0px 15px rgba(0,0,0,0.1); }
        th, td { padding: 12px; border: 1px solid #ddd; text-align: center; }
        th { background-color: #27ae60; color: white; font-weight: bold; }
        .success { background-color: #2ecc71; color: white; padding: 6px 12px; border-radius: 5px; }
        .failure { background-color: #e74c3c; color: white; padding: 6px 12px; border-radius: 5px; }
        .setup-summary, .results-summary { width: 80%; margin: 20px auto; padding: 15px; background-color: #3498db; color: white; text-align: left; border-radius: 8px; box-shadow: 0px 0px 15px rgba(0,0,0,0.1); }
        .setup { font-size: 1.2em; font-weight: bold; }
        .error-details { font-size: 0.95em; color: #c0392b; background-color: #ecf0f1; padding: 8px; border-radius: 5px; }
        .error-details pre { background-color: #e1e1e1; padding: 10px; border-radius: 5px; white-space: pre-wrap; font-size: 0.9em; }
        h1, h3 { font-family: 'Segoe UI', sans-serif; }
        h1 { font-size: 2.5em; }
        h3 { margin-bottom: 10px; }
        .badge { display: inline-block; padding: 10px 20px; margin: 10px; border-radius: 15px; font-size: 1.2em; }
        .badge-success { background-color: #27ae60; color: #fff; }
        .badge-failure { background-color: #e74c3c; color: #fff; }
        .badge-info { background-color: #3498db; color: #fff; }
    </style>
</head>
<body>
    <div class="summary">
        <h1>Schema-Based Integration Test Report</h1>
        <p>Generated Report of Test Results</p>
    </div>
    <div class="setup-summary">
        <h3>Global Setup</h3>
        <p><span class="setup">${globalSetups['setUpAll'] ?? 'Not Executed'}</span></p>
    </div>
    <div class="setup-summary">
        <h3>Global TearDown</h3>
        <p><span class="setup">${globalSetups['tearDownAll'] ?? 'Not Executed'}</span></p>
    </div>
    <div class="results-summary">
        <h3>Overall Results</h3>
        <p><span class="badge badge-info">Total Tests Executed: $totalTests</span></p>
        <p><span class="badge badge-success">Total Success: $totalSuccess</span></p>
        <p><span class="badge badge-failure">Total Failures: $totalFailures</span></p>
    </div>
    <table>
        <thead>
            <tr>
                <th>Test Name</th>
                <th>Status</th>
                <th>Duration (seconds)</th>
                <th>Details</th>
            </tr>
        </thead>
        <tbody>
  ''');

  for (var test in tests) {
    final statusClass = test['status'] == 'success' ? 'success' : 'failure';
    final errorDetail = errorMessages.containsKey(test['id']) 
      ? '<strong>Logs:</strong><br><pre>${errorMessages[test['id']]?.join("\n")}</pre>' 
      : "No issues";
    buffer.writeln('''
        <tr>
            <td>${test['name']}</td>
            <td class="$statusClass">${test['status']}</td>
            <td>${test['duration']?.toStringAsFixed(2) ?? '-'}</td>
            <td><div class="error-details">$errorDetail</div></td>
        </tr>
    ''');
  }

  buffer.writeln('''
        </tbody>
    </table>
</body>
</html>
  ''');
  return buffer.toString();
}
