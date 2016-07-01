//
//  ThreadController.swift
//  SocialSuburb
//
//  Created by Patrick Pahl on 6/29/16.
//  Copyright © 2016 Patrick Pahl. All rights reserved.
//

import Foundation
import CoreData
import UIKit


class ThreadController{
    
    static let sharedController = ThreadController()
    
    let cloudKitManager: CloudKitManager
    
    var isSyncing: Bool = false
    
    init(){
        
    self.cloudKitManager = CloudKitManager()
    
    ///performFullSync()
        
    }
    
    
    func saveToPersistentStorage(){
        let moc = Stack.sharedStack.managedObjectContext
        do {
            try moc.save()
        } catch {
            print("MOC error")
        }
    }
    
    
    func addThread(name: String, text: String, completion: (() -> Void)?){
        let thread = Thread(name: name)
        
        addMessageToThread(text, thread: name, completion: nil)                 ///???
        
        saveToPersistentStorage()
        
        if let completion = completion{
            completion()
        }
        
        if let threadRecord = thread?.cloudKitRecord {
            
            cloudKitManager.saveRecord(threadRecord, completion: { (record, error) in
                
                if let record = record {
                    thread?.update(record)
                    
                ///subscription code??
                }
            })
        }
    }
    
    func deleteThread(thread: Thread, completion: (() -> Void)?){
        let moc = Stack.sharedStack.managedObjectContext
        moc.deleteObject(thread)
        saveToPersistentStorage()
        
        if let completion = completion{
            completion()
        }
        ////Delete CloudKit Code:
        
        if let record = thread.cloudKitRecord{
            
            cloudKitManager.deleteRecordWithID(CKRecordID(recordName: recordID), completion: { (recordID, error) in
                NSLog("OK or \(error)")
            })
        }
        
//        FROM STACKOVERFLOW
//        database.deleteRecordWithID(CKRecordID(recordName: recordId), completionHandler: {recordID, error in
//            NSLog("OK or \(error)")
//        }
        
    }
    
    func addMessageToThread(text: String, thread: Thread, completion: ((success: Bool) -> Void)?){
        
        let message = Message(thread: thread, text: text)
        
        saveToPersistentStorage()
        
        if let completion = completion{
            completion(success: true)
        }
        
        if let messageRecord = message?.cloudKitRecord{
            
            cloudKitManager.saveRecord(messageRecord, completion: { (record, error) in
                if let record = record {
                    message?.update(record)
                }
            })
        }
    }
    
    func deleteMessageFromThread(message: Message, completion: (() -> Void)?){
        let moc = Stack.sharedStack.managedObjectContext
        moc.deleteObject(message)
        saveToPersistentStorage()
        
        if let completion = completion{
            completion()
        }
        
        ////////Delete in CloudKit code
        
        if let messageRecord = messsage?.cloudkitRecord {
        
        cloudKitManager.saveRecord(messageRecord) { (record, error) in
            }
        }
    }
    
    // MARK: - Helper Fetches
    
    func threadWithName(name: String) -> Thread?{           //Thread needs to be optional
        
        if name.isEmpty {return nil}
        
        let fetchRequest = NSFetchRequest(entityName: Thread.typeKey)
        
        let predicate = NSPredicate(format: "recordName == %@", argumentArray: [name])
        
        fetchRequest.predicate = predicate
        
        let result = (try? Stack.sharedStack.managedObjectContext.executeFetchRequest(fetchRequest)) as? [Thread] ?? nil     ///always fails to cast?
        
        return result?.first
        
    }
    
    func syncedRecords(type: String) -> [CloudKitManagedObject]{
        
        let fetchRequest = NSFetchRequest(entityName: type)
        let predicate = NSPredicate(format: "recordIDData != nil")
        
        fetchRequest.predicate = predicate
        
        let results = (try? Stack.sharedStack.managedObjectContext.executeFetchRequest(fetchRequest)) as? [CloudKitManagedObject] ?? []
        
        return results
    }
    
    func unsyncedRecords(type: String) -> [CloudKitManagedObject] {
    
    let fetchRequest = NSFetchRequest(entityName: type)
    let predicate = NSPredicate(format: "recordData == nil")
    
    fetchRequest.predicate = predicate
        
    let results = (try? Stack.sharedStack.managedObjectContext.executeFetchRequest(fetchRequest)) as? [CloudKitManagedObject] ?? []
        
    return results
    }
    
    // MARK: - Sync
    
    func performFullSync(completion: (() -> Void)? = nil) {
        
        if isSyncing {
            if let completion = completion{
                completion()
            }
        } else {
            isSyncing  = true
            
            pushChangesToCloudKit({ (success, error) in
                self.fetchNewRecords(Thread.typeKey){
                    self.fetchNewRecords(Message.typeKey, completion: { 
                        self.isSyncing = false
                        
                        if let completion = completion{
                            completion()
                        }
                    })
                }
            })
        }
    }
    
    
    func fetchNewRecords(type: String, completion: (() -> Void)?){
        
        let referencesToExclude = syncedRecords(type).flatMap({ $0.cloudKitReference})
        var predicate = NSPredicate(format: "NOT(recordID in %@", argumentArray: [referencesToExclude])
        
        if referencesToExclude.isEmpty {
            predicate = NSPredicate(value: true)
        }
        
        cloudKitManager.fetchRecordsWithType(type, predicate: predicate, recordFetchedBlock: { (record) in
            
            switch type{
            case Thread.typeKey:
                let _ = Thread(record: record)
            case Message.typeKey:
                let _ = Message(record: record)
            default:
                return
            }
            self.saveToPersistentStorage()
            
            }) { (records, error) in
                
                if error != nil{
                    print("error - fetch new records")
                }
                if let completion = completion{
                    completion()
                }
            }
        }
    
    
    
    
    
    
    func pushChangesToCloudKit(completion: ((success: Bool, error: NSError?) -> Void)?) {
        
     let unsavedManagedObjects = unsyncedRecords(Thread.typeKey) + unsyncedRecords(Message.typeKey)
     let unsavedRecords = unsavedManagedObjects.flatMap({ $0.cloudKitRecord})
        
     cloudKitManager.saveRecords(unsavedRecords, perRecordCompletion: { (record, error) in
        
        guard let record = record else {return}
        
        if let matchingRecord = unsavedManagedObjects.filter({$0.recordName == record.recordID.recordName}).first{
            matchingRecord.update(record)
        }
        
        }) { (records, error) in
            if let completion = completion{
                let success = records != nil
                completion(success: success, error: error)
            }
        }
    }
}

