/// Lifecycle of the country pool behind a game.
enum LoadState {
  /// Nothing requested yet.
  idle,

  /// A fetch is in flight.
  loading,

  /// Countries are available and questions can be generated.
  ready,

  /// Both the remote source and the offline fallback failed.
  error,
}
