import CoreData
import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // Topic'leri fetch et, başlığa göre sırala
    // Bu hala konu listesini göstermek için gerekli.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Topic.title, ascending: true)],
        animation: .default
    ) private var topics: FetchedResults<Topic>

    // TÜM Notları fetch et, createdAt'a göre sırala
    // Konusuz notları ve filtreleme için tüm notlara erişim sağlamak için
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)], // En son oluşturulan üstte
        animation: .default
    ) private var allNotes: FetchedResults<Note> // TÜM notları çekiyoruz

    @State private var searchText = ""
    // @State private var isShowingAddNote = false // Bu artık kullanılmıyor gibi görünüyor
    @State private var selectedNoteForDetail: Note? // Detay görünümü için

    // Başlık düzenleme için state değişkenleri (Note için)
    @State private var isShowingRenameAlert = false
    @State private var noteToRename: Note?
    @State private var newNoteTitle = ""

    // YENİ: Yeni konu ekleme ekranını yönetmek için ve yeni note ekleme için
    @State private var isShowingAddTopicView = false
    @State private var isShowingAddNoteView = false
    // MARK: - Computed Properties for Filtering and Grouping

    // ... (Mevcut computed properties)

    // Konusu olmayan ve arama metnine göre filtrelenmiş notlar
    private var unfiledNotes: [Note] {
        let notesWithoutTopic = allNotes.filter { $0.topic == nil }
        if searchText.isEmpty {
            return notesWithoutTopic
        } else {
            return notesWithoutTopic.filter { note in
                // Sadece not başlığına göre filtrele
                note.title?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
    }

    // Arama metnine göre filtrelenmiş konular
    // Bu filtrelenmiş konular, sadece başlığı eşleşen veya içinde başlığı eşleşen not olan konuları içerir.
    private var filteredTopics: [Topic] {
        if searchText.isEmpty {
            return topics.map { $0 } // Arama yoksa tüm konular
        } else {
            return topics.filter { topic in
                // Konunun başlığı eşleşiyorsa VEYA
                let topicTitleMatch = topic.title?.localizedCaseInsensitiveContains(searchText) ?? false
                // konu içindeki notlardan en az birinin BAŞLIĞI arama metniyle eşleşiyorsa
                let noteTitleMatch = (topic.notes as? Set<Note> ?? []).contains { note in
                    note.title?.localizedCaseInsensitiveContains(searchText) ?? false
                }
                return topicTitleMatch || noteTitleMatch
            }
        }
    }

    // Belirli bir konu için notları createdAt'a göre sıralayan yardımcı fonksiyon
    private func sortedNotes(for topic: Topic) -> [Note] {
        let notesSet = topic.notes as? Set<Note> ?? []
        return notesSet.sorted {
            ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast)
        }
    }

    // Belirli bir konu için notları sıralayan VE arama metnine göre filtreleyen fonksiyon
    // Bu sadece konu bölümlerinin içindeki notları filtrelemek için kullanılır.
    private func sortedAndFilteredNotes(for topic: Topic) -> [Note] {
        let notes = sortedNotes(for: topic)
        if searchText.isEmpty {
            return notes // Arama yoksa tüm sıralı notlar
        } else {
            // Sadece not başlığına göre filtrele
            return notes.filter { note in
                note.title?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
    }


    // Varsayılan Topic (eğer Topic atanmamışsa veya ekleme sırasında)
    private var defaultTopic: Topic {
        // "Genel" adında bir topic bul veya oluştur
        let request: NSFetchRequest<Topic> = Topic.fetchRequest()
        request.predicate = NSPredicate(format: "title == %@", "Genel")

        do {
            let results = try viewContext.fetch(request)
            if let existingTopic = results.first {
                return existingTopic
            } else {
                // Eğer yoksa oluştur
                let newTopic = Topic(context: viewContext)
                newTopic.title = "Genel"
                // Değişiklikleri hemen kaydetmek genellikle daha iyidir
                // Hata kontrolü eklenebilir
                try viewContext.save() // Hata yakalama bloğunda olduğu için bu kaydetme de yakalanır
                print("'Genel' adlı varsayılan konu oluşturuldu.")
                return newTopic
            }
        } catch {
            print("Varsayılan konu bulunamadı veya oluşturulamadı: \(error)")
            // Hata durumunda kullanıcıya bilgi verebilir veya uygulamayı durdurabilirsiniz.
            // Geçici bir nesne oluşturmak yerine, fatalError Core Data hatasını daha açık hale getirebilir.
            fatalError("Varsayılan 'Genel' konu oluşturulamadı veya getirilemedi: \(error.localizedDescription)")
        }
    }


    var body: some View {
        NavigationView {
            List {
                // **MARK: - Konulu Notlar**
                
                // Arama metnine göre filtrelenmiş konuları göster
                ForEach(filteredTopics) { topic in
                    let filteredNotesForTopic = sortedAndFilteredNotes(for: topic)
                    
                    // Arama yoksa veya konu başlığı eşleşiyorsa veya konuda filtreye uyan not varsa göster
                    if searchText.isEmpty || (topic.title?.localizedCaseInsensitiveContains(searchText) ?? false) || !filteredNotesForTopic.isEmpty {
                        
                        DisclosureGroup(
                            content: {
                                // Konuya ait, arama metnine göre filtrelenmiş notları göster
                                ForEach(filteredNotesForTopic) { note in
                                    NavigationLink(destination: NoteDetailView(note: note), tag: note, selection: $selectedNoteForDetail) {
                                        HStack {
                                            Image(systemName: "doc.text")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                            Text(note.title ?? "Başlıksız Not")
                                            Spacer()
                                        }
                                        .padding(.leading, 8)
                                    }
                                    .onLongPressGesture {
                                        noteToRename = note
                                        newNoteTitle = note.title ?? ""
                                        isShowingRenameAlert = true
                                    }
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            deleteNote(note)
                                        } label: {
                                            Label("Sil", systemImage: "trash")
                                        }
                                        // İleride buraya "Taşı" gibi başka eylemler eklenebilir
                                    }
                                }
                            },
                            label: {
                                HStack {
                                    Image(systemName: "folder")
                                        .foregroundColor(.blue)
                                    Text(topic.title ?? "Başlıksız Konu")
                                        .font(.headline)
                                    Spacer()
                                    // Not sayısını göster
                                    Text("\(filteredNotesForTopic.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                        )
                        .tint(.primary) // DisclosureGroup ok rengini ayarlar
                    }
                }

                // **MARK: - Dosyalanmamış Notlar**
                
                // Konusu olmayan ve arama metnine göre filtrelenmiş notlar varsa bu bölümü göster
                if !unfiledNotes.isEmpty {
                    DisclosureGroup(
                        content: {
                            ForEach(unfiledNotes) { note in
                                NavigationLink(destination: NoteDetailView(note: note), tag: note, selection: $selectedNoteForDetail) {
                                    HStack {
                                        Image(systemName: "doc.text")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                        Text(note.title ?? "Başlıksız Not")
                                        Spacer()
                                    }
                                    .padding(.leading, 8)
                                }
                                .onLongPressGesture {
                                    noteToRename = note
                                    newNoteTitle = note.title ?? ""
                                    isShowingRenameAlert = true
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        deleteNote(note)
                                    } label: {
                                        Label("Sil", systemImage: "trash")
                                    }
                                    // İleride buraya "Taşı" gibi başka eylemler eklenebilir
                                }
                            }
                        },
                        label: {
                            HStack {
                                Image(systemName: "tray")
                                    .foregroundColor(.orange)
                                Text("Dosyalanmamış Notlar")
                                    .font(.headline)
                                Spacer()
                                // Not sayısını göster
                                Text("\(unfiledNotes.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    )
                    .tint(.primary)
                }
            }
            .navigationTitle("Notlar") // Başlığı biraz daha genel yapabiliriz
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: openSettings) {
                        Image(systemName: "gear")
                    }
                }
                // YENİ: Yeni Konu Ekleme Butonu
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingAddTopicView = true // Yeni konu ekleme ekranını aç
                    }) {
                        Image(systemName: "folder.badge.plus") // Konu eklemek için farklı bir ikon kullanabiliriz
                    }
                }
                // Yeni not ekleme butonu (Mevcut olan)
                ToolbarItem(placement: .navigationBarTrailing) {
                   Button(action: {
                       isShowingAddNoteView = true // AddNoteView'ı göster
                   }) {
                       Image(systemName: "square.and.pencil")
                   }
                }
            }
            // Arama çubuğunu sadece başlıklar için ayarla
            .searchable(text: $searchText, prompt: "Konu veya Not Başlığında Ara")
            .alert("Notu Yeniden Adlandır", isPresented: $isShowingRenameAlert, actions: {
                TextField("Yeni Başlık", text: $newNoteTitle)
                Button("İptal", role: .cancel) { resetRenameState() }
                Button("Yeniden Adlandır") { renameNote() }
            }, message: {
                Text("Not için yeni bir başlık girin.")
            })
            // YENİ: Yeni Konu Ekleme Ekranını Sun
            .sheet(isPresented: $isShowingAddTopicView) {
                AddTopicView().environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $isShowingAddNoteView) {
                AddNoteView(onNoteCreated: { newNote in
                    // Yeni not oluşturulduğunda yapılacak işlemler
                    selectedNoteForDetail = newNote // Yeni oluşturulan notu seçerek detay görünümünü aç
                }).environment(\.managedObjectContext, viewContext)
            }


            // iPad ve geniş ekranlar için varsayılan görünüm
            Text("Bir konu veya not seçin")
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Core Data Actions
    
    // ... (addNewNoteToTopic, deleteNote, renameNote, resetRenameState fonksiyonları)

    private func addNewNoteToTopic(_ topic: Topic) {
        let newNote = Note(context: viewContext)
        newNote.id = UUID()
        newNote.title = "Yeni Not"
        newNote.createdAt = Date()
        newNote.topic = topic // Belirtilen konuya ata

        // İlk sayfayı hemen oluştur
        let newPage = Page(context: viewContext)
        newPage.id = UUID()
        newPage.pageIndex = 0 // İlk sayfa
        newPage.note = newNote // Not ile ilişkilendir

        do {
            try viewContext.save()
            selectedNoteForDetail = newNote // Yeni oluşturulan notu seçerek detay görünümünü aç
        } catch {
            print("Hata: Yeni not kaydedilemedi. \(error.localizedDescription)")
            viewContext.rollback()
        }
    }


    private func deleteNote(_ note: Note) {
        // Notu silmeden önce, eğer seçili not bu not ise seçimi kaldır
        if selectedNoteForDetail == note {
            selectedNoteForDetail = nil
        }

        viewContext.delete(note)
        do {
            try viewContext.save()
        } catch {
            print("Hata: Not silinemedi. \(error.localizedDescription)")
            viewContext.rollback()
        }
    }

    private func renameNote() {
        guard let note = noteToRename else { return }
        let trimmedTitle = newNoteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        note.title = trimmedTitle.isEmpty ? "Başlıksız Not" : trimmedTitle

        do {
            try viewContext.save()
        } catch {
            print("Hata: Not yeniden adlandırılamadı. \(error.localizedDescription)")
            viewContext.rollback()
        }
        resetRenameState()
    }

    private func resetRenameState() {
        noteToRename = nil
        newNoteTitle = ""
        isShowingRenameAlert = false
    }


    // MARK: - Other Actions (Değişiklik yok)

    private func openSettings() {
        print("Ayarlar açılacak.")
    }
}

// NoteDetailView ve NotePageView (varsa) - Bu kısımları olduğu gibi bırakabilirsiniz

struct NoteDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var note: Note // @ObservedObject kullanmak güncellemeleri yansıtabilir
    @State private var currentPage: Page? // Aktif sayfa

    var body: some View {
        VStack (){
            // Konu başlığını göstermek için (isteğe bağlı)
            if let topicTitle = note.topic?.title {
                Text("Konu: \(topicTitle)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 5)
            } else {
                Text("Dosyalanmamış Not") // Konusu yoksa belirt
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 5)
            }

            // Notun sayfalarını al, index'e göre sırala ve ilk sayfayı kullan
            if let pages = note.pages as? Set<Page>,
               let firstPage = pages.sorted(by: { $0.pageIndex < $1.pageIndex }).first {

                // NotePageView sayfalar arasında gezinme ve içeriği düzenleme mantığını içermeli
                // currentPage state'i NotePageView içinde değiştirilebilir ve değişiklikler Core Data'ya kaydedilebilir
                NotePageView(page: $currentPage, note: note) // $currentPage'i NotePageView'a binding olarak gönderiyoruz
                    .onAppear {
                        // Eğer currentPage zaten ayarlanmamışsa ilk sayfayı ayarla
                        if currentPage == nil {
                            currentPage = firstPage
                        }
                    }
                    // onDisappear içinde kaydetme yapmak, uygulamanın kapanması gibi durumlarda
                    // değişikliklerin kaybolmamasını sağlar. Ancak, real-time düzenleme sırasında
                    // periyodik kaydetme veya her değişiklikte kaydetme (performans riskli)
                    // NotePageView içinde yapılmalıdır.
                    .onDisappear {
                        saveContext() // Görünüm kaybolduğunda kaydet
                    }

            } else {
                // Eğer hiç sayfa yoksa ve görünüm açıldıysa yeni sayfa ekle
                Text("Sayfa oluşturuluyor...")
                    .onAppear {
                        addNewPageIfNeeded()
                    }
            }
            Spacer() // İçeriği üste hizala
        }
        .navigationTitle(note.title ?? "Başlıksız Not")
        // .id(note.objectID) // Başlığın anında güncellenmesi için gerekebilir
        .onAppear {
             // Görünüm açıldığında ilk sayfayı ayarlamak daha güvenilir olabilir
             setupInitialPage()
        }
    }

     // Eğer notun hiç sayfası yoksa ilk sayfayı ekler
    private func addNewPageIfNeeded() {
        guard let pages = note.pages, pages.count == 0 else { return }

        let newPage = Page(context: viewContext)
        newPage.id = UUID()
        newPage.pageIndex = 0 // İlk sayfa
        newPage.note = note // Not ile ilişkilendir

        do {
            try viewContext.save()
            currentPage = newPage // Yeni eklenen sayfayı aktif sayfa yap
            print("Yeni ilk sayfa oluşturuldu ve atandı.")
        } catch {
            print("Yeni sayfa eklenemedi: \(error.localizedDescription)")
            viewContext.rollback()
        }
    }

    // Görünüm ilk açıldığında veya note değiştiğinde ilk sayfayı ayarlar
    private func setupInitialPage() {
        if let pages = note.pages as? Set<Page>,
            let firstPage = pages.sorted(by: { $0.pageIndex < $1.pageIndex }).first {
             // Eğer notun sayfaları varsa ve currentPage henüz bu notun ilk sayfası değilse
             // veya nil ise, currentPage'i ilk sayfaya ayarla.
             if currentPage?.note != note || currentPage == nil || currentPage?.pageIndex != firstPage.pageIndex {
                 currentPage = firstPage
                 print("İlk sayfa setupInitialPage içinde ayarlandı.")
             }
        } else {
             // Eğer hiç sayfa yoksa, bir tane eklemeyi dene
             addNewPageIfNeeded()
        }
    }


    // Değişiklikleri kaydetmek için yardımcı fonksiyon
    private func saveContext() {
        do {
            if viewContext.hasChanges {
                try viewContext.save()
                print("Değişiklikler kaydedildi.")
            }
        } catch {
            print("Kaydetme hatası: \(error.localizedDescription)")
            viewContext.rollback()
        }
    }
}

import SwiftUI
import CoreData

struct AddTopicView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss // Ekranı kapatmak için

    @State private var newTopicTitle = ""

    var body: some View {
        NavigationView { // Eğer büyük ekranlarda sunulacaksa veya title isteniyorsa
            VStack {
                TextField("Yeni Konu Adı", text: $newTopicTitle)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)

                Button("Konu Ekle") {
                    addTopic()
                }
                .padding()
                .disabled(newTopicTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) // Boş başlık eklemeyi engelle

                Spacer() // İçeriği üste hizala
            }
            .navigationTitle("Yeni Konu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") {
                        dismiss() // Ekranı kapat
                    }
                }
            }
        }
    }

    private func addTopic() {
        let trimmedTitle = newTopicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let newTopic = Topic(context: viewContext)
        newTopic.id = UUID()
        newTopic.title = trimmedTitle
        // createdAt gibi diğer özellikleri de ekleyebilirsiniz

        do {
            try viewContext.save()
            print("Yeni konu kaydedildi: \(newTopic.title ?? "Başlıksız")")
            dismiss() // Başarıyla kaydedildikten sonra ekranı kapat
        } catch {
            print("Hata: Yeni konu kaydedilemedi. \(error.localizedDescription)")
            // Kullanıcıya bir hata mesajı gösterebilirsiniz
            viewContext.rollback() // Hata durumunda yapılan değişiklikleri geri al
        }
    }
}

