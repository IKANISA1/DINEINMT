// Stub implementation for non-web platforms.
// Returns always-online status.

bool isOnline() => true;

Stream<bool> connectivityStream() => const Stream.empty();
