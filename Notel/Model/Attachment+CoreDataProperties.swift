//
//  Attachment+CoreDataProperties.swift
//  Notel
//
//  Created by Alara yüksel on 28.03.2025.
//
//

import Foundation
import CoreData


extension Attachment {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Attachment> {
        return NSFetchRequest<Attachment>(entityName: "Attachment")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var type: String?
    @NSManaged public var fileData: Data?
    @NSManaged public var extraData: String?
    @NSManaged public var positionX: Float
    @NSManaged public var positionY: Float
    @NSManaged public var width: Float
    @NSManaged public var height: Float

    @NSManaged public var noteAnnotation: RecordingAnnotation?
    @NSManaged public var page: Page?

}

extension Attachment : Identifiable {

}
