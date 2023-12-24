import Foundation
import whisper

enum WhisperError: Error {
    case couldNotInitializeContext
}

// Meet Whisper C++ constraint: Don't access from more than one thread at a time.
actor WhisperContext {
    private var context: OpaquePointer
    private var stream_context: OpaquePointer
    var transcript: String = ""

    init(context: OpaquePointer, stream_context: OpaquePointer) {
        self.context = context
        self.stream_context = stream_context
    }
    
    deinit {
        whisper_free(context)
    }
    
    func streamTranscribe(samples: [Float], n_samples: Int32) {
        let maxThreads = max(1, min(8, cpuCount()-2))
        print("Selecting \(maxThreads) threads")
        var whisper_params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        var stream_params = stream_full_default_params()
        stream_params.step_ms = 1500

        "en".withCString { en in
            // Adapted from whisper.objc
            whisper_params.print_realtime = false
            whisper_params.print_progress = false
            whisper_params.print_timestamps = false
            whisper_params.print_special = false
            whisper_params.translate = false
            whisper_params.language = en
            whisper_params.n_threads = Int32(maxThreads)
            whisper_params.offset_ms = 0
            whisper_params.no_context = true
            whisper_params.single_segment = true
            whisper_params.max_tokens = 0
            whisper_params.audio_ctx = 0
            whisper_params.prompt_tokens = nil
            whisper_params.prompt_n_tokens = 0
            
            whisper_reset_timings(context)
            print("About to run whisper_full")
            
            samples.withUnsafeBufferPointer { samples in
                if let text = stream_get_text(context, stream_context, stream_params, whisper_params, samples.baseAddress, n_samples) {
                    print(String.init(cString:text))
                    transcript = String.init(cString: text)
                }
            }
        }
    }
    
    func fullTranscribe(samples: [Float]) {
        // Leave 2 processors free (i.e. the high-efficiency cores).
        let maxThreads = max(1, min(8, cpuCount() - 2))
        print("Selecting \(maxThreads) threads")
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        "en".withCString { en in
            // Adapted from whisper.objc
            params.print_realtime = true
            params.print_progress = false
            params.print_timestamps = true
            params.print_special = false
            params.translate = false
            params.language = en
            params.n_threads = Int32(maxThreads)
            params.offset_ms = 0
            params.no_context = true
            params.single_segment = false
            
            whisper_reset_timings(context)
            print("About to run whisper_full")
            samples.withUnsafeBufferPointer { samples in
                if (whisper_full(context, params, samples.baseAddress, Int32(samples.count)) != 0) {
                    print("Failed to run the model")
                } else {
                    whisper_print_timings(context)
                }
            }
        }
    }
    
    func getTranscription() -> String {
        var transcription = ""
        for i in 0..<whisper_full_n_segments(context) {
            transcription += String.init(cString: whisper_full_get_segment_text(context, i))
        }
        return transcription
    }
    
    static func createContext(path: String) throws -> WhisperContext {
        var params = whisper_context_default_params()
#if targetEnvironment(simulator)
        params.use_gpu = false
        print("Running on the simulator, using CPU")
#endif
        let context = whisper_init_from_file_with_params(path, params)
        let stream_context = whisper_init_stream()
        if let context, let stream_context {
            return WhisperContext(context: context, stream_context: stream_context)
        } else {
            print("Couldn't load model at \(path)")
            throw WhisperError.couldNotInitializeContext
        }
    }
}

fileprivate func cpuCount() -> Int {
    ProcessInfo.processInfo.processorCount
}
