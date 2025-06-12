//
//  SpeechRecognizerManager.swift
//  Notel
//
//  Created by Alara yüksel on 3.06.2025.
//
import Foundation
import Speech
import AVFoundation

class SpeechRecognizerManager: ObservableObject {
    @Published var transcriptions: [TranscriptionSegment] = []
    @Published var isTranscribing: Bool = false
    @Published var errorMessage: String?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "tr-TR"))
    // Her segment için ayrı task tutmak yerine array kullanın
    private var recognitionTasks: [SFSpeechRecognitionTask] = []
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    completion(true)
                case .denied, .restricted, .notDetermined:
                    self.errorMessage = "Konuşma tanıma yetkilendirilmedi."
                    completion(false)
                @unknown default:
                    self.errorMessage = "Bilinmeyen yetkilendirme durumu."
                    completion(false)
                }
            }
        }
    }
    
    func transcribeAudio(from data: Data) {
        guard speechRecognizer?.isAvailable ?? false else {
            errorMessage = "Konuşma tanıma servisi şu anda kullanılamıyor."
            return
        }
        
        isTranscribing = true
        errorMessage = nil
        transcriptions = []
        
        // Önceki task'ları temizle
        cancelAllTasks()
        
        requestAuthorization { [weak self] authorized in
            guard let self = self, authorized else {
                self?.isTranscribing = false
                return
            }
            
            let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString + ".m4a")
            
            do {
                // Tek seferde yazma işlemi
                try data.write(to: tempFileURL)
                
                // Format kontrolü
                let asset = AVURLAsset(url: tempFileURL)
                guard asset.isReadable else {
                    self.errorMessage = "Ses dosyası okunabilir değil veya desteklenmeyen format."
                    self.isTranscribing = false
                    try? FileManager.default.removeItem(at: tempFileURL)
                    return
                }
                
                print("Geçici dosya oluşturuldu: \(tempFileURL.lastPathComponent)")
                print("DEBUG: Geçici dosya boyutu: \(try FileManager.default.attributesOfItem(atPath: tempFileURL.path)[.size] as? Int ?? 0) bayt")
                
                self.transcribeWholeAudioFile(url: tempFileURL)
                
            } catch {
                self.errorMessage = "Ses verisi geçici dosyaya yazılamadı: \(error.localizedDescription)"
                self.isTranscribing = false
                print("Hata: Ses verisi geçici dosyaya yazılamadı: \(error.localizedDescription)")
            }
        }
    }
    
    private func transcribeWholeAudioFile(url: URL) {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        
        guard duration > 0 else {
            self.errorMessage = "Ses dosyası geçerli bir süreye sahip değil."
            self.isTranscribing = false
            try? FileManager.default.removeItem(at: url)
            return
        }
        
        // Tek recognition request oluştur
        let recognitionRequest = SFSpeechURLRecognitionRequest(url: url)
        recognitionRequest.shouldReportPartialResults = true
        
        // Tek recognition task oluştur
        let recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            OperationQueue.main.addOperation {
                guard let self = self else { return }
                
                if let result = result {
                    if result.isFinal {
                        // Tüm metni tek segment olarak ekle
                        let transcription = TranscriptionSegment(
                            startTime: 0,
                            endTime: duration,
                            text: result.bestTranscription.formattedString
                        )
                        self.transcriptions = [transcription]
                        self.isTranscribing = false
                        self.recognitionTasks.removeAll()
                        
                        // Geçici dosyayı sil
                        try? FileManager.default.removeItem(at: url)
                    } else {
                        // Kısmi sonuçları göster (isteğe bağlı)
                        let transcription = TranscriptionSegment(
                            startTime: 0,
                            endTime: duration,
                            text: result.bestTranscription.formattedString + " (devam ediyor...)"
                        )
                        self.transcriptions = [transcription]
                    }
                } else if let error = error {
                    self.errorMessage = "Konuşma tanıma hatası: \(error.localizedDescription)"
                    print("Recognition error: \(error.localizedDescription)")
                    self.isTranscribing = false
                    self.recognitionTasks.removeAll()
                    
                    // Geçici dosyayı sil
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
        
        if let task = recognitionTask {
            recognitionTasks.append(task)
        } else {
            errorMessage = "Konuşma tanıma görevi oluşturulamadı."
            isTranscribing = false
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    func cancelTranscription() {
        cancelAllTasks()
        isTranscribing = false
    }
    
    private func cancelAllTasks() {
        recognitionTasks.forEach { $0.cancel() }
        recognitionTasks.removeAll()
    }
}

// TranscriptionSegment struct'ı (eğer yoksa)
struct TranscriptionSegment: Identifiable {
    let id = UUID()
    let startTime: Double
    let endTime: Double
    let text: String
    
    var timeRangeString: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        
        let start = formatter.string(from: startTime) ?? "00:00"
        let end = formatter.string(from: endTime) ?? "00:00"
        return "\(start) - \(end)"
    }
}
import SwiftUI
// MARK: - RecordingDetailView (Data'dan transkript etmeyi başlatmak için)
struct RecordingDetailView: View {
    let recording: Recording // Varsayılan olarak fileData'sı var
    @StateObject private var speechRecognizerManager = SpeechRecognizerManager()
    
    var body: some View {
        VStack {
            Text("Ses Kaydı Detayları")
                .font(.largeTitle)
                .padding()
            
            if let audioData = recording.fileData { // fileData'yı kullan
                Button(action: {
                    if speechRecognizerManager.isTranscribing {
                        speechRecognizerManager.cancelTranscription()
                    } else {
                        speechRecognizerManager.transcribeAudio(from: audioData) // Data'yı direkt iletiyoruz!
                    }
                }) {
                    Label(speechRecognizerManager.isTranscribing ? "İptal Et" : "Transkript Et", systemImage: speechRecognizerManager.isTranscribing ? "stop.circle.fill" : "mic.fill")
                        .font(.headline)
                }
                .padding()
                .background(speechRecognizerManager.isTranscribing ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            } else {
                Text("Ses verisi bulunamadı.")
                    .foregroundColor(.red)
            }
            
            if speechRecognizerManager.isTranscribing {
                ProgressView("Transkript Ediliyor...")
                    .padding()
            }
            
            if let errorMessage = speechRecognizerManager.errorMessage {
                Text("Hata: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            }
            
            if speechRecognizerManager.transcriptions.isEmpty && !speechRecognizerManager.isTranscribing {
                Text("Henüz bir transkripsiyon yok.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List(speechRecognizerManager.transcriptions) { segment in
                    VStack(alignment: .leading) {
                        Text(segment.timeRangeString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(segment.text)
                            .font(.body)
                    }
                }
            }
        }
        .onAppear {
        }
    }
}
