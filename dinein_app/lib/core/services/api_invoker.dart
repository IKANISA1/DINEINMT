/// Typedef for the DineIn API invoker function.
///
/// Allows injection of a mock/stub invoker for repository unit testing.
///
/// In production code the default is [DineinApiService.invoke]. Tests can
/// provide their own implementation that returns predetermined responses
/// without requiring a live Supabase backend.
typedef ApiInvoker = Future<dynamic> Function(
  String action, {
  Map<String, dynamic>? payload,
  bool useAdminSession,
});
