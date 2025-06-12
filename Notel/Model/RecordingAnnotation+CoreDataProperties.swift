//
//  RecordingAnnotation+CoreDataProperties.swift
//  Notel
//
//  Created by Alara yüksel on 28.03.2025.
//
//

import Foundation
import CoreData


extension RecordingAnnotation {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecordingAnnotation> {
        return NSFetchRequest<RecordingAnnotation>(entityName: "RecordingAnnotation")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Float
    @NSManaged public var recording: Recording?
    @NSManaged public var attachment: Attachment?

}

extension RecordingAnnotation : Identifiable {

}
