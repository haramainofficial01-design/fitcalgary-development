/// Wait for a watched provider to refresh without leaking its failure through
/// RefreshIndicator. The provider retains the error and the screen renders its
/// existing error/retry state; this does not replace failed data with success.
Future<void> settleProviderRefresh(Future<Object?> pending) async {
  try {
    await pending;
  } catch (_) {
    // The watched AsyncValue owns presentation of this failure.
  }
}
