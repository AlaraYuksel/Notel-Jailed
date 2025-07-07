
import SwiftUI
import PencilKit
import CoreData
import PhotosUI
import AVFoundation // << Bunu ekleyin
import PDFKit
import UniformTypeIdentifiers

class ToolSettings: ObservableObject {
    @Published var lastPenTool = PKInkingTool(.pen, color: .black, width: 5)
}
struct NotePageView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var page: Page?
    let note: Note // Mevcut gösterilen sayfa (Binding)
    // Note: pages fetch request will automatically update when context changes
    @FetchRequest var pages: FetchedResults<Page> // Nota ait tüm sayfalar
    
    @FetchRequest var recordings: FetchedResults<Recording> //Nota ait ses kayıtları
    
    @State private var kontrol: Bool = false
    
    //MARK: Zoom State Değişkenleri
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
        
    private let frameSize: CGFloat = 500
    
    // MARK: - Drawing State
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker() // Still needed for PKCanvasView interaction, even if not visible
    @State private var currentTool: PKTool = PKInkingTool(.pen, color: .black, width: 5)
    @State private var loadError: Error?
    @State private var showErrorAlert = false
    @State private var showPalette = false
    @State private var penSelectedOnce = false
    @StateObject private var toolSettings = ToolSettings()
    // MARK: - Attachment State
    @State private var showingImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    // MARK: - Audio Recording State // Ses Kaydı State Değişkenleri
    @State private var audioRecorder: AVAudioRecorder?
    @State private var isRecording = false
    @State private var recordingURL: URL? // Geçici kayıt dosyasının URL'si

    // MARK: - Audio Player State
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentPlayingRecordingID: UUID?
    @State private var currentRecordingIndex: Int = 0
    @State private var playbackProgress: Double = 0.0
    @State private var totalDuration: Double = 0.0
    @State private var currentTime: Double = 0.0
    @State private var playbackTimer: Timer?
    @State private var isDragging: Bool = false
    // MARK: New State for Transcription Panel
        @State private var showTranscriptionPanel: Bool = false
    // Computed Properties
    private var allRecordings: [Recording] {
        recordings.compactMap { $0 }
    }
    
    private var currentRecording: Recording? {
        guard currentRecordingIndex < allRecordings.count else { return nil }
        return allRecordings[currentRecordingIndex]
    }

    
    @State private var undoTapped = false
    @State private var redoTapped = false
    
    @State private var undoTapped1 = false
    @State private var redoTapped1 = false
    
    //PDF EKLEME İÇİN
    @State private var showPDFImporter = false
    
    
    @ViewBuilder
    private var pdfContent: some View {
        if let actualPage = page {
            if let pdfData = actualPage.pdfFile {
                if let uiImage = UIImage(data: pdfData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 700, height: 900)
                        .clipped()
                        .scaleEffect(x: 1, y: -1) // Dikey olarak ters çevirdim
                        .allowsHitTesting(false)
                } else {
                    Text("")
                }
            } else {
                Text("")
            }
        } else {
            Text("Sayfa bulunamadı")
        }
    }
    
    @ViewBuilder
    private var attemptToPage: some View{
        // Sağ alt köşede sayfa belirteci
            if !pages.isEmpty {
                PageIndicatorView(
                    page: $page,
                    pages: pages,
                    note: note,
                    canvasView: canvasView // PKCanvasView örneğini geçiyoruz
                )
                .position(x: UIScreen.main.bounds.width - 40, y: UIScreen.main.bounds.height - 250)
            }
    }
    //Kod basitleştirme işlemi gerçekleştirdim -- Tekrar geri alınabilir :(
    @ViewBuilder
    private var attachmentxcanvasContent: some View{
        
        CanvasView(
            canvasView: $canvasView,
            toolPicker: PKToolPicker(),
            currentTool: $currentTool,
            undoTapped: $undoTapped,
            redoTapped: $redoTapped
        ) { drawing in
            // onEndStroke: kaydetme/işleme kodların
            // MARK: - Critical Change 1: Record Drawing Action (Corrected)
            recordAction(.drawing)
        }
        // Apply a fixed frame and border for visualization, adjust as needed
        .frame(width: 700, height: 900)
        .background(.clear) // Arka planı şeffaf yapar
        .border(Color.gray, width: 0)
        .overlay(
            // Layer 3: Attachments (Images, etc.)
            Group {
                if let currentPage = page, let attachments = currentPage.attachments as? Set<Attachment> {
                    // Use Array(attachments) to iterate over a stable collection
                    ForEach(Array(attachments), id: \.self) { attachment in
                        AttachmentView(
                            attachment: attachment,
                            // Pass the closure to record attachment move actions
                            onMoveEnded: { attachmentID, oldX, oldY, newX, newY in
                                recordAction(.moveAttachment(attachmentID: attachmentID, oldX: oldX, oldY: oldY, newX: newX, newY: newY))
                            }
                        )
                        // Position the attachment using its top-left coordinates from Core Data
                        .position(x: CGFloat(attachment.positionX) + CGFloat(attachment.width) / 2,
                                  y: CGFloat(attachment.positionY) + CGFloat(attachment.height) / 2)
                    }
                }
                CanvasView(
                    canvasView: $canvasView,
                    toolPicker: PKToolPicker(),
                    currentTool: $currentTool,
                    undoTapped: $undoTapped1,
                    redoTapped: $redoTapped1
                ) { drawing in
                    // onEndStroke: kaydetme/işleme kodların
                    // MARK: - Critical Change 1: Record Drawing Action (Corrected)
                    recordAction(.drawing)
                }

                // Apply a fixed frame and border for visualization, adjust as needed
                
                .frame(width: 700, height: 900)
                .background(.clear) // Arka planı şeffaf yapar
                .border(Color.gray, width: 0)
                .disabled(kontrol)
            }
            .padding() // Adjust padding if necessary
        )
        
    }
    @ViewBuilder
    private var toolbar: some View{
        DraggableToolbar(
            toolSettings: toolSettings,
            showPDFImporter: $showPDFImporter,
            onPDFImport: handlePDFImport,
            currentTool: $currentTool,
            showPalette: $showPalette,
            onImagePicker: { showingImagePicker = true },
            onStartRecording: startRecording,
            onStopRecording: stopRecording,
            onPlayRecording: {
                if !recordings.isEmpty {
                    stopRecording() // Ensure recording stops before playing
                    playRecording(recordings.first!) // plays the first recording
                }
            },
            onStopPlayback: stopPlayback,
            onSelectPen: selectPen,
            onSelectEraser: selectEraser,
            onSelectHighlighter: selectHighlighter,
            onSelectBrush: selectBrush,
            onDeleteAll: {
                if let currentPage = page {
                    deleteAllAttachments(for: currentPage, in: viewContext)
                }
            },
            onAddPage: addNewPage,
            onUndo: undo,
            onRedo: redo,
            onOpenSheet: {showingRecordingsSheet.toggle()},
            onClickEdit: change,
            onSelectLasso: selectLassoTool,
            isRecording: isRecording,
            isPlaying: isPlaying,
            canUndo: canUndo,
            canRedo: canRedo,
            hasRecordings: !recordings.isEmpty, // Check if recordings array is not empty
            selectedTool: "pen"
        )
        
    }
    private func change() {
        kontrol.toggle()
    }
    // MARK: - Undo/Redo State
    // Define the types of actions we can undo/redo
    enum ActionType {
        // Stores the drawing data *after* a stroke sequence ends
        case drawing
        // An attachment was added. Store ID to find/delete on undo.
        case addAttachment(attachmentID: UUID, data: Data, x: Float, y: Float, width: Float, height: Float)
        // An attachment was deleted. Store all details to recreate on undo.
        case deleteAttachment(attachmentID: UUID, data: Data, x: Float, y: Float, width: Float, height: Float)
        // An attachment was moved. Store ID and old/new positions.
        case moveAttachment(attachmentID: UUID, oldX: Float, oldY: Float, newX: Float, newY: Float)
        // A recording was added. Store ID to find/delete on undo. // << Yeni Aksiyon Tipleri
        case addRecording(recordingID: UUID)
        // A recording was deleted. Store all details to recreate on undo.
        case deleteRecording(recordingID: UUID, data: Data, duration: Double, timestamp: Date) // Data needed for recreate

    }
    
    @State private var actionHistory: [ActionType] = []
    @State private var actionHistoryIndex: Int = -1 // Index of the last performed action
    private let maxActionHistorySize: Int = 30 // Limit the history size
    
    // MARK: - Initializer (Mevcut - FetchRequest'i güncelleyeceğiz)
        init(page: Binding<Page?>, note: Note) {
            self._page = page
            self.note = note // Note'u burada saklıyoruz
            
            _pages = FetchRequest(
                entity: Page.entity(),
                sortDescriptors: [NSSortDescriptor(keyPath: \Page.pageIndex, ascending: true)],
                predicate: NSPredicate(format: "note == %@", note)
            )

            // Mevcut sayfaya ait kayıtları getirecek FetchRequest'i burada tanımlıyoruz.
            // Başlangıçta nil olabilir, page?.id'ye bağlı olarak predicate ayarlanacak.
            
            _recordings = FetchRequest(
                        entity: Recording.entity(),
                        sortDescriptors: [NSSortDescriptor(keyPath: \Recording.createdAt, ascending: true)], // Kayıtları zamana göre sırala
                        predicate: NSPredicate(format: "note == %@", note) // *** Burası Güncellendi: Kayıtları ilgili Nota göre filtrele ***
                    )
        }

    // MARK: - Computed Properties for Button State
    private var canUndo: Bool {
        actionHistoryIndex >= 0
    }
    @State private var showingRecordingsSheet = false
    private var canRedo: Bool {
        actionHistoryIndex < actionHistory.count - 1
    }
    
    //MARK: SCALING CANVAS
    @State private var canvasScale: CGFloat = 1.0
    
    
    @State private var isPlayerVisible = false
    // MARK: - View Body
    var body: some View {
        VStack(spacing: 0) {
                    GeometryReader { geometry in
                        ZStack(alignment: .center) { // Align to bottom trailing for the transcription panel
                            // Existing content layers for PDF and Canvas
                            VStack(spacing: 0) {
                                ZStack(alignment: .center) {
                                    pdfContent
                                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
                                        .scaleEffect(scale)
                                        .gesture(
                                            MagnificationGesture()
                                                .onChanged { value in
                                                    let delta = value / lastScale
                                                    lastScale = value
                                                    scale *= delta
                                                }
                                                .onEnded { _ in
                                                    lastScale = 1.0
                                                    
                                                    // Scale limitlerini ayarla
                                                    if scale < 0.5 {
                                                        withAnimation(.spring()) {
                                                            scale = 0.5
                                                        }
                                                    } else if scale > 3.0 {
                                                        withAnimation(.spring()) {
                                                            scale = 3.0
                                                        }
                                                    }
                                                }
                                        )
                                        .onTapGesture(count: 2) {
                                            // Double tap ile reset
                                            withAnimation(.spring()) {
                                                scale = 1.0
                                            }
                                        }
                                    
                                    attachmentxcanvasContent
                                        .frame(width: min(geometry.size.width - 40, 700), height: min(geometry.size.height - 140, 900))
                                        .clipped()
                                        .scaleEffect(scale)
                                        .gesture(
                                            MagnificationGesture()
                                                .onChanged { value in
                                                    let delta = value / lastScale
                                                    lastScale = value
                                                    scale *= delta
                                                }
                                                .onEnded { _ in
                                                    lastScale = 1.0
                                                    
                                                    // Scale limitlerini ayarla
                                                    if scale < 0.5 {
                                                        withAnimation(.spring()) {
                                                            scale = 0.5
                                                        }
                                                    } else if scale > 3.0 {
                                                        withAnimation(.spring()) {
                                                            scale = 3.0
                                                        }
                                                    }
                                                }
                                        )
                                        .onTapGesture(count: 2) {
                                            // Double tap ile reset
                                            withAnimation(.spring()) {
                                                scale = 1.0
                                            }
                                        }
                                }}

                            // Audio Player Bar - Sabit alt konumda
                            VStack {
                                Spacer()
                                AudioPlayerBar(
                                    isPlaying: $isPlaying,
                                    progress: $playbackProgress,
                                    currentTime: $currentTime,
                                    totalDuration: $totalDuration,
                                    isDragging: $isDragging,
                                    currentRecording: currentRecording,
                                    onPlayPause: togglePlayback,
                                    onPrevious: previousRecording,
                                    onNext: nextRecording,
                                    onSeek: seekToTime,
                                    onSkipBackward: { skipBackward(seconds: 10) },
                                    onSkipForward: { skipForward(seconds: 10) },
                                    isPlayerVisible: $isPlayerVisible
                                )
                                .frame(height: 120)
                                .background(Color(.systemBackground))
                                .cornerRadius(20)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                            
                        }
                    }
                    .sheet(isPresented: $showingRecordingsSheet) {
                        GeometryReader { sheetGeometry in
                            VStack { // Use a VStack to arrange the ScrollView and the Transcription Panel
                                ScrollView {
                                    LazyVStack(spacing: 16) {
                                        ForEach(Array(allRecordings.enumerated()), id: \.element.id) { index, recording in
                                            RecordingRowView(
                                                recording: recording,
                                                isCurrentlyPlaying: currentPlayingRecordingID == recording.id && isPlaying,
                                                onTap: { selectRecording(at: index) }
                                            )
                                        }
                                    }
                                    .padding()
                                    .padding(.top, 20)
                                }
                                .frame(width: sheetGeometry.size.width, height: sheetGeometry.size.height * 0.6) // Adjust height for recordings
                                .background(.clear)

                                // MARK: Transcription Panel - Moved inside the sheet
                                if showTranscriptionPanel, let recordingToTranscribe = currentRecording {
                                    VStack {
                                        // Spacer() // No need for Spacer here if you want it below the scroll view
                                        DisclosureGroup(isExpanded: $showTranscriptionPanel) {
                                            RecordingDetailView(recording: recordingToTranscribe)
                                                .frame(height: 250) // Adjust height as needed
                                                .background(Color(.systemBackground))
                                                .cornerRadius(10)
                                                .shadow(radius: 5)
                                        } label: {
                                            Text("Transkripsiyon Detayları")
                                                .font(.headline)
                                                .padding()
                                                .frame(maxWidth: .infinity)
                                                .background(Color.accentColor.opacity(0.2))
                                                .cornerRadius(10)
                                        }
                                        .padding()
                                        .transition(.move(edge: .bottom)) // Smooth transition
                                    }
                                    .frame(width: sheetGeometry.size.width) // Ensure it takes full width of the sheet
                                    .background(Color(.systemBackground)) // Add a background for the panel itself
                                    .cornerRadius(10) // Optional: Add corner radius to the panel
                                }
                            }
                            .frame(width: sheetGeometry.size.width, height: sheetGeometry.size.height) // This VStack will take the full sheet size
                        }
                    }
                }
        .overlay(toolbar,alignment: .center)
        .overlay(attemptToPage,alignment: .bottom)
            .onAppear {
                setupToolPicker()
                loadDrawingData(for: page)
            }
            .onDisappear {
                saveCurrentDrawingData()
                // Clear Undo/Redo history when leaving the page/note
                actionHistory = []
                actionHistoryIndex = -1
                print("Undo/Redo history cleared.") // Debug
            }
            // Photos Picker for adding images
            .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        // Call addAttachment and record the action *within* addAttachment
                        addAttachment(imageData: data)
                        selectedPhotoItem = nil // Clear selection
                    }
                }
            }

            // MARK: - Toolbar Buttons
            // Sayfa Navigasyon Butonları
            HStack {
                Button(action: previousPage) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .padding(10)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
                .disabled(isFirstPage())
                .accessibilityLabel("Önceki Sayfa")
                
                Spacer() // Push page navigation buttons to the ends
                
                
                
                
                // MARK: Undo/Redo Buttons
                /*
                Button(action: undo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.title2)
                        .padding(10)
                        .background(canUndo ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
                .disabled(!canUndo)
                .accessibilityLabel("Geri Al")

                Button(action: redo) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.title2)
                        .padding(10)
                        .background(canRedo ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
                .disabled(!canRedo)
                .accessibilityLabel("İleri Al")

                Spacer() // Push page navigation buttons to the ends
*/
                
                
                Button(action: nextPage) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .padding(10)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
                .disabled(isLastPage())
                .accessibilityLabel("Sonraki Sayfa")
                
                // MARK: - Sayfa Silme Butonu
                            if let currentPage = page {
                                Button(role: .destructive) { // .destructive rolü, butona kırmızı renk verir
                                    deletePage(currentPage)
                                } label: {
                                    Label("Bu Sayfayı Sil", systemImage: "trash.fill")
                                }
                                .padding()
                                .background(Color.red.opacity(0.1)) // Hafif kırmızı arka plan
                                .cornerRadius(10)
                            } else {
                                Text("Sayfa silmek için mevcut sayfa yok.")
                                    .foregroundColor(.gray)
                            }
                        
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Araç Seçimi ve Yeni Sayfa Butonları
            HStack {
                /*
                // Resim Ekle Butonu
                Button(action: { showingImagePicker = true }) {
                    Image(systemName: "photo")
                        .font(.title2)
                        .padding(10)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Resim Ekle")

                Spacer() // Push tool selection buttons to the center
                // MARK: Audio Recording Button // << Ses Kaydı Butonu
                Button(action: {
                    if isRecording {
                        stopRecording()
                    } else {
                                        // Kayıt başlatmadan önce aktif ses işlemlerini durdur
                        stopPlayback()
                        startRecording()
                    }
                }) {
                    Image(systemName: isRecording ? "mic.fill.badge.xmark" : "mic.fill")
                        .font(.title2)
                        .padding(10)
                        .background(isRecording ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                        .clipShape(Circle())
                    }
                .disabled(isPlaying) // Sadece oynatma sırasında kaydı engelle, kayıt sırasında oynatma zaten durdurulur
                .accessibilityLabel(isRecording ? "Kaydı Durdur" : "Ses Kaydı Başlat")

                Button(action: {
                    // Eğer bir kayıt varsa ve şu an bir şey oynatılmıyorsa, ilk kaydı oynat
                                     if (!recordings.isEmpty && !isPlaying) {
                                         // Oynatmadan önce aktif kayıt işlemini durdur
                                         stopRecording()
                                         playRecording(recordings.first!) // plays the first recording
                                     } else if isPlaying {
                                         stopPlayback() // Eğer oynatılıyorsa durdur
                                     }
                                 }) {
                                     Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                         .font(.title2)
                                         .padding(10)
                                         .background(Color.yellow.opacity(0.2))
                                         .clipShape(Circle())
                                 }
                                 .disabled(recordings.isEmpty || isRecording)
                                 .accessibilityLabel(isPlaying ? "Oynatmayı Durdur" : "İlk Kaydı Oynat")

                // Kalem Butonu
                Button(action: selectPen) {
                    Image(systemName: "pencil.tip")
                        .font(.title2)
                        .padding(10)
                        .background(isSelected(toolType: .pen) ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Kalem")
                

                // Silgi Butonu
                Button(action: selectEraser) {
                    Image(systemName: "eraser")
                        .font(.title2)
                        .padding(10)
                        .background(currentTool is PKEraserTool ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Silgi")

                // Fosforlu Kalem Butonu
                Button(action: selectHighlighter) {
                    Image(systemName: "highlighter")
                        .font(.title2)
                        .padding(10)
                        .background(isSelected(toolType: .marker) ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Fosforlu Kalem")

                // Kurşun Kalem Butonu
                Button(action: selectBrush) {
                    Image(systemName: "paintbrush") // or "pencil"
                        .font(.title2)
                        .padding(10)
                        .background(isSelected(toolType: .pencil) ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Fırça")

                Spacer() // Push tool selection buttons to the center

                // Tüm Ekleri Sil Butonu (Add confirmation dialog in a real app)
                 Button(action: {
                     // Ensure page is not nil before attempting to delete
                     if let currentPage = page {
                         // This function will now also record delete actions
                         deleteAllAttachments(for: currentPage, in: viewContext)
                     }
                 }) {
                     Image(systemName: "trash.fill")
                         .font(.title2)
                         .padding(10)
                         .background(Color.red.opacity(0.2))
                         .clipShape(Circle())
                 }
                 .accessibilityLabel("Tüm Ekleri Sil")
                    ---------*/
                //PDF Ekleme Butonu
            /*
                PDFImporterButton(
                            showPDFImporter: $showPDFImporter,
                            onImport: handlePDFImport
                )
                */
                /*
                // Yeni Sayfa Ekle Butonu
                Button(action: addNewPage) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .padding(10)
                        .background(Color.green.opacity(0.2))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Yeni Sayfa Ekle")*/
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: page?.id) { oldPageId, newPageId in
            // When page changes, save old page and load new page
            if oldPageId != newPageId {
                // saveCurrentDrawingData() // Save is already handled by onDisappear or page navigation funcs
                loadDrawingData(for: page)
                actionHistory = []
                actionHistoryIndex = -1
                print("Page changed, Undo/Redo history cleared.") // Debug
            }
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Hata"),
                message: Text("Çizim verisi yüklenirken hata oluştu: \(loadError?.localizedDescription ?? "Bilinmeyen hata")"),
                dismissButton: .default(Text("Tamam")) {
                    loadError = nil
                }
            )
        }
    }
    // Apple Pencil dokunuşunu kontrol et
        private func isPencilTouch(_ value: DragGesture.Value) -> Bool {
            // iOS 14+ için UITouch.TouchType kontrolü
            if #available(iOS 14.0, *) {
                // Gesture'dan UITouch bilgisine erişim sınırlı
                // Alternatif: Force değeri ile tahmin
                return value.predictedEndLocation != value.location
            }
            return false
        }
    //MARK: Drag İşlemi
    private func limitedOffset(_ newOffset: CGSize) -> CGSize {
        let maxOffsetX = max(0, (frameSize * (scale - 1)) / 2)
        let maxOffsetY = max(0, (frameSize * (scale - 1)) / 2)
        
        let limitedX = min(max(newOffset.width, -maxOffsetX), maxOffsetX)
        let limitedY = min(max(newOffset.height, -maxOffsetY), maxOffsetY)
        
        return CGSize(width: limitedX, height: limitedY)
    }
    
    // Mevcut offset'i limitlerle kontrol et
    private func limitOffset() {
        offset = limitedOffset(offset)
        lastOffset = offset
    }
    //MARK: SES İŞLEMLERİ
        private func setupInitialState() {
                if !allRecordings.isEmpty && currentRecording != nil {
                    loadRecordingDuration()
                }
            }
            
            private func selectRecording(at index: Int) {
                guard index < allRecordings.count else { return }
                if (isPlaying && currentRecordingIndex == index){
                    togglePlayback()
                    return
                }
                stopPlayback()
                currentRecordingIndex = index
                loadRecordingDuration()
                playCurrentRecording()
            }
            
            private func loadRecordingDuration() {
                guard let recording = currentRecording,
                      let audioData = recording.fileData else {
                    totalDuration = 0.0
                    return
                }
                
                do {
                    let tempPlayer = try AVAudioPlayer(data: audioData)
                    totalDuration = tempPlayer.duration
                    currentTime = 0.0
                    playbackProgress = 0.0
                } catch {
                    print("Error loading duration: \(error)")
                    totalDuration = 0.0
                }
            }
            
            private func playCurrentRecording() {
                guard let recording = currentRecording,
                      let audioData = recording.fileData else {
                    print("Error: Recording data is missing")
                    return
                }
                if !isPlayerVisible {
                    isPlayerVisible.toggle()
                }
                
                let audioSession = AVAudioSession.sharedInstance()
                do {
                    try audioSession.setCategory(.playback, mode: .default, options: [])
                    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                    
                    audioPlayer = try AVAudioPlayer(data: audioData)
                    audioPlayer?.currentTime = currentTime
                    audioPlayer?.play()
                    
                    isPlaying = true
                    currentPlayingRecordingID = recording.id
                    
                    startProgressTimer()
                    showTranscriptionPanel = true
                } catch {
                    print("Error starting playback: \(error)")
                    loadError = error
                    showErrorAlert = true
                }
            }
            
            private func togglePlayback() {
                if isPlaying {
                    pausePlayback()
                } else {
                    resumePlayback()
                }
            }
            
            private func pausePlayback() {
                audioPlayer?.pause()
                isPlaying = false
                stopProgressTimer()
            }
            
            private func resumePlayback() {
                if audioPlayer != nil {
                    audioPlayer?.play()
                    isPlaying = true
                    startProgressTimer()
                } else {
                    playCurrentRecording()
                }
            }
            
            private func stopPlayback() {
                audioPlayer?.stop()
                isPlaying = false
                currentPlayingRecordingID = nil
                currentTime = 0.0
                playbackProgress = 0.0
                stopProgressTimer()
                do {
                    try AVAudioSession.sharedInstance().setActive(false)
                } catch {
                    print("Error deactivating audio session: \(error)")
                }
                
                audioPlayer = nil
                showTranscriptionPanel = false
            }
            
            private func previousRecording() {
                if currentRecordingIndex > 0 {
                    selectRecording(at: currentRecordingIndex - 1)
                }
            }
            
            private func nextRecording() {
                if currentRecordingIndex < allRecordings.count - 1 {
                    selectRecording(at: currentRecordingIndex + 1)
                }
            }
            
            private func seekToTime(_ time: Double) {
                currentTime = time
                audioPlayer?.currentTime = time
                
                if totalDuration > 0 {
                    playbackProgress = time / totalDuration
                }
            }
            
            private func skipBackward(seconds: Double) {
                let newTime = max(0, currentTime - seconds)
                seekToTime(newTime)
            }
            
            private func skipForward(seconds: Double) {
                let newTime = min(totalDuration, currentTime + seconds)
                seekToTime(newTime)
            }
            
            private func startProgressTimer() {
                stopProgressTimer()
                playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    guard let player = audioPlayer, !isDragging else { return }
                    
                    currentTime = player.currentTime
                    
                    if totalDuration > 0 {
                        playbackProgress = currentTime / totalDuration
                    }
                    
                    // Oynatma bittiğinde
                    if !player.isPlaying && isPlaying {
                        if currentTime >= totalDuration - 0.1 {
                            // Sonraki kayda geç
                            if currentRecordingIndex < allRecordings.count - 1 {
                                nextRecording()
                            } else {
                                stopPlayback()
                            }
                        }
                    }
                }
            }
            
            private func stopProgressTimer() {
                playbackTimer?.invalidate()
                playbackTimer = nil
            }
    
    // MARK: - Helper Functions for Button State
    private func isFirstPage() -> Bool {
        guard let currentPage = page, let firstPage = pages.first else { return true }
        return currentPage.pageIndex == firstPage.pageIndex
    }

    private func isLastPage() -> Bool {
        guard let currentPage = page, let lastPage = pages.last else { return true }
        return currentPage.pageIndex == lastPage.pageIndex
    }

    private func isSelected(toolType: PKInkingTool.InkType) -> Bool {
        guard let inkingTool = currentTool as? PKInkingTool else { return false }
        return inkingTool.inkType == toolType
    }

    // MARK: - Core Logic (Drawing & Saving)
    private func setupToolPicker() {
        // Tool picker is attached to the canvas view, even if hidden.
        // This setup is correct.
        toolPicker.setVisible(false, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        selectPen() // Set a default tool
    }

    private func loadDrawingData(for pageToLoad: Page?) {
        DispatchQueue.main.async {
            if let targetPage = pageToLoad, let drawingData = targetPage.drawingData {
                do {
                    // If drawingData is empty, it's a blank page, create a new drawing
                    if drawingData.isEmpty {
                        canvasView.drawing = PKDrawing()
                        print("Loaded empty drawing for page \(targetPage.pageIndex).")
                    } else {
                        let drawing = try PKDrawing(data: drawingData)
                        canvasView.drawing = drawing
                         print("Loaded drawing data for page \(targetPage.pageIndex). Data size: \(drawingData.count)") // Debug
                    }
                } catch {
                    print("Error loading drawing data for page \(targetPage.pageIndex): \(error.localizedDescription)")
                    loadError = error
                    showErrorAlert = true
                    canvasView.drawing = PKDrawing() // Clear canvas on error
                }
            } else {
                // If no page is selected or page has no data, clear canvas
                canvasView.drawing = PKDrawing()
                 print("No page or no data, cleared canvas.") // Debug
            }
        }
    }

    // Saves the current drawing data for a specific page object
    private func saveDrawingData(for pageToSave: Page) {
        // Check if the drawing has actually changed before saving
        let currentDrawingData = canvasView.drawing.dataRepresentation()
         print("Attempting to save drawing for page \(pageToSave.pageIndex). Current data size: \(currentDrawingData.count)") // Debug

        pageToSave.drawingData = currentDrawingData

        do {
            // Use performAndWait to ensure save completes before potentially changing page
            try viewContext.performAndWait {
                 if viewContext.hasChanges {
                    try viewContext.save()
                    print("Successfully saved drawing for page \(pageToSave.pageIndex).") // Debug
                } else {
                     print("View context has no changes to save for drawing on page \(pageToSave.pageIndex).") // Debug
                 }
            }
        } catch {
            print("Error saving drawing data for page \(pageToSave.pageIndex): \(error.localizedDescription)")
            // Consider showing a user alert here
        }
    }

    // Saves the drawing for the currently active page
    private func saveCurrentDrawingData() {
        guard let currentPage = page else { return }
        saveDrawingData(for: currentPage)
    }

    // MARK: - Navigation
    private func previousPage() {
        guard let currentPage = page,
              let currentIndex = pages.firstIndex(of: currentPage),
              currentIndex > 0 else { return }

        saveDrawingData(for: currentPage) // Save current page before navigating
        page = pages[currentIndex - 1]    // Change the bound page
        // loadDrawingData will be triggered by the onChange(of: page?.id)
         print("Navigating to previous page: \(page?.pageIndex ?? -1)") // Debug
    }

    private func nextPage() {
        guard let currentPage = page,
              let currentIndex = pages.firstIndex(of: currentPage),
              currentIndex < pages.count - 1 else { return }

        saveDrawingData(for: currentPage) // Save current page before navigating
        page = pages[currentIndex + 1]    // Change the bound page
        // loadDrawingData will be triggered by the onChange(of: page?.id)
         print("Navigating to next page: \(page?.pageIndex ?? -1)") // Debug
    }

    private func addNewPage() {
        // Ensure we have a note to add the page to
        guard let currentNote = page?.note ?? pages.first?.note else {
            print("Error: Note not found to add new page.")
            return
        }

        // Save the current page's drawing before creating a new one
        if let currentPage = page {
            saveDrawingData(for: currentPage)
        }

        // Create the new page
        let newPageIndex = (pages.map { $0.pageIndex }.max() ?? -1) + 1
        let newPage = Page(context: viewContext)
        newPage.id = UUID()
        newPage.note = currentNote
        newPage.pageIndex = Int16(newPageIndex)
        newPage.drawingData = Data() // Start with empty drawing data
        // Other page properties if any...

        // Save the context to persist the new page
        do {
            try viewContext.save()
            print("New page created and saved: Index \(newPageIndex)") // Debug
            // Set the newly created page as the current page
            DispatchQueue.main.async {
                 page = newPage
                 print("Current page set to new page: Index \(newPage.pageIndex)") // Debug
                 // loadDrawingData is triggered by the onChange(of: page?.id)
            }
        } catch {
            print("Error creating/saving new page: \(error.localizedDescription)")
            viewContext.rollback() // Rollback changes on error
            // Consider showing user alert
        }
    }
    
    //Delete page fonksiyonu denemesi
    
    private func deletePage(_ pageToDelete: Page) {
        guard let viewContext = pageToDelete.managedObjectContext else {
            print("Error: Cannot delete page, no managed object context found.")
            return
        }

        let deletedPageIndex = pageToDelete.pageIndex

        var pageToTransitionTo: Page? = nil
        if pageToDelete == page {
            if let currentIndex = pages.firstIndex(of: pageToDelete) {
                if currentIndex + 1 < pages.count {
                    pageToTransitionTo = pages[currentIndex + 1]
                } else if currentIndex > 0 {
                    pageToTransitionTo = pages[currentIndex - 1]
                }
            }
        }
        viewContext.delete(pageToDelete)
        do {
            try viewContext.save()
            print("Page deleted successfully: Index \(deletedPageIndex)")

            var index: Int16 = 0
            for page in pages.sorted(by: { $0.pageIndex < $1.pageIndex }) {
                if page.pageIndex != index {
                    page.pageIndex = index
                }
                index += 1
            }
            try viewContext.save()
            print("Pages re-indexed successfully.")

            DispatchQueue.main.async {
                if let transitionPage = pageToTransitionTo {
                    self.page = transitionPage
                    print("Current page set to: Index \(transitionPage.pageIndex)")
                } else if let firstRemainingPage = self.pages.first {
                    self.page = firstRemainingPage
                    print("Current page set to first remaining page: Index \(firstRemainingPage.pageIndex)")
                } else {
                    print("No pages left after deletion. Adding a new default page.")
                    self.addNewPage()
                }
            }

        } catch {
            print("Error deleting or re-indexing pages: \(error.localizedDescription)")
            viewContext.rollback()
        }
    }
    
    // MARK: - Tool Selection
    // Located in NotePageView.swift
    // Around Page 22-23

    private func selectPen() {
        // Adım 1: Kullanıcı "Kalem" aracını seçti.
        // Amacımız her zaman `toolSettings.lastPenTool` içinde saklanan,
        // yani kalemin kendine ait son ayarlarını (renk ve kalınlık) yüklemektir.
        // Diğer araçların (fosforlu kalem, silgi vb.) renkleri kalemin rengini değiştirmemeli.

        // `toolSettings.lastPenTool` değişkeni, ToolSettings sınıfında .pen tipinde,
        // siyah renk ve 5 kalınlığında bir kalem olarak başlatılır:
        // `@Published var lastPenTool = PKInkingTool(.pen, color: .black, width: 5)`
        // Bu değişken, kalem ayarları paletten her değiştirildiğinde güncellenmelidir.

        // Adım 2: Şu anki aktif aracı (`currentTool`) doğrudan `toolSettings.lastPenTool` ile ayarla.
        // Bu satır, kalem seçildiğinde HER ZAMAN kalemin kendi hafızasındaki (toolSettings.lastPenTool)
        // ayarların yüklenmesini sağlar.
        currentTool = toolSettings.lastPenTool; // [cite: 71] // KRİTİK DÜZELTME BU SATIRDADIR.

        // Adım 3: `showPalette` ve `penSelectedOnce` mantığı.
        // Bu kısım, paletin kullanıcı aynı araca ikinci kez tıkladığında açılıp açılmayacağını kontrol eder.
        // Renk sorununu doğrudan çözmez, ancak kullanıcı arayüzü etkileşiminin bir parçasıdır.
        // Eğer `penSelectedOnce` true ise (kullanıcı kısa bir süre önce zaten kaleme tıklamıştı), paleti göster.
        if penSelectedOnce {
            showPalette = true; // [cite: 70]
            penSelectedOnce = false; // [cite: 70] // Palet açıldı, bu durumu sıfırla.
        } else {
            // Eğer `penSelectedOnce` false ise (kalem yeni seçiliyor veya başka bir araçtan kaleme geçiliyor),
            // `penSelectedOnce`'ı true yap. Bu, bir sonraki tıklamada paletin açılmasını sağlar.
            penSelectedOnce = true; // [cite: 71]
            // Kısa bir süre sonra `penSelectedOnce`'ı otomatik olarak false yapmak için:
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // self.penSelectedOnce = false // Eğer bu satır aktifse, kullanıcı 1.5 saniye içinde
                                             // tekrar tıklamazsa palet açılmaz. Bu kısmı ihtiyacınıza göre ayarlayın.
                                             // Genellikle, paleti göstermek için bu gecikmeli sıfırlama yerine,
                                             // aracın zaten seçili olup olmadığını kontrol etmek daha yaygındır.
                                             // Şimdilik orijinal mantığınıza sadık kalıyoruz.
            }
        }
        
        // Adım 4: Konsola Hata Ayıklama Mesajı (İsteğe Bağlı)
        // O anda `toolSettings.lastPenTool`'un ne olduğunu görmek için:
        if let penTool = toolSettings.lastPenTool as? PKInkingTool {
            print("Kalem aracı seçildi. Yüklenen renk: \(penTool.color), kalınlık: \(penTool.width)")
        }
        print("Tool selected: Pen (Debug Message)")
    }

    private func selectLassoTool() {
        currentTool = PKLassoTool()
        print("Tool selected: Lasso Tool (Selection)")
    }


    private func selectEraser() {
        currentTool = PKEraserTool(.vector) // or .bitmap
        print("Tool selected: Eraser") // Debug
    }

    private func selectHighlighter() {
        // Highlight color and opacity might need adjustment
        currentTool = PKInkingTool(.marker, color: .yellow.withAlphaComponent(0.5), width: 15)
        print("Tool selected: Highlighter") // Debug
    }

    private func selectBrush() {
        // .pencil is the closest InkType to a brush/pencil effect
        currentTool = PKInkingTool(.pencil, color: .blue, width: 10)
        print("Tool selected: Brush (Pencil type)") // Debug
    }

    // MARK: - Attachment Handling
    private func addAttachment(imageData: Data) {
        guard let currentPage = page else {
             print("Error: Cannot add attachment, current page is nil.")
             return
        }

        let canvasWidth: Double = 300.0 // Replace with actual canvas width if using GeometryReader dynamically
        let canvasHeight: Double = 601.0 // Replace with actual canvas height if using GeometryReader dynamically

        let defaultAttachmentWidth: Double = 150.0
        let defaultAttachmentHeight: Double = 150.0 // Or calculate based on aspect ratio

        // Calculate initial top-left position to center the attachment
        let initialPositionX = (canvasWidth / 2.0) - (defaultAttachmentWidth / 2.0)
        let initialPositionY = (canvasHeight / 2.0) - (defaultAttachmentHeight / 2.0)


        let newAttachment = Attachment(context: viewContext)
        let attachmentID = UUID() // Generate ID before saving
        newAttachment.id = attachmentID
        newAttachment.page = currentPage
        newAttachment.fileData = imageData
        newAttachment.positionX = Float(initialPositionX) // Store top-left X
        newAttachment.positionY = Float(initialPositionY) // Store top-left Y
        newAttachment.width = Float(defaultAttachmentWidth)
        newAttachment.height = Float(defaultAttachmentHeight)
        // newAttachment.timestamp = Date()

        // Save the new attachment to Core Data
        do {
            if viewContext.hasChanges {
                try viewContext.save()
                print("New attachment created and saved.") // Debug
                // Record the action *after* successful saving
                recordAction(.addAttachment(attachmentID: attachmentID, data: imageData, x: Float(initialPositionX), y: Float(initialPositionY), width: Float(defaultAttachmentWidth), height: Float(defaultAttachmentHeight)))
            }
        } catch {
            print("Error saving new attachment: \(error.localizedDescription)")
            viewContext.rollback() // Rollback changes on error
            // Consider showing user alert
        }
    }

     // Deletes all attachments for a given page
     func deleteAllAttachments(for page: Page, in context: NSManagedObjectContext) {
         guard let attachmentsToDelete = page.attachments as? Set<Attachment>, !attachmentsToDelete.isEmpty else {
             print("No attachments to delete for page \(page.pageIndex).")
             return // Nothing to delete
         }

         print("Deleting \(attachmentsToDelete.count) attachments for page \(page.pageIndex)...") // Debug

         // Record deletion actions *before* actually deleting the objects
         // Iterate over a copy because deleting modifies the set
         let attachmentsCopy = Array(attachmentsToDelete)
         for attachment in attachmentsCopy {
             // Ensure attachment has data and properties before recording
             guard let id = attachment.id, let data = attachment.fileData else {
                 print("Skipping recording delete action for attachment with missing data/ID.")
                 continue
             }
             // Record the delete action with enough info to recreate
             recordAction(.deleteAttachment(attachmentID: id, data: data, x: attachment.positionX, y: attachment.positionY, width: attachment.width, height: attachment.height))

             // Delete the attachment object from the context
             context.delete(attachment)
             print("Attachment \(id) marked for deletion.") // Debug
         }

         // Save the context to persist the deletions
         do {
             try context.save()
             print("All attachments successfully deleted and context saved for page \(page.pageIndex).") // Debug
             // No need to record a single 'deleteAll' action if individual ones are recorded
         } catch {
             let nsError = error as NSError
             print("Error saving context after deleting attachments: \(nsError), \(nsError.userInfo)")
             context.rollback() // Rollback changes on error
             // Consider showing user alert
         }
     }

    // Helper to fetch an attachment by ID from Core Data
    private func fetchAttachment(by id: UUID) -> Attachment? {
        let request: NSFetchRequest<Attachment> = Attachment.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        do {
            let results = try viewContext.fetch(request)
            return results.first
        } catch {
            print("Error fetching attachment by ID \(id): \(error.localizedDescription)")
            return nil
        }
    }
    
    // Helper to fetch a recording by ID from Core Data // << Yeni Helper Fonksiyon
         private func fetchRecording(by id: UUID) -> Recording? {
             let request: NSFetchRequest<Recording> = Recording.fetchRequest()
             request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
             request.fetchLimit = 1
             do {
                 let results = try viewContext.fetch(request)
                 return results.first
             } catch {
                 print("Error fetching recording by ID \(id): \(error.localizedDescription)")
                 return nil
             }
         }


        // MARK: - Audio Recording Logic // << Ses Kayıt Mantığı
        private func startRecording() {
            guard let currentPage = page else {
                print("Error: Cannot start recording, current page is nil.")
                return
            }

            // Aktif oynatmayı durdur
            stopPlayback()

            let audioSession = AVAudioSession.sharedInstance()
            do {
                // Ses oturumunu kayda hazırla
                try audioSession.setCategory(.record, mode: .measurement, options: [])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

                // Geçici kayıt dosyasının URL'sini oluştur
                let fileManager = FileManager.default
                let tempDirectory = fileManager.temporaryDirectory
                let fileName = UUID().uuidString + ".m4a" // Kayıt formatı (AAC)
                let tempURL = tempDirectory.appendingPathComponent(fileName)

                // AVAudioRecorder ayarları
                let settings = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC), // AAC formatı
                    AVSampleRateKey: 12000, // Örnekleme hızı
                    AVNumberOfChannelsKey: 1, // Mono kanal
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue // Yüksek kalite
                ]

                // AVAudioRecorder'ı başlat
                audioRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
                audioRecorder?.record() // Kaydı başlat
                isRecording = true
                recordingURL = tempURL // Geçici URL'yi sakla

                print("Recording started at URL: \(tempURL.absoluteString)") // Debug

            } catch {
                print("Error starting recording: \(error.localizedDescription)")
                loadError = error // Hata state'ini ayarla
                showErrorAlert = true // Alert'i göster
                stopRecording() // Hata durumunda kaydı durdurmayı dene
            }
        }
    private func stopRecording() {
        guard isRecording else { return }

        audioRecorder?.stop() // Kaydı durdur
        isRecording = false // State'i güncelle

        // Ses oturumunu pasifleştir (isteğe bağlı)
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
                print("Error deactivating audio session after recording: \(error.localizedDescription)")
        }

        // Kaydedilen veriyi al ve Core Data'ya kaydet
        if let url = recordingURL {
            do {
                let audioData = try Data(contentsOf: url) // Ses verisi burada alınıyor
                let duration = audioRecorder?.currentTime ?? 0 // Süre burada alınıyor

                // *** BURAYA EKLİYORUZ: saveRecording fonksiyonunu çağır ***
                // Kaydı hangi Nota kaydetmek istediğimizi belirtiyoruz (View'ın note özelliği)
                saveRecording(data: audioData, duration: duration, for: self.note) // View'ın note özelliğini kullanıyoruz


                // Geçici dosyayı sil
                try FileManager.default.removeItem(at: url)
                print("Recording stopped and temporary file deleted.") // Debug

            } catch {
                print("Error stopping recording or reading data: \(error.localizedDescription)")
                loadError = error
                showErrorAlert = true
                // Hata durumunda temporary file'ı silmeyi de düşünebilirsiniz
                try? FileManager.default.removeItem(at: url) // Opsiyonel: Hata olsa bile dosyayı sil
            }
        }

        audioRecorder = nil // Recorder'ı serbest bırak
        recordingURL = nil // URL'yi temizle
    }

        // Ses kaydını Core Data'ya kaydeden fonksiyon // << Yeni Kaydetme Fonksiyonu
    // Ses kaydını Core Data'ya kaydeden fonksiyon // << Note Parametresi Alan Güncellenmiş Fonksiyon
    private func saveRecording(data: Data, duration: TimeInterval, for note: Note) {
        // İlgili Note parametre olarak geliyor

        // Yeni bir Recording nesnesi oluştur
        let newRecording = Recording(context: viewContext)
        let recordingID = UUID() // ID oluştur
        newRecording.id = recordingID
        newRecording.fileData = data // Ses verisi
        newRecording.createdAt = Date() // Kayıt zamanı
        newRecording.duration = Float(duration) // Süre

        // *** BURASI ÖNEMLİ: Kaydı parametre olarak gelen Note'a bağla ***
        // Core Data modelinizde Recording varlığında 'note' adında Note'a giden bir to-one ilişki olduğunu varsayıyoruz.
        // Eğer ilişkinin adı farklıysa burayı düzeltin.
        newRecording.note = note // İlişkiyi kur

        do {
            try viewContext.performAndWait {
                if viewContext.hasChanges {
                    try viewContext.save()
                    print("Successfully saved recording with ID \(recordingID) and linked to note \(note.objectID).") // Debug
                    // Kaydı kaydettikten sonra aksiyonu kaydet
                    // recordAction(.addRecording(recordingID: recordingID, noteID: note.id)) // Eğer ActionType enum'ına noteID eklerseniz
                    // recordAction(.addRecording(recordingID: recordingID)) // Mevcut ActionType'a göre. Bunu bug olmaması için iptal ettim.
                } else {
                     print("View context has no changes to save for recording on note \(note.objectID).") // Debug
                 }
            }
        } catch {
            print("Error saving new recording for note \(note.objectID): \(error.localizedDescription)")
            viewContext.rollback() // Hata durumunda geri al
            loadError = error
            showErrorAlert = true
        }
    }
    
         // MARK: - Audio Playback Logic // << Ses Oynatma Mantığı
         private func playRecording(_ recording: Recording) {
             guard let audioData = recording.fileData else {
                 print("Error: Recording data is missing for playback.")
                 return
             }
             isPlayerVisible.toggle()
             // Aktif kaydı durdur
             stopRecording()
             // Aktif oynatmayı durdur (başka bir kaydı oynatmak için)
             stopPlayback()

             let audioSession = AVAudioSession.sharedInstance()
             do {
                 // Ses oturumunu oynatmaya hazırla
                 try audioSession.setCategory(.playback, mode: .default, options: [])
                 try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

                 // AVAudioPlayer'ı başlat
                 audioPlayer = try AVAudioPlayer(data: audioData)
                 audioPlayer?.delegate = nil // Delegate'i kullanmıyoruz şimdilik, oynatma bitince state'i manuel güncelleyeceğiz
                 audioPlayer?.play() // Oynatmayı başlat
                 isPlaying = true // State'i güncelle
                 currentPlayingRecordingID = recording.id // Oynatılan kaydın ID'sini sakla

                 print("Playback started for recording with ID: \(recording.id?.uuidString ?? "nil")") // Debug

                 // Oynatma bitince isPlaying state'ini false yapmak için küçük bir gecikme ekleyebiliriz
                 // Veya AVAudioPlayerDelegate'i kullanabiliriz. Delegate daha sağlamdır.
                 // Basitlik için gecikme kullanalım, ancak delegate daha doğru bir yaklaşımdır.
                 let duration = audioPlayer?.duration ?? 0
                 if duration > 0 {
                     DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                         // Oynatma bittiğinde state'i güncelle
                         if self.isPlaying && self.currentPlayingRecordingID == recording.id {
                             self.stopPlayback()
                             print("Playback finished for recording with ID: \(recording.id?.uuidString ?? "nil")") // Debug
                         }
                     }
                 }


             } catch {
                 print("Error starting playback: \(error.localizedDescription)")
                 loadError = error
                 showErrorAlert = true
                 stopPlayback() // Hata durumunda oynatmayı durdurmayı dene
             }
         }


    // MARK: - Undo/Redo Logic

    // Records an action, managing history stack and index
    private func recordAction(_ action: ActionType) {
        // Clear any actions ahead of the current index (redo history)
        if actionHistoryIndex < actionHistory.count - 1 {
            let startIndex = actionHistoryIndex + 1
            actionHistory.removeSubrange(startIndex..<actionHistory.count)
             print("Cleared redo history (\(actionHistory.count - 1 - actionHistoryIndex) actions).") // Debug
        }

        // Add the new action
        actionHistory.append(action)
        actionHistoryIndex += 1
         print("Recorded action: \(action) at index \(actionHistoryIndex). Total history size: \(actionHistory.count)") // Debug

        // Trim history if it exceeds the max size
        if actionHistory.count > maxActionHistorySize {
            actionHistory.removeFirst()
            actionHistoryIndex -= 1 // Adjust index because the first element was removed
             print("History trimmed, oldest action removed. New size: \(actionHistory.count), index: \(actionHistoryIndex)") // Debug
        }
    }
    
    // Performs an action or its inverse
    // isReverse = true means perform the inverse (undo)
    // isReverse = false means perform the action (redo)// Performs an action or its inverse
    // isReverse = true means perform the inverse (undo)
    // isReverse = false means perform the action (redo)
    private func performAction(_ action: ActionType, isReverse: Bool) {
        print("Performing action: \(action), reverse: \(isReverse)") // Debug
        do {
            switch action {
            case .drawing:
                if isReverse {
                    // Ekleme işlemini Geri Al: Eklenen eki sil.
                    undoTapped = true
                    
                } else {
                    // Ekleme işlemini Yinele: Ek zaten var olmalı
                    redoTapped = true
                }
                // Geri alma/Yineleme fonksiyonları

            case .addAttachment(let attachmentID, let data, let x, let y, let width, let height):
                if isReverse {
                    // Ekleme işlemini Geri Al: Eklenen eki sil.
                    if let attachment = fetchAttachment(by: attachmentID) {
                        viewContext.delete(attachment)
                        print("Undo: Deleted attachment with ID \(attachmentID).")
                         // Core Data'ya kaydet
                        if viewContext.hasChanges { try viewContext.save() }
                    } else {
                        print("Undo Add Error: Attachment \(attachmentID) not found.")
                    }
                } else {
                    // Ekleme işlemini Yinele: Ek zaten var olmalı (geri alma sırasında silindiyse).
                    // Core Data fetch request bu nesneyi tekrar gösterecektir.
                    guard let currentPage = page else {
                         print("Undo Delete Error: Current page is nil, cannot recreate attachment.")
                         return
                    }
                    let newAttachment = Attachment(context: viewContext)
                    newAttachment.id = attachmentID // Orijinal ID'yi kullan
                    newAttachment.page = currentPage // Mevcut sayfaya bağla
                    newAttachment.fileData = data // Veriyi geri yükle
                    newAttachment.positionX = x // Konumu geri yükle
                    newAttachment.positionY = y
                    newAttachment.width = width
                    newAttachment.height = height
                     // Eğer undo işlemi Core Data nesnesini tamamen sildiyse ve burada recreate etmek gerekirse,
                     // ActionType.addAttachment'ın data taşıması gerekirdi.
                     // Mevcut yapıda fetchRequest'in yeterli olduğu varsayılıyor.
                }

            case .deleteAttachment(let attachmentID, let data, let x, let y, let width, let height):
                if isReverse {
                    // Silme işlemini Geri Al: Silinen eki yeniden oluştur.
                    guard let currentPage = page else {
                         print("Undo Delete Error: Current page is nil, cannot recreate attachment.")
                         return
                    }
                    let newAttachment = Attachment(context: viewContext)
                    newAttachment.id = attachmentID // Orijinal ID'yi kullan
                    newAttachment.page = currentPage // Mevcut sayfaya bağla
                    newAttachment.fileData = data // Veriyi geri yükle
                    newAttachment.positionX = x // Konumu geri yükle
                    newAttachment.positionY = y
                    newAttachment.width = width
                    newAttachment.height = height
                    // newAttachment.timestamp = ... // Gerekirse zaman damgasını geri yükle

                    // viewContext.insert(newAttachment) // Context ile oluşturulduğunda insert zaten olur

                    print("Undo: Recreated attachment with ID \(attachmentID).")
                     // Core Data'ya kaydet
                    if viewContext.hasChanges { try viewContext.save() }

                } else {
                    // Silme işlemini Yinele: Eki tekrar sil.
                    if let attachment = fetchAttachment(by: attachmentID) {
                        viewContext.delete(attachment)
                        print("Redo: Deleted attachment with ID \(attachmentID).")
                         // Core Data'ya kaydet
                        if viewContext.hasChanges { try viewContext.save() }
                    } else {
                         print("Redo Delete Warning: Attachment \(attachmentID) not found (already deleted?).")
                    }
                }
            case .addRecording(let recordingID):
                             if isReverse {
                                 // Kayıt ekleme işlemini Geri Al: Eklenen kaydı sil.
                                 if let recording = fetchRecording(by: recordingID) {
                                     viewContext.delete(recording)
                                     print("Undo: Deleted recording with ID \(recordingID).")
                                     // Core Data'ya kaydet
                                     if viewContext.hasChanges { try viewContext.save() }
                                 } else {
                                     print("Undo Add Recording Error: Recording \(recordingID) not found.")
                                 }
                             } else {
                                  // Kayıt ekleme işlemini Yinele: Kayıt zaten var olmalı.
                                 print("Redo: Ensure recording \(recordingID) exists (Core Data fetch handles this).")
                             }

                         case .deleteRecording(let recordingID, let data, let duration, let timestamp):
                             if isReverse {
                                 // Kayıt silme işlemini Geri Al: Silinen kaydı yeniden oluştur.
                                 guard let currentPage = page else {
                                     print("Undo Delete Recording Error: Current page is nil, cannot recreate recording.")
                                     return
                                 }
                                 let newRecording = Recording(context: viewContext)
                                 newRecording.id = recordingID // Orijinal ID'yi kullan
                                 newRecording.fileData = data // Veriyi geri yükle
                                 newRecording.duration = Float(duration) // Süreyi geri yükle
                                 newRecording.createdAt = timestamp // Zaman damgasını geri yükle

                                  // viewContext.insert(newRecording) // Context ile oluşturulduğunda insert zaten olur

                                 print("Undo: Recreated recording with ID \(recordingID).")
                                 // Core Data'ya kaydet
                                 if viewContext.hasChanges { try viewContext.save() }

                             } else {
                                 // Kayıt silme işlemini Yinele: Kaydı tekrar sil.
                                 if let recording = fetchRecording(by: recordingID) {
                                     viewContext.delete(recording)
                                     print("Redo: Deleted recording with ID \(recordingID).")
                                     // Core Data'ya kaydet
                                     if viewContext.hasChanges { try viewContext.save() }
                                 } else {
                                      print("Redo Delete Recording Warning: Recording \(recordingID) not found (already deleted?).")
                                 }
                             }
            case .moveAttachment(let attachmentID, let oldX, let oldY, let newX, let newY):
                if let attachment = fetchAttachment(by: attachmentID) {
                    if isReverse {
                        // Taşıma işlemini Geri Al: Eski konuma dön.
                        attachment.positionX = oldX
                        attachment.positionY = oldY
                        print("Undo: Moved attachment \(attachmentID) to (\(oldX), \(oldY)).")
                    } else {
                        // Taşıma işlemini Yinele: Yeni konumu uygula.
                        attachment.positionX = newX
                        attachment.positionY = newY
                         print("Redo: Moved attachment \(attachmentID) to (\(newX), \(newY)).")
                    }
                     // Core Data'ya kaydet
                     if viewContext.hasChanges { try viewContext.save() }
                } else {
                     print("Move Undo/Redo Error: Attachment \(attachmentID) not found.")
                }
            }

            // Core Data değişikliklerini kaydet (Eğer attachment işlemleri yapıldıysa).
            // Çizim işlemleri için kaydetme, sayfa değişimi veya onDisappear gibi yerlerde
            // daha verimli olabilir. performAction içinde save, her undo/redo adımında Core Data'ya yazmayı dener.
            // Eğer attachment işlemleri Core Data objelerini doğrudan değiştiriyorsa, save gereklidir.
            // MARK: Undo/Redo for Recordings // << Kayıtlar için Undo/Redo Mantığı
            
                         

        } catch {
            print("Error performing undo/redo action \(action): \(error.localizedDescription)")
            // Hata durumunda değişiklikleri geri al
            viewContext.rollback()
             // Kullanıcıya hata gösterebilirsiniz
        }
    }


    // MARK: - Undo/Redo Button Actions
    private func undo() {
        guard canUndo else { return }
        // actionHistoryIndex şu anda son gerçekleştirilen eylemin dizinini gösteriyor.
        // Geri alma, indeksi 1 azaltır.
        // Ardından, şu anki (geri alınacak) eylemin tersini uygulamak için
        // performAction'ı çağırırız.

        let actionToUndo = actionHistory[actionHistoryIndex] // Geri alacağımız eylemi al

        actionHistoryIndex -= 1 // İndeksi 1 geri al (artık bir önceki durumu gösteriyor)

        performAction(actionToUndo, isReverse: true) // Eylemin tersini uygula
        print("Undo performed. New index: \(actionHistoryIndex)") // Debug
    }
    private func redo() {
        guard canRedo else { return }
        // actionHistoryIndex şu anda son geri alınan eylemin dizinini gösteriyor (undo'dan sonra).
        // Yineleme, indeksi 1 artırır.
        // Ardından, şu anki (yeniden yapılacak) eylemi uygulamak için
        // performAction'ı çağırırız.

        actionHistoryIndex += 1 // İndeksi 1 ileri al

        let actionToRedo = actionHistory[actionHistoryIndex] // Yeniden yapacağımız eylemi al

        performAction(actionToRedo, isReverse: false) // Eylemi uygula
         print("Redo performed. New index: \(actionHistoryIndex)") // Debug
    }
    //MARK: - ADD PDF LOGIC
    func importPDF(_ pdfURL: URL) {
        guard pdfURL.startAccessingSecurityScopedResource() else {
                        print("Failed to access security scoped resource")
                        return
                    }
        
        guard let document = PDFDocument(url: pdfURL) else {
            print("Failed to load PDF document.")
            return
        }
        
        // Mevcut en yüksek pageIndex’i bul
        let existingMaxIndex = (pages.map { $0.pageIndex }.max() ?? -1)
        var newPageIndex = Int(existingMaxIndex) + 1
        
        // PDF’in her sayfası için dön
        for pageNumber in 0..<document.pageCount {
            guard let pdfPage = document.page(at: pageNumber) else { continue }
            
            // Sayfayı UIImage olarak al
            let pageBounds = pdfPage.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageBounds.size)
            let image = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(pageBounds)
                pdfPage.draw(with: .mediaBox, to: ctx.cgContext)
            }
            
            // UIImage’ı Data formatına çevir (PNG)
            guard let imageData = image.pngData() else {
                print("Failed to convert PDF page \(pageNumber) to image data.")
                continue
            }
            
            // Yeni Page entity’si oluştur
            let newPage = Page(context: viewContext)
            newPage.id = UUID()
            newPage.note = note
            newPage.pageIndex = Int16(newPageIndex)
            newPage.pdfFile = imageData
            newPage.drawingData = Data() // Başlangıçta boş
            
            newPageIndex += 1
        }
        
        // Context’i kaydet
        do {
            try viewContext.save()
            print("PDF pages imported and saved successfully.")
        } catch {
            print("Error saving PDF pages: \(error.localizedDescription)")
            viewContext.rollback()
        }
    }
    func handlePDFImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let pdfURL = urls.first {
                importPDF(pdfURL) // Assuming importPDF is defined elsewhere
            }
        case .failure(let error):
            print("Failed to import PDF: \(error.localizedDescription)")
        }
    }

}

