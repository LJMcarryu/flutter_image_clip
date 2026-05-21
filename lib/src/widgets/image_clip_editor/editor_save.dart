// ignore_for_file: invalid_use_of_protected_member

part of '../image_clip_editor.dart';

extension _ImageClipEditorSave on _ImageClipEditorState {
  Future<ImageClipResult?> _saveCropResult({
    required EditedImage source,
    required CropRegion sourceRegion,
    required CropRegion previewRegion,
    required ImageClipCropTransform transform,
  }) async {
    if (_isBusy) {
      return null;
    }
    final taskId = ++_taskSerial;
    _activeTask?.cancel();
    unawaited(_activeProgressSubscription?.cancel());
    _activeProgressSubscription = null;

    setState(() {
      _isBusy = true;
      _progressValue = 0;
      _status = widget.labels.croppingStatus;
    });

    try {
      final visibleRegion = _sourceVisibleRegionForResult(source, sourceRegion);
      final saveRegion = _sourceRegionForSave(source, sourceRegion, transform);
      final steps = <ImageClipPipelineStep>[
        ImageClipPipelineStep.cropRegion(saveRegion),
        if (transform.normalizedRotation != 0)
          ImageClipPipelineStep.rotate(degrees: transform.normalizedRotation),
        if (transform.flipHorizontal)
          const ImageClipPipelineStep.flipHorizontal(),
        if (transform.flipVertical) const ImageClipPipelineStep.flipVertical(),
      ];
      final saveBytes = _sourceImageBytes;
      final savePath = _sourceImagePath;
      final sourceLabel = _sourceImageLabel ?? source.label;
      final saveFromOriginal = source.isPreviewSized;
      final activeTask = savePath != null && saveFromOriginal
          ? _processor.processFileTask(
              savePath,
              label: sourceLabel,
              steps: steps,
              outputSettings: widget.outputSettings,
              operationLabel: 'Crop',
            )
          : saveBytes != null && saveFromOriginal
          ? _processor.processBytesTask(
              saveBytes,
              label: sourceLabel,
              steps: steps,
              outputSettings: widget.outputSettings,
              operationLabel: 'Crop',
            )
          : _processor.processPipelineTask(
              ImageClipPipeline.fromImage(
                source: source,
                steps: steps,
                outputSettings: widget.outputSettings,
                operationLabel: 'Crop',
              ),
            );
      _activeTask = activeTask;
      _listenToProgress(activeTask, taskId);
      final cropped = await activeTask.result;
      if (!mounted || taskId != _taskSerial) {
        return null;
      }
      final result = ImageClipResult(
        source: source,
        cropped: cropped,
        region: saveRegion,
        previewRegion: previewRegion,
        visibleRegion: visibleRegion,
        aspectRatio: _cropAspectRatio,
        rotationDegrees: transform.normalizedRotation,
        flippedHorizontally: transform.flipHorizontal,
        flippedVertically: transform.flipVertical,
      );
      setState(() {
        _isBusy = false;
        _activeTask = null;
        _activeProgressSubscription = null;
        _progressValue = null;
        _status = widget.labels.completedStatus(
          widget.labels.cropCompleteStatus,
          cropped,
        );
      });
      widget.onResult?.call(result);
      if (widget.closeOnSave) {
        Navigator.of(context).pop(result);
        return result;
      }
      if (widget.showResultPage) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => ImageClipResultPage(
              result: result,
              labels: widget.labels,
              theme: widget.theme,
            ),
          ),
        );
      }
      return result;
    } catch (error) {
      if (!mounted || taskId != _taskSerial) {
        return null;
      }
      setState(() {
        _isBusy = false;
        _activeTask = null;
        _activeProgressSubscription = null;
        _progressValue = null;
        _status = widget.labels.errorMessage(error);
      });
      _showMessage(widget.labels.errorMessage(error));
      return null;
    }
  }

  CropRegion _sourceVisibleRegionForResult(
    EditedImage source,
    CropRegion region,
  ) {
    if (!source.isPreviewSized) {
      return region.clampToBounds(
        sourceWidth: source.sourceWidth,
        sourceHeight: source.sourceHeight,
      );
    }

    final scaleX = source.sourceWidth / source.width;
    final scaleY = source.sourceHeight / source.height;
    final x = (region.x * scaleX).round().clamp(0, source.sourceWidth - 1);
    final y = (region.y * scaleY).round().clamp(0, source.sourceHeight - 1);
    return CropRegion(
      x: x.toInt(),
      y: y.toInt(),
      width: (region.width * scaleX)
          .round()
          .clamp(1, source.sourceWidth - x)
          .toInt(),
      height: (region.height * scaleY)
          .round()
          .clamp(1, source.sourceHeight - y)
          .toInt(),
      cornerRadius: region.cornerRadius * ((scaleX + scaleY) / 2),
    );
  }

  CropRegion _sourceRegionForSave(
    EditedImage source,
    CropRegion region,
    ImageClipCropTransform transform,
  ) {
    final sourceRatio = _sourceSaveAspectRatioFor(transform);
    final sourceRatioUnits = _sourceSaveAspectRatioUnitsFor(transform);
    if (!source.isPreviewSized) {
      return region.clampToBounds(
        sourceWidth: source.sourceWidth,
        sourceHeight: source.sourceHeight,
      );
    }

    final scaleX = source.sourceWidth / source.width;
    final scaleY = source.sourceHeight / source.height;
    final x = (region.x * scaleX).round().clamp(0, source.sourceWidth - 1);
    final y = (region.y * scaleY).round().clamp(0, source.sourceHeight - 1);
    final mapped = CropRegion(
      x: x.toInt(),
      y: y.toInt(),
      width: (region.width * scaleX)
          .round()
          .clamp(1, source.sourceWidth - x)
          .toInt(),
      height: (region.height * scaleY)
          .round()
          .clamp(1, source.sourceHeight - y)
          .toInt(),
      cornerRadius: region.cornerRadius * ((scaleX + scaleY) / 2),
    );
    return _aspectLockedRegion(
      mapped,
      sourceWidth: source.sourceWidth,
      sourceHeight: source.sourceHeight,
      targetRatio: sourceRatio,
      ratioUnits: sourceRatioUnits,
    );
  }

  double _sourceSaveAspectRatioFor(ImageClipCropTransform transform) {
    return transform.quarterTurns.isOdd
        ? 1 / _cropAspectRatioValue
        : _cropAspectRatioValue;
  }

  _AspectRatioUnits? _sourceSaveAspectRatioUnitsFor(
    ImageClipCropTransform transform,
  ) {
    final visualWidth = _integerRatioUnitOf(_cropAspectRatio.width);
    final visualHeight = _integerRatioUnitOf(_cropAspectRatio.height);
    if (visualWidth == null || visualHeight == null) {
      return null;
    }
    final sourceWidth = transform.quarterTurns.isOdd
        ? visualHeight
        : visualWidth;
    final sourceHeight = transform.quarterTurns.isOdd
        ? visualWidth
        : visualHeight;
    final divisor = _greatestCommonDivisor(sourceWidth, sourceHeight);
    return _AspectRatioUnits(
      width: sourceWidth ~/ divisor,
      height: sourceHeight ~/ divisor,
    );
  }

  CropRegion _aspectLockedRegion(
    CropRegion region, {
    required int sourceWidth,
    required int sourceHeight,
    required double targetRatio,
    required _AspectRatioUnits? ratioUnits,
  }) {
    final bounded = region.clampToBounds(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
    var width = bounded.width;
    var height = bounded.height;

    if (ratioUnits != null) {
      final units = math.min(
        width ~/ ratioUnits.width,
        height ~/ ratioUnits.height,
      );
      if (units > 0) {
        width = units * ratioUnits.width;
        height = units * ratioUnits.height;
      } else {
        final fitted = _fitRegionSize(width, height, targetRatio);
        width = fitted.width;
        height = fitted.height;
      }
    } else {
      final fitted = _fitRegionSize(width, height, targetRatio);
      width = fitted.width;
      height = fitted.height;
    }

    final x = (bounded.x + (bounded.width - width) / 2)
        .round()
        .clamp(0, sourceWidth - width)
        .toInt();
    final y = (bounded.y + (bounded.height - height) / 2)
        .round()
        .clamp(0, sourceHeight - height)
        .toInt();

    return CropRegion(
      x: x,
      y: y,
      width: width,
      height: height,
      cornerRadius: bounded.cornerRadius.clamp(0, math.min(width, height) / 2),
    );
  }

  ImageClipDimensions _fitRegionSize(
    int availableWidth,
    int availableHeight,
    double targetRatio,
  ) {
    if (!targetRatio.isFinite || targetRatio <= 0) {
      return ImageClipDimensions(
        width: availableWidth,
        height: availableHeight,
      );
    }
    var width = availableWidth;
    var height = (width / targetRatio).round().clamp(1, availableHeight);
    if (height == availableHeight && width / height > targetRatio) {
      width = (height * targetRatio).round().clamp(1, availableWidth);
    }
    return ImageClipDimensions(width: width.toInt(), height: height.toInt());
  }

  int? _integerRatioUnitOf(double value) {
    if (!value.isFinite || value <= 0) {
      return null;
    }
    final rounded = value.round();
    if ((value - rounded).abs() > 0.0001 || rounded <= 0) {
      return null;
    }
    return rounded;
  }
}

class _AspectRatioUnits {
  const _AspectRatioUnits({required this.width, required this.height});

  final int width;
  final int height;
}
