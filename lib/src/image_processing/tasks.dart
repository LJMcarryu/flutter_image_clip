part of 'image_processor.dart';

/// A stage emitted by an [ImageClipTask].
enum ImageClipTaskProgressStage {
  /// The task object was created and is waiting for its isolate.
  queued,

  /// The task is decoding image bytes.
  decoding,

  /// The task is applying one or more transformations.
  processing,

  /// The task is encoding the final image bytes.
  encoding,

  /// The task completed successfully.
  completed,
}

/// Progress event emitted by an [ImageClipTask].
class ImageClipTaskProgress {
  /// Creates a progress event.
  const ImageClipTaskProgress({
    required this.stage,
    required this.completedSteps,
    required this.totalSteps,
    required this.message,
  });

  /// Current task stage.
  final ImageClipTaskProgressStage stage;

  /// Number of completed pipeline steps.
  final int completedSteps;

  /// Total number of pipeline steps.
  final int totalSteps;

  /// Human-readable status message.
  final String message;

  /// Progress fraction clamped from 0 to 1.
  double get fraction {
    if (stage == ImageClipTaskProgressStage.completed) {
      return 1;
    }
    if (totalSteps <= 0) {
      return switch (stage) {
        ImageClipTaskProgressStage.queued => 0,
        ImageClipTaskProgressStage.decoding => 0.25,
        ImageClipTaskProgressStage.processing => 0.5,
        ImageClipTaskProgressStage.encoding => 0.85,
        ImageClipTaskProgressStage.completed => 1,
      };
    }
    final processingFraction = (completedSteps / totalSteps)
        .clamp(0, 1)
        .toDouble();
    return switch (stage) {
      ImageClipTaskProgressStage.queued => 0,
      ImageClipTaskProgressStage.decoding => 0.1,
      ImageClipTaskProgressStage.processing => 0.1 + processingFraction * 0.75,
      ImageClipTaskProgressStage.encoding => 0.9,
      ImageClipTaskProgressStage.completed => 1,
    };
  }

  /// Whether this event represents a completed task.
  bool get isCompleted => stage == ImageClipTaskProgressStage.completed;

  @override
  String toString() {
    return 'ImageClipTaskProgress('
        'stage: ${stage.name}, '
        'completedSteps: $completedSteps, '
        'totalSteps: $totalSteps, '
        'message: $message'
        ')';
  }

  @override
  bool operator ==(Object other) {
    return other is ImageClipTaskProgress &&
        other.stage == stage &&
        other.completedSteps == completedSteps &&
        other.totalSteps == totalSteps &&
        other.message == message;
  }

  @override
  int get hashCode => Object.hash(stage, completedSteps, totalSteps, message);

  Map<String, Object?> _toMap() => <String, Object?>{
    'stage': stage.name,
    'completedSteps': completedSteps,
    'totalSteps': totalSteps,
    'message': message,
  };

  static ImageClipTaskProgress _fromMap(Map<Object?, Object?> map) {
    return ImageClipTaskProgress(
      stage: _progressStageFromName(map['stage'] as String?),
      completedSteps: _intOf(map['completedSteps'], fallback: 0),
      totalSteps: _intOf(map['totalSteps'], fallback: 0),
      message: (map['message'] as String?) ?? '',
    );
  }
}

/// Options for a cancelable image processing task.
class ImageClipTaskOptions {
  /// Creates task options.
  const ImageClipTaskOptions({this.timeout, this.onProgress});

  /// Optional timeout after which the task is canceled.
  final Duration? timeout;

  /// Optional callback invoked for every progress event.
  final void Function(ImageClipTaskProgress progress)? onProgress;
}

/// A cancelable image processing task.
class ImageClipTask<T> {
  /// Wraps an existing [future] as an image task.
  factory ImageClipTask.fromFuture(
    Future<T> future, {
    ImageClipTaskOptions? options,
  }) {
    final task = ImageClipTask<T>._manual(
      options ?? const ImageClipTaskOptions(),
    );
    task._bindFuture(future);
    return task;
  }

  ImageClipTask._start(
    Map<String, Object?> request, {
    ImageClipTaskOptions? options,
  }) : _options = options ?? const ImageClipTaskOptions(),
       _onCancel = null {
    _startTimeoutTimer();
    _emitProgress(
      const ImageClipTaskProgress(
        stage: ImageClipTaskProgressStage.queued,
        completedSteps: 0,
        totalSteps: 0,
        message: 'Queued',
      ),
    );
    unawaited(_spawn(request));
  }

  ImageClipTask._manual(this._options, {void Function()? onCancel})
    : _onCancel = onCancel {
    _startTimeoutTimer();
  }

  final ImageClipTaskOptions _options;
  final void Function()? _onCancel;
  final _resultCompleter = Completer<T>();
  final _progressController =
      StreamController<ImageClipTaskProgress>.broadcast();

  ReceivePort? _receivePort;
  Isolate? _isolate;
  Timer? _timeoutTimer;
  bool _isCanceled = false;

  /// Future completed with the task result.
  Future<T> get result => _resultCompleter.future;

  /// Progress events emitted by the task.
  Stream<ImageClipTaskProgress> get progress => _progressController.stream;

  /// Whether this task has been canceled.
  bool get isCanceled => _isCanceled;

  /// Whether this task has completed with a value or error.
  bool get isCompleted => _resultCompleter.isCompleted;

  /// Cancels the task and kills its background isolate.
  bool cancel() {
    return _cancelWith(const ImageClipTaskCanceledException());
  }

