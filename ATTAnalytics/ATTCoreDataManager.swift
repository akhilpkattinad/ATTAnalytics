//
//  ATTCoreDataManager.swift
//  TrackingHelper
//
//  Created by Sreekanth R on 23/01/17.
//  Copyright © 2017 Sreekanth R. All rights reserved.
//

import UIKit
import CoreData

class ATTCoreDataManager: NSObject {
    var errorHandler: (Error) -> Void = {_ in }
    // WARNING!!!
    // MARK: - Core Data stack
    lazy var libraryDirectory: NSURL = {
        let urls = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
        return urls[urls.count-1] as NSURL
    }()
    /*
    // WARNING!!!
    // USE THE BELOW MANAGEDOBJECTMODEL FOR DEVELOPMENT PURPOSE ONLY - BEFORE CONVERTING TO FRAMEWORK
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL = Bundle.main.url(forResource: "ATTDB", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    */
    
    
     // MARK: - PersistentStoreCoordinator for below ios 10 support
     // WARNING!!!
     // USE THE BELOW MANAGEDOBJECTMODEL FOR PRODUCTION PURPOSE ONLY - AFTER CONVERTING TO FRAMEWORK
     
     lazy var managedObjectModel: NSManagedObjectModel = {
     let bundlePath = Bundle.main.path(forResource: "ATTBackends", ofType: "bundle")
     let bundle = Bundle(path: bundlePath!)
     let modelPath = bundle?.path(forResource:"ATTDB", ofType:"momd")
     let modelURL = URL(fileURLWithPath: modelPath!)
     return NSManagedObjectModel(contentsOf: modelURL)!
     }()
     
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel:self.managedObjectModel)
        let url = self.libraryDirectory.appendingPathComponent("ATTDB.sqlite")
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType,
                                               configurationName: nil,
                                               at: url,
                                               options: [NSMigratePersistentStoresAutomaticallyOption: true,
                                                         NSInferMappingModelAutomaticallyOption: true
                ]
            )
        } catch {
            // Report any error we got.
            print("CoreData error \(error), \(String(describing: error._userInfo))")
            self.errorHandler(error)
        }
        return coordinator
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        let coordinator = self.persistentStoreCoordinator
        var mainManagedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        mainManagedObjectContext.persistentStoreCoordinator = coordinator
        return mainManagedObjectContext
    }()
    /*
    // MARK: - Persistent container for above ios 10 support
    // ABOVE IOS 10
    /// THIS STACK IS ONLY BE USED FOR DEVELOPMENT PURPOSE BEFORE CONVERTING TO FRAMEWORK
    
    @available(iOS 10.0, *)
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ATTDB")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    */
    
    
     /// WARNING!!!
     /////////// REPLACE THE ABOVE CODE WITH THE BELOW GIVEN CODE WHEN CONVERTING TO FRAMEWORK/////
     ///// CREATE A BUNDLE TARGET AND ADD THE .XCDATAMODELLD FILE AS COMPILE SOURCE//////
     ///// HOST PROJECT MUST INCLUDE THE .BUNDLE ALSO///////
     
     
     // MARK: - Core Data stack
     @available(iOS 10.0, *)
     lazy var persistentContainer: NSPersistentContainer = {
     let container = NSPersistentContainer(name: "ATTDB", managedObjectModel: self.managedObjectModel)
     container.loadPersistentStores(completionHandler: { (storeDescription, error) in
     if let error = error as NSError? {
     fatalError("Unresolved error \(error), \(error.userInfo)")
     }
     })
     return container
     }()
    
    
    func currentContext() -> NSManagedObjectContext {
        var managedContext:NSManagedObjectContext!
        if #available(iOS 10.0, *) {
            managedContext = self.persistentContainer.viewContext
            
        } else {
            // Fallback on earlier versions
            managedContext = self.managedObjectContext
        }
        return managedContext
    }
    
    // MARK: Screen view methods
    func createScreenView(screenViewModel:ATTScreenViewModel?) -> Void {
        
        guard let screenViewModel = screenViewModel,let entity = NSEntityDescription.entity(forEntityName: "Screen", in: self.currentContext()) else {
            return
        }
        let newScreen = NSManagedObject(entity: entity, insertInto: self.currentContext())
        
        newScreen.setValue(screenViewModel.screenViewID,         forKeyPath: "screenViewID")
        newScreen.setValue(screenViewModel.previousScreenName,   forKeyPath: "previousScreen")
        newScreen.setValue(screenViewModel.previousScreenTitle,  forKeyPath: "previousScreenTitle")
        newScreen.setValue(screenViewModel.screenName,           forKeyPath: "presentScreen")
        newScreen.setValue(screenViewModel.screenTitle,          forKeyPath: "screenTitle")
        newScreen.setValue(screenViewModel.screeViewDuration,    forKeyPath: "screenWatchDuration")
        newScreen.setValue(screenViewModel.screenViewBeginTime,  forKeyPath: "screenWatchedTime")
        newScreen.setValue(screenViewModel.latitude,             forKeyPath: "latitude")
        newScreen.setValue(screenViewModel.longitude,            forKeyPath: "longitude")
        newScreen.setValue(false,                                 forKeyPath: "syncStatus")
        
        self.saveContext()
    }
    
    func updateScreenView(screenViewModel:ATTScreenViewModel) -> Void {
        
        guard let screenViewModelID = screenViewModel.screenViewID  else {
            return
        }
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Screen")
        fetchRequest.predicate = NSPredicate(format: "screenViewID = %@", screenViewModelID)
        
        do {
            let results = try self.currentContext().fetch(fetchRequest) as [AnyObject]
            if (results.count) > 0 {
                let managedObject = results[0]
                managedObject.setValue(screenViewModel.previousScreenName, forKey: "previousScreen")
                managedObject.setValue(screenViewModel.screeViewDuration, forKey: "screenWatchDuration")
                
                self.saveContext()
            }
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }
    func fetchAllEvents() -> [AnyObject]? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Events")
        do {
            let data:Array<AnyObject> = try self.currentContext().fetch(fetchRequest)
            return data
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
            return nil
        }
    }
    
    /// fetch all screens
    ///
    /// - Returns: array of screen models
    func fetchAllScreens() -> [AnyObject]? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Screen")
        do {
            let data:Array<AnyObject> = try self.currentContext().fetch(fetchRequest)
            return data
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
            return nil
        }
    }
    
    /// Fetch screen with screenID
    ///
    /// - Parameter screenID: screenID
    /// - Returns: array of event item
    func fetchScreenWithScreenID(screenID:String?) -> [AnyObject]? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Screen")
        fetchRequest.predicate = NSPredicate(format: "screenViewID = %@", screenID!)
        do {
            let data:Array<AnyObject> = try self.currentContext().fetch(fetchRequest)
            return data
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
            return nil
        }
    }
    
    
    /// Create events in DB
    ///
    /// - Parameter event: ATTEventModel instance
    func createEvents(event:ATTEventModel?) -> Void {
        
        guard let currentEvent = event,let entity = NSEntityDescription.entity(forEntityName: "Events",in: self.currentContext())  else {
            return
        }
        
        let newEvent = NSManagedObject(entity: entity, insertInto: self.currentContext())
        
        newEvent.setValue(currentEvent.screenViewID,   forKeyPath: "screenViewID")
        newEvent.setValue(currentEvent.eventType,      forKeyPath: "eventType")
        newEvent.setValue(currentEvent.eventStartTime, forKeyPath: "eventStartTime")
        newEvent.setValue(currentEvent.eventName,      forKeyPath: "eventName")
        newEvent.setValue(currentEvent.eventDuration,  forKeyPath: "eventDuration")
        newEvent.setValue(currentEvent.latitude,       forKeyPath: "latitude")
        newEvent.setValue(currentEvent.longitude,      forKeyPath: "longitude")
        
        if let newEventDataURL = currentEvent.dataURL {
            newEvent.setValue(newEventDataURL, forKeyPath: "dataURL")
        }
        if let newEventArguments = currentEvent.arguments {
            let data = try? JSONSerialization.data(withJSONObject: newEventArguments, options: [])
            newEvent.setValue(data, forKeyPath: "customParam")
        }
        self.saveContext()
    }
    
    
    /// Fetch item from entity with respect to screenID
    ///
    /// - Parameter screenID: screenID
    /// - Returns: arry of items for particular screenID
    func fetchEventWithScreenID(screenID:String?) -> [AnyObject]? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Events")
        fetchRequest.predicate = NSPredicate(format: "screenViewID = %@", screenID!)
        do {
            let data:Array<AnyObject> = try self.currentContext().fetch(fetchRequest)
            return data
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
            return nil
        }
    }
    
    // MARK: Call back sync
    
    /// Delete array contents from entity.
    ///
    /// - Parameter screenIDArray: array of screenID
    func removeSyncedObjects(screenIDArray:Array<String?>) -> Void {
        for eachScreenID in screenIDArray {
            if let eachScreenID = eachScreenID {
                self.deleteSyncableObjects(screenID: eachScreenID, forEntity: "Screen")
                self.deleteSyncableObjects(screenID: eachScreenID, forEntity: "Events")
            }
            self.saveContext()
        }
    }
    
    /// Delete entity content
    ///
    /// - Parameter entityName: DB entity Name
    func deleteSyncableObjects(forEntity entityName:String) -> Void {
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        if #available(iOS 9.0, *) {
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            do {
                try persistentStoreCoordinator.execute(deleteRequest, with: self.currentContext())
            } catch let error as NSError {
                // TODO: handle the error
                print("Could not save. \(error), \(error.userInfo)")
            }
            
        } else {
            do {
                let results = try self.currentContext().fetch(fetchRequest) as Array<AnyObject>
                if (results.count) > 0 {
                    for eachScreen in results {
                        self.currentContext().delete(eachScreen as! NSManagedObject)
                    }
                }
            } catch let error as NSError {
                print("Could not save. \(error), \(error.userInfo)")
            }
        }
        
    }
    
    /// Delete item from core data
    ///
    /// - Parameters:
    ///   - screenID: screenID is unique ID
    ///   - entityName: entityName
    func deleteSyncableObjects(screenID:String, forEntity entityName:String) -> Void {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "screenViewID = %@", screenID)
        do {
            let results = try self.currentContext().fetch(fetchRequest) as Array<AnyObject>
            if (results.count) > 0 {
                for eachScreen in results {
                    self.currentContext().delete(eachScreen as! NSManagedObject)
                }
            }
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }
    
    // MARK: - Core Data Saving support
    func saveContext () {
        let context = self.currentContext()
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}
