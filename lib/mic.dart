import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mic/mic.dart';

import 'src/file_service.dart';
export 'src/mic_state.dart';

class MicPlugin {
  MicPlugin._();
  static final MicPlugin instance = MicPlugin._();
  final MethodChannel _methodChannel = MethodChannel('com.mg.mic/methods');
  final EventChannel _eventChannel = EventChannel('com.mg.mic/stream');

  final StreamController<List<int>> _audioStream = StreamController<List<int>>();

  final ValueNotifier<MicState> _state = ValueNotifier<MicState>(MicState.stopped);
  ValueNotifier<MicState> get state => _state;
  Stream<List<int>> get stream => _audioStream.stream.asBroadcastStream();

  bool _isInitialized = false;

  void init() {
    _eventChannel.receiveBroadcastStream().listen(
      (data) {
        _audioStream.add(List<int>.from(data));
      },
      onError: (error) {
        _state.value = MicState.errored;
        debugPrint('MicPlugin Error: $error');
      },
    );
  }

  Future<void> start() async {
    if (!_isInitialized) {
      init();
      _isInitialized = true;
    }

    try {
      final String? result = await _methodChannel.invokeMethod('startListening');
      if (result == 'Recording Started' || result == 'Already Recording') {
        _state.value = MicState.started;
      } else {
        _state.value = MicState.errored;
      }
    } catch (e) {
      _state.value = MicState.errored;
      debugPrint('Error starting microphone: $e');
    }
  }

  Future<void> stop() async {
    try {
      final String? result = await _methodChannel.invokeMethod('stopListening');
      if (result == 'Recording Stopped' || result == 'Not recording') {
        _state.value = MicState.stopped;
      } else {
        _state.value = MicState.errored;
      }
    } catch (e) {
      _state.value = MicState.errored;
      debugPrint('Error stopping microphone: $e');
    }
  }

  Future<void> save({required List<int> audioData, required String path}) async {
    try {
      await FileService.saveAudioWav(audioData, path);
    } catch (e) {
      debugPrint('Error saving audio: $e');
    }
  }

  Future<void> dispose() async {
    await _audioStream.close();
    _state.dispose();
  }
}
