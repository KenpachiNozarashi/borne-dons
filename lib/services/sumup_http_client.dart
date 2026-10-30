import 'package:http/http.dart' as http;
import 'sumup_http_client_stub.dart'
    if (dart.library.io) 'sumup_http_client_io.dart'
    as platform;

/// Only SumUp uses this factory; Stripe and local logo requests are unchanged.
http.Client createSumupHttpClient() => platform.createSumupHttpClient();
