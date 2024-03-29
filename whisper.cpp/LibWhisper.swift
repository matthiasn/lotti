import Foundation

enum WhisperError: Error {
    case couldNotInitializeContext
}

// Meet Whisper C++ constraint: Don't access from more than one thread at a time.
actor WhisperContext {
    private var context: OpaquePointer
    
    init(context: OpaquePointer) {
        self.context = context
    }
    
    deinit {
        whisper_free(context)
    }
    
    func fullTranscribe(language: String,samples: [Float]) {
        // Leave 2 processors free (i.e. the high-efficiency cores).
        let maxThreads = max(1, min(8, cpuCount() - 2))
        print("Selecting \(maxThreads) threads")
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        language.withCString { lang in
            // Adapted from whisper.objc
            params.print_realtime = true
            params.print_progress = false
            params.print_timestamps = true
            params.print_special = false
            params.translate = false
            params.language = lang
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
    
    func detectLanguage(samples: [Float]) -> String {
        // Leave 2 processors free (i.e. the high-efficiency cores).
        let maxThreads = max(1, min(8, cpuCount() - 2))
        print("Selecting \(maxThreads) threads")
        var language = "not detected"
        
        samples.withUnsafeBufferPointer { samples in
            if (whisper_pcm_to_mel(context, samples.baseAddress, Int32(samples.count), Int32(maxThreads)) != 0) {
                print("Failed to detect language")
            } else {
                let languageId = whisper_lang_auto_detect(context, 0, Int32(maxThreads), nil)
                language = String(cString: whisper_lang_str(Int32(languageId)))
                print("Detected language: " + language)
            }
        }
        return language
    }
    
    func getTranscription() -> String {
        var transcription = ""
        for i in 0..<whisper_full_n_segments(context) {
            transcription += String.init(cString: whisper_full_get_segment_text(context, i))
        }
        return transcription
    }
    
    static func createContext(path: String) throws -> WhisperContext {
        let context = whisper_init_from_file(path)
        if let context {
            return WhisperContext(context: context)
        } else {
            print("Couldn't load model at \(path)")
            throw WhisperError.couldNotInitializeContext
        }
    }
}

fileprivate func cpuCount() -> Int {
    ProcessInfo.processInfo.processorCount
}


func transcribe(args: [String: Any]) async -> String {
    let audioFilePath = args["audioFilePath"] as! String
    let modelPath = args["modelPath"] as! String
    let language = args["language"] as! String
    
    var floats: [Float]?
    do {
        let url = URL(fileURLWithPath: audioFilePath)
        floats = try decodeWaveFile(url)
        
        guard let whisperContext: WhisperContext? = try WhisperContext.createContext(path: modelPath) else {
            return "context not created"
        }
        
        if (floats != nil) {
            await whisperContext?.fullTranscribe(language: language, samples: floats!)
            let text = await whisperContext?.getTranscription()
            return text ?? ""
        }
    } catch {
        floats = nil
    }
    
    return "Transcribe " + audioFilePath + " " + modelPath
}

func detectLanguage(args: [String: Any]) async -> String {
    let audioFilePath = args["audioFilePath"] as! String
    let modelPath = args["modelPath"] as! String
    
    var floats: [Float]?
    do {
        let url = URL(fileURLWithPath: audioFilePath)
        floats = try decodeWaveFile(url)
        
        guard let whisperContext: WhisperContext? = try WhisperContext.createContext(path: modelPath) else {
            return "context not created"
        }
        
        if (floats != nil) {
            let language = await whisperContext?.detectLanguage(samples: floats!)
            return language ?? ""
        }
    } catch {
        floats = nil
    }
    
    return "Transcribe " + audioFilePath + " " + modelPath
}

func decodeWaveFile(_ url: URL) throws -> [Float] {
    let data = try Data(contentsOf: url)
    let floats = stride(from: 44, to: data.count - 2, by: 2).map {
        return data[$0..<$0 + 2].withUnsafeBytes {
            let short = Int16(littleEndian: $0.load(as: Int16.self))
            return max(-1.0, min(Float(short) / 32767.0, 1.0))
        }
    }
    return floats
}
