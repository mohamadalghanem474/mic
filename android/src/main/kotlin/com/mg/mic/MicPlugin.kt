package com.mg.mic;

import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** MicPlugin */
class MicPlugin: FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var methodChannel: MethodChannel;
    private lateinit var eventChannel: EventChannel;

    private var audioRecord: AudioRecord? = null;
    private var isRecording = false;
    private val sampleRate = 44100;
    private val channelConfig = AudioFormat.CHANNEL_IN_MONO;
    private val encoding = AudioFormat.ENCODING_PCM_16BIT;
    private var bufferSize: Int = 0;

    private var eventSink: EventChannel.EventSink? = null;

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.mg.mic/methods");
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "com.mg.mic/stream");

        methodChannel.setMethodCallHandler(this);
        eventChannel.setStreamHandler(this);

        bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, encoding);
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null);
        eventChannel.setStreamHandler(null);
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startListening" -> startListening(result);
            "stopListening" -> stopListening(result);
            else -> result.notImplemented();
        }
    }

    private fun startListening(result: Result) {
        if (isRecording) {
            result.success("Already Recording");
            return;
        }

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            channelConfig,
            encoding,
            bufferSize
        );

        if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
            result.error("UNAVAILABLE", "AudioRecord initialization failed", null);
            return;
        }

        isRecording = true;
        audioRecord?.startRecording();

        val mainHandler = Handler(Looper.getMainLooper());

        Thread {
            val audioData = ByteArray(bufferSize);
            while (isRecording) {
                try {
                    if (audioRecord?.state == AudioRecord.STATE_INITIALIZED) {
                        val bytesRead = audioRecord?.read(audioData, 0, bufferSize) ?: -1;
                        if (bytesRead > 0) {
                            mainHandler.post {
                                eventSink?.success(audioData.copyOfRange(0, bytesRead));
                            }
                        } else if (bytesRead < 0) {
                            throw Exception("Error reading audio data, bytesRead: $bytesRead");
                        }
                    } else {
                        throw IllegalStateException("AudioRecord is not in a valid state");
                    }
                } catch (e: Exception) {
                    Log.e("MicPlugin", "Error while reading audio data: ${e.message}");
                    mainHandler.post {
                        eventSink?.error("READ_FAILED", "Failed to read audio data", e.localizedMessage);
                    }
                    stopListening(object : Result {
                        override fun success(result: Any?) {}
                        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
                        override fun notImplemented() {}
                    });
                    break;
                }
            }
        }.start();

        result.success("Recording Started");
    }

    private fun stopListening(result: Result) {
        if (!isRecording) {
            result.success("Not recording");
            return;
        }

        try {
            isRecording = false;
            audioRecord?.stop();
            audioRecord?.release();
            audioRecord = null;
            result.success("Recording Stopped");
        } catch (e: Exception) {
            result.error("STOP_FAILED", "Failed to stop recording: ${e.message}", null);
            Log.e("MicPlugin", "Error stopping recording: ${e.message}");
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events;
    }

    override fun onCancel(arguments: Any?) {
        stopListening(object : Result {
            override fun success(result: Any?) {}
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
            override fun notImplemented() {}
        });
    }
}
