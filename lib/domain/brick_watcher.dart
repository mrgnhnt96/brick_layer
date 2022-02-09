import 'dart:async';

import 'package:brick_oven/domain/brick_config.dart';
import 'package:watcher/watcher.dart';

/// the function that happens on the file event
typedef OnEvent = void Function();

/// {@template brick_watcher}
/// Watches the local files, and updates on events
/// {@endtemplate}
class BrickWatcher {
  /// {@macro brick_watcher}
  BrickWatcher(String dir) : watcher = DirectoryWatcher(dir);

  /// the source directory of the brick, which will be watched
  final DirectoryWatcher watcher;

  StreamSubscription<WatchEvent>? _listener;

  final _events = <OnEvent>[];

  /// whether the watcher has run
  bool get hasRun => _hasRun;
  var _hasRun = false;

  /// whether the watcher is running
  bool get isRunning => _listener != null && _events.isNotEmpty;

  /// adds event that will be called when a file creates an event
  void addEvent(OnEvent onEvent) {
    _events.add(onEvent);
  }

  /// starts the watcher
  void startWatcher() {
    if (_listener != null) {
      return resetWatcher();
    }

    _listener = watcher.events.listen((watchEvent) {
      _hasRun = true;
      for (final event in _events) {
        logger.info('Running brick_oven');
        event();
      }
    });

    // TODO(mrgnhnt96):
    // - add listener to yaml file
    // - update bricks when yaml is updated? Or stop whole process?
    // - refactor listener, and add tests
  }

  /// resets the watcher
  void resetWatcher() {
    _listener?.cancel();
    _listener = null;

    startWatcher();
  }
}