//
//  Transcribe.swift
//  Runner
//
//  Created by mn on 06.05.23.
//

import Foundation
import Flutter

func transcribe(audioFilePath: String, modelPath: String, result: @escaping FlutterResult) async -> Void {
    var floats: [Float]?
    do {
        let url = URL(fileURLWithPath: audioFilePath)
        floats = try decodeWaveFile(url)
        
        guard let whisperContext: WhisperContext? = try WhisperContext.createContext(path: modelPath) else {
            result("context not created")
        }
        
        if (floats != nil) {
            await whisperContext?.fullTranscribe(samples: floats!)
            let text = await whisperContext?.getTranscription()
            result(text)
        }
    } catch {
        floats = nil
    }
    
    result("Transcribe " + audioFilePath + " " + modelPath + " " + "\(floats?[...5])")
}


func detectLanguage(audioFilePath: String, modelPath: String, result: @escaping FlutterResult) async -> Void {
    var floats: [Float]?
    do {
        let url = URL(fileURLWithPath: audioFilePath)
        floats = try decodeWaveFile(url)

        guard let whisperContext: WhisperContext? = try WhisperContext.createContext(path: modelPath) else {
            result("context not created")
        }

        if (floats != nil) {
            let language = await whisperContext?.detectLanguage(samples: floats!)
            result(language)
        }
    } catch {
        floats = nil
    }

    result("Transcribe " + audioFilePath + " " + modelPath + " " + "\(floats?[...5])")
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
