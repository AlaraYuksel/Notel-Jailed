//
//  AddNoteView.swift
//  Notel
//
//  Created by Alara yüksel on 30.03.2025.
import SwiftUI

struct AddNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var noteTitle: String = "Yeni Not"
    @State private var selectedTopic: Topic?
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Topic.title, ascending: true)],
        animation: .default)
    private var topics: FetchedResults<Topic>
    
    var onNoteCreated: ((Note) -> Void)?
    
    var body: some View {
        NavigationView {
            Form {
                // Not başlık bölümü
                Section(header: Text("Not Detayları")) {
                    TextField("Not Başlığı", text: $noteTitle)
                }
                
                // Topic seçim bölümü
                Section(header: Text("Topic Seçimi")) {
                    topicSelectionView
                }
            }
            .navigationTitle("Yeni Not")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        addNote()
                    }
                    .disabled(isFormInvalid)
                }
            }
        }
    }
    
    // Form geçerlilik kontrolü
    private var isFormInvalid: Bool {
        return noteTitle.trimmingCharacters(in: .whitespaces).isEmpty || selectedTopic == nil
    }
    
    // Topic seçim görünümü
    private var topicSelectionView: some View {
        Group {
            if topics.isEmpty {
                Text("Hiç topic bulunamadı. Önce topic oluşturun.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(topics, id: \.self) { topic in
                    TopicRowView(topic: topic, isSelected: selectedTopic == topic)
                        .onTapGesture {
                            selectedTopic = topic
                        }
                }
            }
        }
    }
    
    private func addNote() {
        let newNote = Note(context: viewContext)
        newNote.id = UUID()
        newNote.title = noteTitle
        newNote.createdAt = Date()
        newNote.topic = selectedTopic
        
        let newPage = Page(context: viewContext)
        newPage.id = UUID()
        newPage.pageIndex = 0
        newPage.note = newNote
        
        do {
            try viewContext.save()
            onNoteCreated?(newNote)
            dismiss()
        } catch {
            print("Not eklenemedi: \(error.localizedDescription)")
        }
    }
}

// Topic satırı için ayrı bir view
struct TopicRowView: View {
    let topic: Topic
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Text(topic.title ?? "İsimsiz Topic")
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
    }
}
