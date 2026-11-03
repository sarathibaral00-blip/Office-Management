String letterTitle(String kind) => switch (kind) {
  'appointment' => 'Appointment letter',
  'confirmation' => 'Confirmation letter',
  'experience' => 'Experience certificate',
  'salary_certificate' => 'Salary certificate',
  'noc' => 'No objection certificate',
  _ => 'Employee letter',
};
String letterBody(String kind, Map employee, Map company) {
  final name = employee['name'],
      designation = employee['designation'] ?? 'employee',
      joined = employee['joined_at'],
      salary = employee['salary'],
      currency = company['currency'];
  return switch (kind) {
    'appointment' =>
      'We are pleased to appoint $name as $designation with ${company['name']}, effective $joined. The monthly salary is $currency $salary. The appointment is subject to the terms stated below and the company’s approved policies.',
    'confirmation' =>
      'This letter confirms that $name, serving as $designation since $joined, is confirmed in their position with ${company['name']}, subject to the effective date and terms stated below.',
    'experience' =>
      'This is to certify that $name has served with ${company['name']} as $designation since $joined. The period and nature of service certified for this request are set out below.',
    'salary_certificate' =>
      'This is to certify that $name ($designation), employed since $joined, has a structured monthly gross salary of $currency $salary. This certificate is issued for the purpose stated below.',
    'noc' =>
      '${company['name']} has no objection to $name, employed as $designation since $joined, undertaking the purpose described below, subject to the conditions and approved dates stated in this letter.',
    _ => throw const FormatException('Unsupported letter template'),
  };
}
