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
      final saveRegion = _sourceRegionForSave(source, sourceRegion);
      final steps = <ImageClipPipelineStep>[
        ImageClipPipelineStep.cropRegion(saveRegion),
        if (transform.normalizedRotation != 0)
          ImageClipPipelineStep.rotate(degrees: transform.normalizedRotation),
        if (transform.flipHorizontal)
          const ImageClipPipelineStep.flipHorizontal(),
        if (transform.flipVertical) const ImageClipPipelineStep.flipVertical(),
      ];
      final saveBytes = _sourceImageBytes;
      final sourceLabel = _sourceImageLabel ?? source.label;
      final saveFromOriginal = saveBytes != null && source.isPreviewSized;
      final activeTask = saveFromOriginal
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

  CropRegion _sourceRegionForSave(EditedImage source, CropRegion region) {
    if (!source.isPreviewSized) {
      return region;
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
}
