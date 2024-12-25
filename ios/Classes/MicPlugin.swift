
import Flutter
import UIKit
import AVFoundation

public class MicPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    private var audioEngine: AVAudioEngine?
    private var audioFormat: AVAudioFormat?
    private var isRecording = false
    private var eventSink: FlutterEventSink?
    private let sampleRate: Double = 44100.0

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "com.mg.mic/methods", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "com.mg.mic/stream", binaryMessenger: registrar.messenger())
        let instance = SwiftMicPlugin()
        
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startListening":
            startListening(result: result)
        case "stopListening":
            stopListening(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func startListening(result: @escaping FlutterResult) {
        guard !isRecording else {
            result("Already Recording")
            return
        }
        
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else {
            result(FlutterError(code: "INIT_FAILED", message: "Failed to initialize AudioEngine", details: nil))
            return
        }
        
        let inputNode = audioEngine.inputNode
        audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: true)
        
        guard let audioFormat = audioFormat else {
            result(FlutterError(code: "FORMAT_ERROR", message: "Failed to create audio format", details: nil))
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: audioFormat) { (buffer, time) in
            guard let eventSink = self.eventSink else { return }
            
            let audioData = buffer.int16ChannelData?.pointee
            let data = Data(buffer: UnsafeBufferPointer(start: audioData, count: Int(buffer.frameLength)))
            
            eventSink(data)
        }
        
        do {
            try audioEngine.start()
            isRecording = true
            result("Recording Started")
        } catch {
            result(FlutterError(code: "START_FAILED", message: "Failed to start recording: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func stopListening(result: @escaping FlutterResult) {
        guard isRecording else {
            result("Not recording")
            return
        }
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false
        
        result("Recording Stopped")
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