// MARK: - CanvasView
struct CanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var toolPicker: PKToolPicker
    @Binding var currentTool: PKTool
    
    @Binding var undoTapped: Bool
    @Binding var redoTapped: Bool
    
    // Stroke bittiğinde çağrılacak closure
    var onEndStroke: (PKDrawing) -> Void
    
    func makeUIView(context: Context) -> PKCanvasView {
        print("makeUIView çağrıldı")
        canvasView.drawingPolicy = .anyInput
        canvasView.delegate = context.coordinator // Delegate'i atama - önemli!
        canvasView.isOpaque = false

        // Tool picker ayarları
        toolPicker.addObserver(canvasView)
        toolPicker.setVisible(false, forFirstResponder: canvasView)
        canvasView.becomeFirstResponder()
        
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        print("updateUIView çağrıldı")
        uiView.tool = currentTool
        
        // Delegate'in her güncellemede atandığından emin olun
        if uiView.delegate !== context.coordinator {
            print("Delegate tekrar atanıyor")
            uiView.delegate = context.coordinator
        }
        
        // Undo işlemi
        if undoTapped {
            if let undoManager = uiView.undoManager, undoManager.canUndo {
                undoManager.undo()
                print("Undo performed.")
            }
            DispatchQueue.main.async {
                undoTapped = false
            }
        }
        
        // Redo işlemi
        if redoTapped {
            if let undoManager = uiView.undoManager, undoManager.canRedo {
                undoManager.redo()
                print("Redo performed.")
            }
            DispatchQueue.main.async {
                redoTapped = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        print("makeCoordinator çağrıldı")
        return Coordinator(self)
    }
    
    // MARK: - Critical Fix: Coordinator Implementation
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasView
        
        init(_ parent: CanvasView) {
            self.parent = parent
            super.init()
            print("Coordinator initialized")
        }
        
        // MARK: - Critical Fix: Stroke End Delegate
        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            print("canvasViewDidEndUsingTool çağrıldı")
            notifyStrokeEnd(canvasView)
        }
        
        func canvasViewDidFinishRendering(_ canvasView: PKCanvasView) {
            print("canvasViewDidFinishRendering çağrıldı")
        }
        
        // Bu metod her stroke bittiğinde çağrılacak
        func canvasViewDidEndStroke(_ canvasView: PKCanvasView) {
            print("canvasViewDidEndStroke çağrıldı!")
            notifyStrokeEnd(canvasView)
        }
        
        // Stroke bittiğini bildiren yardımcı metod
        private func notifyStrokeEnd(_ canvasView: PKCanvasView) {
            print("notifyStrokeEnd çağrıldı - onEndStroke closure'ı çağırılıyor")
            DispatchQueue.main.async {
                self.parent.onEndStroke(canvasView.drawing)
            }
        }
    }
}


    
struct PageIndicatorView: View {
    @Binding var page: Page?
    var pages: FetchedResults<Page>
    let note: Note
    var canvasView: PKCanvasView // Çizim verilerini kaydetmek için
    
