//
//  PDFFile+CoreDataProperties.swift
//  Notel
//
//  Created by Alara yüksel on 28.03.2025.
//
//

import Foundation
import CoreData


extension PDFFile {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PDFFile> {
        return NSFetchRequest<PDFFile>(entityName: "PDFFile")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var fileName: String?
    @NSManaged public var fileData: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var note: Note?

}

extension PDFFile : Identifiable {

}
