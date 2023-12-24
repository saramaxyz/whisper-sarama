import Foundation
import AVFoundation

actor Recorder {
    private var recorder: AVAudioRecorder?
    private var audioEngine = AVAudioEngine()
    private let CHUNK_TO_READ = 5
    private let CHUNK_SIZE = 640
    private let INPUT_SIZE = 3200

    enum RecorderError: Error {
        case couldNotStartRecording
    }
    func stopStreaming() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    func startStreaming(whisperContext: WhisperContext, delegate: WhisperState) throws {
        let inputNode = audioEngine.inputNode
        let inputNodeOutputFormat = inputNode.outputFormat(forBus: 0)
        let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(16000), channels: 1, interleaved: false)
        let formatConverter =  AVAudioConverter(from:inputNodeOutputFormat, to: targetFormat!)
        var pcmBufferToBeProcessed = [Float32]()
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNodeOutputFormat) { [unowned self] (buffer, _) in
              let pcmBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat!, frameCapacity: AVAudioFrameCount(targetFormat!.sampleRate) / 10)
              var error: NSError? = nil
              
              let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                outStatus.pointee = AVAudioConverterInputStatus.haveData
                return buffer
              }
              formatConverter!.convert(to: pcmBuffer!, error: &error, withInputFrom: inputBlock)
              
              let floatArray = Array(UnsafeBufferPointer(start: pcmBuffer!.floatChannelData![0], count:Int(pcmBuffer!.frameLength)))
              pcmBufferToBeProcessed += floatArray
              
              if pcmBufferToBeProcessed.count >= 24000 {
                let samples = Array(pcmBufferToBeProcessed)
                pcmBufferToBeProcessed = [Float32]()
                whisperContext.streamTranscribe(samples: samples, n_samples: Int32(samples.count))
                Task {
                    await delegate.messageLog = whisperContext.transcript
                }
//                print("\(whisperContext.stream_context.transcript)")
//                serialQueue.async {
//                  var result = self.module.recognize(samples)
//                  if result!.count > 0 {
//                    result = result!.replacingOccurrences(of: "▁", with: "")
//                    DispatchQueue.main.async {
//                      self.tvResult.text = self.tvResult.text + " " + result!
//                    }
//                  }
//                }
              }
        }
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    func startRecording(toOutputFile url: URL, delegate: AVAudioRecorderDelegate?) throws {
        let recordSettings: [String : Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
#if !os(macOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
#endif
        let recorder = try AVAudioRecorder(url: url, settings: recordSettings)
        recorder.delegate = delegate
        if recorder.record() == false {
            print("Could not start recording")
            throw RecorderError.couldNotStartRecording
        }
        self.recorder = recorder
    }
    
    func stopRecording() {
        recorder?.stop()
        recorder = nil
    }
}
