import 'dart:io';
import 'package:http/http.dart' as http;
import 'windows_sumup_client.dart';

http.Client createSumupHttpClient() =>
    Platform.isWindows ? WindowsSumupClient() : http.Client();
