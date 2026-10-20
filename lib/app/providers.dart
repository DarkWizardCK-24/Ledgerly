import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';

final apiClientProvider = Provider((_) => ApiClient());

final apiStatusProvider = FutureProvider.autoDispose<ApiStatus>(
  (ref) => ref.watch(apiClientProvider).checkStatus(),
);
