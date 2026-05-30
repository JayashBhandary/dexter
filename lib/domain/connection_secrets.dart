import 'dart:convert';

class ConnectionSecrets {
  const ConnectionSecrets({
    this.password,
    this.serviceAccountJson,
    this.accessKeyId,
    this.secretAccessKey,
    this.sessionToken,
    this.bearerToken,
    this.apiKey,
    this.basicAuth,
  });

  final String? password;
  final String? serviceAccountJson;
  final String? accessKeyId;
  final String? secretAccessKey;
  final String? sessionToken;
  final String? bearerToken;
  final String? apiKey;
  final String? basicAuth;

  bool get isEmpty =>
      password == null &&
      serviceAccountJson == null &&
      accessKeyId == null &&
      secretAccessKey == null &&
      sessionToken == null &&
      bearerToken == null &&
      apiKey == null &&
      basicAuth == null;

  Map<String, Object?> toJson() => {
        if (password != null) 'password': password,
        if (serviceAccountJson != null) 'serviceAccountJson': serviceAccountJson,
        if (accessKeyId != null) 'accessKeyId': accessKeyId,
        if (secretAccessKey != null) 'secretAccessKey': secretAccessKey,
        if (sessionToken != null) 'sessionToken': sessionToken,
        if (bearerToken != null) 'bearerToken': bearerToken,
        if (apiKey != null) 'apiKey': apiKey,
        if (basicAuth != null) 'basicAuth': basicAuth,
      };

  String encode() => jsonEncode(toJson());

  static ConnectionSecrets decode(String raw) {
    final j = jsonDecode(raw) as Map<String, Object?>;
    return ConnectionSecrets(
      password: j['password'] as String?,
      serviceAccountJson: j['serviceAccountJson'] as String?,
      accessKeyId: j['accessKeyId'] as String?,
      secretAccessKey: j['secretAccessKey'] as String?,
      sessionToken: j['sessionToken'] as String?,
      bearerToken: j['bearerToken'] as String?,
      apiKey: j['apiKey'] as String?,
      basicAuth: j['basicAuth'] as String?,
    );
  }
}
