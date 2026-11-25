import 'package:trek_bikes_app/auth_api.dart';

String userErrorMessage(Object error, String fallback) =>
    error is ApiException && error.message.trim().isNotEmpty
    ? error.message
    : fallback;
