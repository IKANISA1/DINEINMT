import 'package:dinein_app/core/services/api_invoker.dart';

/// A configurable mock [ApiInvoker] for unit testing repositories.
///
/// Usage:
/// ```dart
/// final mock = MockApiInvoker();
/// mock.registerResponse('get_venues', [venueJson1, venueJson2]);
/// final repo = VenueRepository.forTesting(invoker: mock.invoke);
/// ```
class MockApiInvoker {
  /// Registered responses by action name.
  final Map<String, dynamic> _responses = {};

  /// Recorded invocations for verification.
  final List<MockInvocation> invocations = [];

  /// Error to throw for a specific action (simulates network/API errors).
  final Map<String, Exception> _errors = {};

  /// Register a response for a given action.
  void registerResponse(String action, dynamic response) {
    _responses[action] = response;
  }

  /// Register an error to throw for a given action.
  void registerError(String action, Exception error) {
    _errors[action] = error;
  }

  /// Clear all registered responses, errors, and invocation history.
  void reset() {
    _responses.clear();
    _errors.clear();
    invocations.clear();
  }

  /// The invoker function — pass this to repository constructors.
  Future<dynamic> invoke(
    String action, {
    Map<String, dynamic>? payload,
    bool useAdminSession = false,
  }) async {
    invocations.add(
      MockInvocation(
        action: action,
        payload: payload,
        useAdminSession: useAdminSession,
      ),
    );

    if (_errors.containsKey(action)) {
      throw _errors[action]!;
    }

    if (_responses.containsKey(action)) {
      return _responses[action];
    }

    throw Exception(
      'MockApiInvoker: No response registered for action "$action"',
    );
  }

  /// Verify that an action was called at least once.
  bool wasCalled(String action) =>
      invocations.any((inv) => inv.action == action);

  /// Get the number of times an action was called.
  int callCount(String action) =>
      invocations.where((inv) => inv.action == action).length;

  /// Get the last invocation for a given action (for payload inspection).
  MockInvocation? lastInvocation(String action) {
    final matches = invocations.where((inv) => inv.action == action).toList();
    return matches.isNotEmpty ? matches.last : null;
  }
}

/// Record of a single [MockApiInvoker] call.
class MockInvocation {
  final String action;
  final Map<String, dynamic>? payload;
  final bool useAdminSession;

  const MockInvocation({
    required this.action,
    this.payload,
    this.useAdminSession = false,
  });

  @override
  String toString() =>
      'MockInvocation($action, admin=$useAdminSession, payload=$payload)';
}

/// Convenience: a no-op invoker that the typedef satisfies.
ApiInvoker get noOpInvoker => (
      String action, {
      Map<String, dynamic>? payload,
      bool useAdminSession = false,
    }) async =>
        null;
