enum TimerStatus {
  active('Active', 'Timer is running'),
  running('Running', 'Timer is running'),
  paused('Paused', 'Timer is paused'),
  completed('Completed', 'Timer finished normally'),
  stopped('Stopped', 'Timer stopped manually or emergency');

  const TimerStatus(this.displayName, this.description);

  final String displayName;
  final String description;

  // Helper method to get status from string
  static TimerStatus fromString(String value) {
    return TimerStatus.values.firstWhere(
      (status) => status.name == value.toLowerCase(),
      orElse: () => TimerStatus.active,
    );
  }

  // Helper method to check if timer is running
  bool get isRunning => this == TimerStatus.active || this == TimerStatus.running;

  // Helper method to check if timer is paused
  bool get isPaused => this == TimerStatus.paused;

  // Helper method to check if timer is finished
  bool get isFinished => this == TimerStatus.completed || this == TimerStatus.stopped;

  // Helper method to check if timer can be started
  bool get canStart => this == TimerStatus.paused;

  // Helper method to check if timer can be paused
  bool get canPause => this == TimerStatus.active || this == TimerStatus.running;

  // Helper method to check if timer can be stopped
  bool get canStop => this == TimerStatus.active || this == TimerStatus.running || this == TimerStatus.paused;

  // Helper method to check if timer can be resumed
  bool get canResume => this == TimerStatus.paused;

  // Get icon for this status
  String get icon {
    switch (this) {
      case TimerStatus.active:
      case TimerStatus.running:
        return '▶️';
      case TimerStatus.paused:
        return '⏸️';
      case TimerStatus.completed:
        return '✅';
      case TimerStatus.stopped:
        return '⏹️';
    }
  }

  // Get color for this status
  int get color {
    switch (this) {
      case TimerStatus.active:
      case TimerStatus.running:
        return 0xFF4CAF50; // Green
      case TimerStatus.paused:
        return 0xFFFF9800; // Orange
      case TimerStatus.completed:
        return 0xFF2196F3; // Blue
      case TimerStatus.stopped:
        return 0xFFF44336; // Red
    }
  }

  @override
  String toString() => displayName;
}
