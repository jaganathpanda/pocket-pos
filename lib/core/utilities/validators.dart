bool isValidMobile(String value) =>
    RegExp(r'^[6-9][0-9]{9}$').hasMatch(value.trim());

String? validateMobile(String? value, {bool required = false}) {
  final mobile = (value ?? '').trim();
  if (mobile.isEmpty) {
    return required ? 'Mobile number is required' : null;
  }
  return isValidMobile(mobile) ? null : 'Enter a valid 10-digit mobile number';
}

bool isValidGst(String value) =>
    RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[A-Z0-9]{3}$').hasMatch(value);

bool isStrongPin(String value) => RegExp(r'^[0-9]{4,6}$').hasMatch(value);
