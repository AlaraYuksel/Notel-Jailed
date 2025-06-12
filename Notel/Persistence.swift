import CoreData
import SwiftUI

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentCloudKitContainer

    private init() {
        container = NSPersistentCloudKitContainer(name: "Notel") // Core Data model adı burada belirtilmeli
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }

    // MARK: - Save Context
    private func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    // MARK: - CRUD for Note

    func addNote(title: String) -> Note {
        let context = container.viewContext
        let newNote = Note(context: context)
        newNote.title = title
        newNote.createdAt = Date()
        newNote.updatedAt = Date()
        saveContext()
        return newNote
    }

    func fetchNotes() -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Error fetching notes: \(error)")
            return []
        }
    }

    func updateNote(_ note: Note, newTitle: String?) {
        note.title = newTitle ?? note.title
        note.updatedAt = Date()
        saveContext()
    }

    func deleteNote(_ note: Note) {
        container.viewContext.delete(note)
        saveContext()
    }

    // MARK: - CRUD for Page

    func addPage(to note: Note, pageIndex: Int16, type: String) -> Page {
        let context = container.viewContext
        let newPage = Page(context: context)
        newPage.pageIndex = pageIndex
        newPage.type = type
        newPage.note = note
        newPage.drawingData = Data()
        saveContext()
        return newPage
    }

    func fetchPages(for note: Note) -> [Page] {
        let request: NSFetchRequest<Page> = Page.fetchRequest()
        request.predicate = NSPredicate(format: "note == %@", note)
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Error fetching pages: \(error)")
            return []
        }
    }

    func deletePage(_ page: Page) {
        container.viewContext.delete(page)
        saveContext()
    }

    // MARK: - CRUD for PDFFile

    func addPDFFile(to note: Note, fileName: String, fileData: Data) -> PDFFile {
        let context = container.viewContext
        let pdfFile = PDFFile(context: context)
        pdfFile.fileName = fileName
        pdfFile.fileData = fileData
        pdfFile.note = note
        saveContext()
        return pdfFile
    }

    func fetchPDFFiles(for note: Note) -> [PDFFile] {
        let request: NSFetchRequest<PDFFile> = PDFFile.fetchRequest()
        request.predicate = NSPredicate(format: "note == %@", note)
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Error fetching PDF files: \(error)")
            return []
        }
    }

    func deletePDFFile(_ pdfFile: PDFFile) {
        container.viewContext.delete(pdfFile)
        saveContext()
    }

    // MARK: - CRUD for Attachment

    func addAttachment(to note: Page, type: String, fileData: Data?) -> Attachment {
        let context = container.viewContext
        let attachment = Attachment(context: context)
        attachment.type = type
        attachment.fileData = fileData
        attachment.page = note
        saveContext()
        return attachment
    }

    func fetchAttachments(for note: Note) -> [Attachment] {
        let request: NSFetchRequest<Attachment> = Attachment.fetchRequest()
        request.predicate = NSPredicate(format: "note == %@", note)
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Error fetching attachments: \(error)")
            return []
        }
    }

    func deleteAttachment(_ attachment: Attachment) {
        container.viewContext.delete(attachment)
        saveContext()
    }

    // MARK: - CRUD for Recording

    func addRecording(to note: Note, fileData: Data, duration: Float) -> Recording {
        let context = container.viewContext
        let recording = Recording(context: context)
        recording.fileData = fileData
        recording.duration = duration
        recording.note = note
        saveContext()
        return recording
    }

    func fetchRecordings(for note: Note) -> [Recording] {
        let request: NSFetchRequest<Recording> = Recording.fetchRequest()
        request.predicate = NSPredicate(format: "note == %@", note)
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Error fetching recordings: \(error)")
            return []
        }
    }

    func deleteRecording(_ recording: Recording) {
        container.viewContext.delete(recording)
        saveContext()
    }

    // MARK: - CRUD for RecordingAnnotation

    func addRecordingAnnotation(to recording: Recording, timestamp: Float) -> RecordingAnnotation {
        let context = container.viewContext
        let annotation = RecordingAnnotation(context: context)
        annotation.timestamp = timestamp
        annotation.recording = recording
        saveContext()
        return annotation
    }

    func fetchRecordingAnnotations(for recording: Recording) -> [RecordingAnnotation] {
        let request: NSFetchRequest<RecordingAnnotation> = RecordingAnnotation.fetchRequest()
        request.predicate = NSPredicate(format: "recording == %@", recording)
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Error fetching recording annotations: \(error)")
            return []
        }
    }

    func deleteRecordingAnnotation(_ annotation: RecordingAnnotation) {
        container.viewContext.delete(annotation)
        saveContext()
    }
}
