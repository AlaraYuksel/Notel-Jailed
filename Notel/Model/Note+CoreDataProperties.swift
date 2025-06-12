//
//  Note+CoreDataProperties.swift
//  Notel
//
//  Created by Alara yüksel on 4.05.2025.
//
//

import Foundation
import CoreData


extension Note {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Note> {
        return NSFetchRequest<Note>(entityName: "Note")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var pages: NSSet?
    @NSManaged public var pdffiles: NSSet?
    @NSManaged public var recordings: NSSet?
    @NSManaged public var topic: Topic?

}

// MARK: Generated accessors for pages
extension Note {

    @objc(addPagesObject:)
    @NSManaged public func addToPages(_ value: Page)

    @objc(removePagesObject:)
    @NSManaged public func removeFromPages(_ value: Page)

    @objc(addPages:)
    @NSManaged public func addToPages(_ values: NSSet)

    @objc(removePages:)
    @NSManaged public func removeFromPages(_ values: NSSet)

}

// MARK: Generated accessors for pdffiles
extension Note {

    @objc(addPdffilesObject:)
    @NSManaged public func addToPdffiles(_ value: PDFFile)

    @objc(removePdffilesObject:)
    @NSManaged public func removeFromPdffiles(_ value: PDFFile)

    @objc(addPdffiles:)
    @NSManaged public func addToPdffiles(_ values: NSSet)

    @objc(removePdffiles:)
    @NSManaged public func removeFromPdffiles(_ values: NSSet)

}

// MARK: Generated accessors for recordings
extension Note {

    @objc(addRecordingsObject:)
    @NSManaged public func addToRecordings(_ value: Recording)

    @objc(removeRecordingsObject:)
    @NSManaged public func removeFromRecordings(_ value: Recording)

    @objc(addRecordings:)
    @NSManaged public func addToRecordings(_ values: NSSet)

    @objc(removeRecordings:)
    @NSManaged public func removeFromRecordings(_ values: NSSet)

}

extension Note : Identifiable {
    // İlk sayfanın içeriğini (varsa) döndürür
    var firstPagePreview: String {
        guard let firstPage = sortedPages.first else {
            return "İçerik yok" // Veya boş string ""
        }
        // Page varlığınızda içeriği tutan attribute'un adı 'content' varsayımıyla:
        // return firstPage.content ?? "İçerik yok"
        // Eğer Page içeriği farklı bir yapıda (örn. çizim verisi) ise,
        // burayı uygun bir metin temsili döndürecek şekilde güncellemeniz gerekir.
        // Şimdilik varsayılan bir metin döndürelim:
         return "Sayfa \(firstPage.pageIndex + 1) içeriği..." // Gerçek içeriği buraya ekleyin
    }

    // sortedPages zaten vardı, onu kullanıyoruz.
    var sortedPages: [Page] {
        (pages as? Set<Page>)?.sorted(by: { $0.pageIndex < $1.pageIndex }) ?? []
    }

}
