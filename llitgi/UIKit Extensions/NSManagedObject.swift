//
//  NSManagedObject.swift
//  llitgi
//
//  Created by Xavi Moll on 28/12/2017.
//  Copyright © 2017 xmollv. All rights reserved.
//

import Foundation
import CoreData

extension NSManagedObject {
    
    static func fetch<T: Managed>(with identifier: String, format: String, in context: NSManagedObjectContext) -> T? {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: T.self))
        request.predicate = NSPredicate(format: format, argumentArray: [identifier])
        var fetchedElement: T?
        context.performAndWait {
            do {
                let fetchedElements = try context.fetch(request) as? [T]
                fetchedElement = fetchedElements?.first
            } catch {
                Logger.log(error.localizedDescription, event: .error)
            }
        }
        return fetchedElement
    }
    
    static func create<T: Managed>(in context: NSManagedObjectContext) -> T? {
        guard let entity = NSEntityDescription.entity(forEntityName: String(describing: T.self), in: context) else {
            Logger.log("Invalid Core Data configuration", event: .error)
            return nil
        }
        var object: T?
        context.performAndWait {
            object = T.init(entity: entity, insertInto: context)
        }
        return object
    }
    
    /// Grabs the value of the key stored in Core Data using a performAndWait block
    func read<T>(key: String) -> T? {
        var response: T? = nil
        self.managedObjectContext?.performAndWait {
            response = self.value(forKey: key) as? T
        }
        return response
    }
    
    /// Updates (or sets) the value of the key stored in Core Data using a performAndWait block
    func update<T>(key: String, with value: T?) {
        self.managedObjectContext?.performAndWait {
            self.setValue(value, forKey: key)
        }
    }
    
}
