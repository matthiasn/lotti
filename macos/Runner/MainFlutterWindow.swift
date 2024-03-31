import Cocoa
import FlutterMacOS
import WhisperKit
import llmfarm_core
import IOKit

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController.init()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)
        
        let transcriptionChannel = FlutterMethodChannel(
            name: "lotti/transcribe",
            binaryMessenger: flutterViewController.engine.binaryMessenger)

        transcriptionChannel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "transcribe":
                guard let args = call.arguments as? [String: Any] else { return }
                let audioFilePath = args["audioFilePath"] as! String
                
                Task {
                    let model = "large-v3"
                    let pipe = try? await WhisperKit(model: model, verbose: true, prewarm: true)
                    
                    let transcription = try? await pipe!.transcribe(
                        audioPath: audioFilePath,
                        decodeOptions: DecodingOptions(
                            task: DecodingTask.transcribe,
                            usePrefillPrompt: false
                        ))
                    
                    let text = transcription?.text
                    let language = transcription?.language

                    let data = [language, model, text]
                    result(data)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }


        let llmChannel = FlutterMethodChannel(
            name: "lotti/llm",
            binaryMessenger: flutterViewController.engine.binaryMessenger)
        
        llmChannel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "prompt":
                guard let args = call.arguments as? [String: Any] else { return }
                let input_text = args["inputText"] as! String
                let model_path = args["modelPath"] as! String

                Task {
                    let maxOutputLength = 256
                    var total_output = 0
                    
                    let ai = AI(_modelPath: model_path,_chatName: "chat")
                    var params:ModelAndContextParams = .default
                    params.promptFormat = .Custom
                    params.custom_prompt_format = """
                    SYSTEM: You are a helpful, respectful and honest assistant.
                    USER: {prompt}
                    ASSISTANT:
                    """

                    params.use_metal = true

                    _ = try? ai.loadModel_sync(ModelInference.LLama_gguf,contextParams: params)
                    
                    func llmCallback(_ str: String, _ time: Double) -> Bool {
                        print("\(str)",terminator: "")
                        total_output += str.count
                        if(total_output>maxOutputLength){
                            return true
                        }
                        return false
                    }

                    let output = try? ai.model.predict(input_text, llmCallback)
                    result(output)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        
        RegisterGeneratedPlugins(registry: flutterViewController)
        
        super.awakeFromNib()
    }
}