  void _bindFuture(Future<T> future) {
    future.then(_complete, onError: _completeError);
  }

  void _startTimeoutTimer() {
    final timeout = _options.timeout;
    if (timeout == null) {
      return;
    }
    _timeoutTimer = Timer(timeout, () {
      _cancelWith(
        ImageClipTaskTimeoutException(
          'Image processing task timed out after ${timeout.inMilliseconds} ms',
          timeout: timeout,
        ),
      );
    });
  }

  Future<void> _spawn(Map<String, Object?> request) async {
    final receivePort = ReceivePort();
    _receivePort = receivePort;

    try {
      final isolate =
          await Isolate.spawn(_imageClipTaskEntrypoint, <String, Object?>{
            'request': _prepareRequestForIsolate(request),
            'sendPort': receivePort.sendPort,
          }, debugName: 'image-job');
      _isolate = isolate;
      if (_isCanceled) {
        isolate.kill(priority: Isolate.immediate);
        return;
      }
    } catch (error, stackTrace) {
      _completeError(error, stackTrace);
      return;
    }

    receivePort.listen((Object? message) {
      if (_resultCompleter.isCompleted) {
        return;
      }
      final map = Map<Object?, Object?>.from(message! as Map);
      final type = map['type'] as String?;
      switch (type) {
        case 'progress':
          _emitProgress(
            ImageClipTaskProgress._fromMap(
              Map<Object?, Object?>.from(map['progress']! as Map),
            ),
          );
          break;
        case 'result':
          _complete(
            EditedImage.fromMap(_editedImageResultFromMessage(map['result']))
                as T,
          );
          break;
        case 'error':
          _completeError(_exceptionFromMap(map));
          break;
      }
    });
  }

  void _emitProgress(ImageClipTaskProgress progress) {
    if (_progressController.isClosed) {
      return;
    }
    _progressController.add(progress);
    _options.onProgress?.call(progress);
  }

  bool _cancelWith(Object error) {
    if (_resultCompleter.isCompleted) {
      return false;
    }
    _isCanceled = true;
    try {
      _onCancel?.call();
    } catch (_) {
      // Cancellation must still complete the task even if custom cleanup fails.
    }
    _isolate?.kill(priority: Isolate.immediate);
    _completeError(error);
    return true;
  }

  void _complete(T value) {
    if (_resultCompleter.isCompleted) {
      return;
    }
    _emitProgress(
      const ImageClipTaskProgress(
        stage: ImageClipTaskProgressStage.completed,
        completedSteps: 1,
        totalSteps: 1,
        message: 'Completed',
      ),
    );
    _resultCompleter.complete(value);
    _dispose();
  }

  void _completeError(Object error, [StackTrace? stackTrace]) {
    if (_resultCompleter.isCompleted) {
      return;
    }
    _resultCompleter.completeError(error, stackTrace);
    _dispose();
  }

  void _dispose() {
    _timeoutTimer?.cancel();
    _receivePort?.close();
    unawaited(_progressController.close());
  }
}

void _imageClipTaskEntrypoint(Map<String, Object?> message) {
  final sendPort = message['sendPort']! as SendPort;
  final request = Map<String, Object?>.from(message['request']! as Map);

  void report(ImageClipTaskProgress progress) {
    sendPort.send(<String, Object?>{
      'type': 'progress',
      'progress': progress._toMap(),
    });
  }

  try {
    final result = _runImageJob(request, reportProgress: report);
    sendPort.send(<String, Object?>{'type': 'result', 'result': result});
  } catch (error) {
    sendPort.send(<String, Object?>{
      'type': 'error',
      ..._exceptionToMap(error),
    });
  }
}

ImageClipTaskProgressStage _progressStageFromName(String? name) {
  for (final stage in ImageClipTaskProgressStage.values) {
    if (stage.name == name) {
      return stage;
    }
  }
  return ImageClipTaskProgressStage.processing;
}

Map<String, Object?> _exceptionToMap(Object error) {
  if (error is ImageClipImageTooLargeException) {
    return <String, Object?>{
      'kind': 'tooLarge',
      'message': error.message,
      'width': error.width,
      'height': error.height,
      'maxPixels': error.maxPixels,
    };
  }
  if (error is ImageClipInvalidCropRegionException) {
    return <String, Object?>{'kind': 'invalidCrop', 'message': error.message};
  }
  if (error is ImageClipDecodeException) {
    return <String, Object?>{'kind': 'decode', 'message': error.message};
  }
  if (error is ImageClipUnsupportedFormatException) {
    return <String, Object?>{
      'kind': 'unsupportedFormat',
      'message': error.message,
      'format': error.format,
    };
  }
  if (error is ImageClipProcessingException) {
    return <String, Object?>{'kind': 'processing', 'message': error.message};
  }
  return <String, Object?>{'kind': 'processing', 'message': error.toString()};
}

Object _exceptionFromMap(Map<Object?, Object?> map) {
  final message = (map['message'] as String?) ?? 'Image processing failed';
  return switch (map['kind'] as String?) {
    'tooLarge' => ImageClipImageTooLargeException(
      message,
      width: _intOf(map['width'], fallback: 0),
      height: _intOf(map['height'], fallback: 0),
      maxPixels: _intOf(map['maxPixels'], fallback: 0),
    ),
    'invalidCrop' => ImageClipInvalidCropRegionException(message),
    'decode' => ImageClipDecodeException(message),
    'unsupportedFormat' => ImageClipUnsupportedFormatException(
      message,
      format: (map['format'] as String?) ?? 'unknown',
    ),
    _ => ImageClipProcessingException(message),
  };
}
