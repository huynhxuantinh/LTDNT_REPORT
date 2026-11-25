import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

bool isNetworkFailure(Object error) =>
    error is SocketException ||
    error is http.ClientException ||
    error is TimeoutException;
