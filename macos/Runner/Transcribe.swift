//
//  Transcribe.swift
//  Runner
//
//  Created by mn on 06.05.23.
//

import Foundation

func transcribe( audioFilePath: String, modelPath: String) -> String? {
    let floats: [Float]?
    do {
        let url = URL(fileURLWithPath: audioFilePath)
        floats = try decodeWaveFile(url)
    } catch {
        floats = nil
    }
    
    
    return "Transcribe " + audioFilePath + " " + modelPath + " " + "\(floats?[...5])"
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
