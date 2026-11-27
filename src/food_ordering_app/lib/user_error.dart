import 'dart:async';

import 'package:trek_bikes_app/auth_api.dart';

String userErrorMessage(Object error, String fallback) =>
    error is TimeoutException
    ? 'Máy chủ phản hồi quá lâu. Hãy kiểm tra kết quả trước khi thử lại.'
    : error is ApiException && error.message.trim().isNotEmpty
    ? error.message
    : fallback;
