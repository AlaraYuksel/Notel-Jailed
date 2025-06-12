//
//  Page+CoreDataProperties.swift
//  Notel
//
//  Created by Alara yüksel on 7.05.2025.
//
//

import Foundation
import CoreData


extension Page {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Page> {
        return NSFetchRequest<Page>(entityName: "Page")
    }

    @NSManaged public var drawingData: Data?
    @NSManaged public var id: UUID?
    @NSManaged public var pageIndex: Int16
    @NSManaged public var pdfPageNumber: Int16
    @NSManaged public var type: String?
    @NSManaged public var pdfFile: Data?
    @NSManaged public var attachments: NSSet?
    @NSManaged public var note: Note?

}

// MARK: Generated accessors for attachments
extension Page {

    @objc(addAttachmentsObject:)
    @NSManaged public func addToAttachments(_ value: Attachment)

    @objc(removeAttachmentsObject:)
    @NSManaged public func removeFromAttachments(_ value: Attachment)

    @objc(addAttachments:)
    @NSManaged public func addToAttachments(_ values: NSSet)

    @objc(removeAttachments:)
    @NSManaged public func removeFromAttachments(_ values: NSSet)

}

extension Page : Identifiable {

}