    @State private var showingPageInput = false
    @State private var inputPageNumber = ""
    @Environment(\.managedObjectContext) private var viewContext
    
    var currentPageIndex: Int {
        guard let page = page else { return 0 }
        return pages.firstIndex(of: page) ?? 0
    }
    
    var totalPages: Int {
        pages.count
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Mevcut sayfa numarası (tıklanabilir)
            Text("\(currentPageIndex + 1)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(.ultraThinMaterial))
                .onTapGesture {
                    showingPageInput = true
                    inputPageNumber = "\(currentPageIndex + 1)"
                }
                .alert("Go to Page", isPresented: $showingPageInput) {
                    TextField("Page number", text: $inputPageNumber)
                        .keyboardType(.numberPad)
                    Button("Cancel", role: .cancel) { }
                    Button("Go") {
                        goToPage()
                    }
                }
            
            // Toplam sayfa sayısı
            Text("\(totalPages)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
    }
    
    private func goToPage() {
        guard let pageNumber = Int(inputPageNumber),
              pageNumber > 0,
              pageNumber <= totalPages else { return }
        
        let targetIndex = pageNumber - 1
        if targetIndex < pages.count {
            // Mevcut sayfayı kaydet
            if let currentPage = page {
                saveDrawingData(for: currentPage)
            }
            // Yeni sayfaya geç
            page = pages[targetIndex]
        }
    }
    
    // Çizim verilerini kaydetme fonksiyonu
    private func saveDrawingData(for pageToSave: Page) {
        // Çizimin gerçekten değişip değişmediğini kontrol et
        let currentDrawingData = canvasView.drawing.dataRepresentation()
        print("Attempting to save drawing for page \(pageToSave.pageIndex). Current data size: \(currentDrawingData.count)")
        
        pageToSave.drawingData = currentDrawingData
        
        do {
            // Sayfa değişmeden önce kaydın tamamlanmasını sağlamak için performAndWait kullan
            try viewContext.performAndWait {
                if viewContext.hasChanges {
                    try viewContext.save()
                    print("Successfully saved drawing for page \(pageToSave.pageIndex).")
                } else {
                    print("View context has no changes to save for drawing on page \(pageToSave.pageIndex).")
                }
            }
        } catch {
            print("Error saving drawing data for page \(pageToSave.pageIndex): \(error.localizedDescription)")
            // Kullanıcıya hata mesajı göstermek için bir alert ekleyebilirsiniz
        }
    }
}

// MARK: - Audio Player Bar Component

struct AudioPlayerBar: View {
    @Binding var isPlaying: Bool
    @Binding var progress: Double
    @Binding var currentTime: Double
    @Binding var totalDuration: Double
    @Binding var isDragging: Bool
    
    let currentRecording: Recording?
    let onPlayPause: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onSeek: (Double) -> Void
    let onSkipBackward: () -> Void
    let onSkipForward: () -> Void
    
    // MARK: - View Control
        @Binding var isPlayerVisible: Bool
    var body: some View {
        if isPlayerVisible {
            VStack(spacing: 0) {
                // Close Button
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPlayerVisible = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(.black.opacity(0.3))
                            )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                // Main Content
                VStack(spacing: 10) {
                    // Title and Time
                    VStack(spacing: 4) {
                        

                        Text(timeDisplay)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 12)

                    // Progress Slider
                    VStack(spacing: 6) {
                        Slider(value: Binding(
                            get: { progress },
                            set: { newValue in
                                let seekTime = newValue * totalDuration
                                onSeek(seekTime)

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    // isDragging = false
                                }
                            }
                        ), in: 0...1)
                        .accentColor(.white)
                        .padding(.horizontal, 12)
                    }

                    // Control Buttons
                    HStack(spacing: 20) {
                        Button(action: onPrevious) {
                            Image(systemName: "backward.end.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                        }

                        Button(action: onSkipBackward) {
                            Image(systemName: "gobackward.10")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                        }

                        Button(action: onPlayPause) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }

                        Button(action: onSkipForward) {
                            Image(systemName: "goforward.10")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                        }

                        Button(action: onNext) {
                            Image(systemName: "forward.end.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .frame(width: 280, height: 120) // Adjusted height from 160 to 120
            .background(
                // Glassmorphism effect
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .black.opacity(0.2),
                                        .black.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .scale(scale: 0.8).combined(with: .opacity)
            ))
        }
    }
    
    private var recordingTitle: String {
        if let recording = currentRecording {
            return ""
        }
        return ""
    }
    
    private var timeDisplay: String {
        let current = formatTime(currentTime)
        let total = formatTime(totalDuration)
        return "\(current) / \(total)"
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Recording Row Component

struct RecordingRowView: View {
    let recording: Recording
    let isCurrentlyPlaying: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: isCurrentlyPlaying ? "speaker.wave.2.fill" : "waveform")
                    .foregroundColor(isCurrentlyPlaying ? .blue : .secondary)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ses Kaydı")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let createdAt = recording.createdAt {
                        Text(DateFormatter.localizedString(from: createdAt, dateStyle: .short, timeStyle: .short))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isCurrentlyPlaying {
                    Image(systemName: "play.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrentlyPlaying ? Color.blue.opacity(0.1) : Color.clear)
                    .stroke(isCurrentlyPlaying ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
// Apple Pencil algılayıcı UIView
struct PencilDetectorView: UIViewRepresentable {
    let onPencilStatusChange: (Bool) -> Void
    
    func makeUIView(context: Context) -> PencilDetectorUIView {
        return PencilDetectorUIView(onPencilStatusChange: onPencilStatusChange)
    }
    
    func updateUIView(_ uiView: PencilDetectorUIView, context: Context) {}
}

class PencilDetectorUIView: UIView {
    let onPencilStatusChange: (Bool) -> Void
    
    init(onPencilStatusChange: @escaping (Bool) -> Void) {
        self.onPencilStatusChange = onPencilStatusChange
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        if let touch = touches.first {
            let isPencil = touch.type == .pencil || touch.type == .stylus
            onPencilStatusChange(isPencil)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        onPencilStatusChange(false)
    }
}
