bool isValidMobile(String value) => RegExp(r'^[6-9][0-9]{9}$').hasMatch(value);

bool isValidGst(String value) => RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[A-Z0-9]{3}$').hasMatch(value);

bool isStrongPin(String value) => RegExp(r'^[0-9]{4,6}$').hasMatch(value);
