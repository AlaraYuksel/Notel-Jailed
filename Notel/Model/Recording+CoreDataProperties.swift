//
//  Recording+CoreDataProperties.swift
//  Notel
//
//  Created by Alara yüksel on 28.03.2025.
//
//

import Foundation
import CoreData


extension Recording {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Recording> {
        return NSFetchRequest<Recording>(entityName: "Recording")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var fileData: Data?
    @NSManaged public var duration: Float
    @NSManaged public var createdAt: Date?
    @NSManaged public var annotations: NSSet?
    @NSManaged public var note: Note?

}

// MARK: Generated accessors for annotations
extension Recording {

    @objc(addAnnotationsObject:)
    @NSManaged public func addToAnnotations(_ value: RecordingAnnotation)

    @objc(removeAnnotationsObject:)
    @NSManaged public func removeFromAnnotations(_ value: RecordingAnnotation)

    @objc(addAnnotations:)
    @NSManaged public func addToAnnotations(_ values: NSSet)

    @objc(removeAnnotations:)
    @NSManaged public func removeFromAnnotations(_ values: NSSet)

}

extension Recording : Identifiable {

}
