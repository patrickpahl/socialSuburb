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
        
        performFullSync()
        
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
        guard let thread = Thread(name: name) else {
            return
        }
        
        addMessageToThread(text, thread: thread, completion: nil)
        
        saveToPersistentStorage()
        
        if let completion = completion{
            completion()
        }
        
        if let threadRecord = thread.cloudKitRecord {
            
            cloudKitManager.saveRecord(threadRecord, completion: { (record, error) in
                
                if let record = record {
                    thread.update(record)
                    
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
        ///Delete CloudKit Code:
        
        if let CKRecordID = thread.cloudKitRecordID{
            
            cloudKitManager.deleteRecordWithID(CKRecordID, completion: { (recordID, error) in
                NSLog("OK or \(error)")
            })
        }
    }
    
    func addMessageToThread(text: String, thread: Thread, completion: ((success: Bool) -> Void)?){
        
        let message = Message(thread: thread, text: text)
        
        saveToPersistentStorage()                               ///Takes care of 'self.messages.append(message)' ???
        
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
        
        ///Delete in CloudKit code
        
        if let messageRecordID = message.cloudKitRecordID {
            
            cloudKitManager.deleteRecordWithID(messageRecordID, completion: { (recordID, error) in
                NSLog("OK or \(error)")
            })
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
    
    // MARK: - Subscriptions
    
    func subscribeToNewThreads(completion: ((success: Bool, error: NSError?) -> Void)?){
        
        let predicate = NSPredicate(value: true)
        
        cloudKitManager.subscribe(Thread.typeKey, predicate: predicate, subscriptionID: "allThreads", contentAvailable: true, options: .FiresOnRecordCreation) { (subscription, error) in
            
            if let completion = completion{
                let success = subscription != nil
                completion(success: success, error: error)
            }
        }
    }
    
    func checkSubscriptionToThreadMessages(thread: Thread, completion: ((subscribed: Bool) -> Void)?) {
        
        cloudKitManager.fetchSubscription(thread.recordName) { (subscription, error) in
            if let completion = completion {
                let subscribed = subscription != nil
                completion(subscribed: subscribed)
            }
        }
    }
    
    func addSubscriptionToThreadMessages(thread: Thread, alertBody: String?, completion: ((success: Bool, error: NSError?) -> Void)?){
        
        guard let recordID = thread.cloudKitRecordID else {fatalError("Unable to create cloudkit reference for subscription")}
        
        let predicate = NSPredicate(format: "thread == %@", argumentArray: [recordID])
        
        cloudKitManager.subscribe(Message.typeKey, predicate: predicate, subscriptionID: thread.recordName, contentAvailable: true, options: .FiresOnRecordCreation) { (subscription, error) in
            
            if let completion = completion{
                
                let success = subscription != nil
                completion(success: success, error: error)
            }
        }
    }
    
    func removeSubscriptionToThreadMessages(thread: Thread, completion: ((success: Bool, error: NSError?) -> Void)?) {
        
        let subscriptionID = thread.recordName
        
        cloudKitManager.unsubscribe(subscriptionID) { (subscriptionID, error) in
            if let completion = completion {
                let success = subscriptionID != nil && error == nil
                completion(success: success, error: error)
            }
        }
    }
    
    func toggleThreadMessageSubscription(thread: Thread, completion: ((success: Bool, isSubscribed: Bool, error: NSError?) -> Void)?) {
        
        cloudKitManager.fetchSubscriptions { (subscriptions, error) in
            if subscriptions?.filter({$0.subscriptionID == thread.recordName}).first != nil {
                self.removeSubscriptionToThreadMessages(thread, completion: { (success, error) in
                    
                    if let completion = completion{
                        completion(success: success, isSubscribed: false, error: error)
                    }
                })
            } else {
                self.addSubscriptionToThreadMessages(thread, alertBody: "new Message 👍", completion: { (success, error) in
                    if let completion = completion{
                        completion(success: true, isSubscribed: true, error: error)
                    }
                })
            }
        }
    }
    
    /////////////////////////////////////////////////////// NEW 7/3/16, from Message Controller on bulletinboard app
    
    static let MessagesControllerDidRefreshNotification = "MessagesControllerDidRefreshNotification"
    
    static let ThreadsControllerDidRefreshNotification = "ThreadsControllerDidRefreshNotification"
    
    
    // MARK: Public Methods
    
    func refresh(completion: ((NSError?) -> Void)? = nil){
        
        cloudKitManager.fetchRecordsWithType(Message.recordType, recordFetchedBlock: nil) { (records, error) in
            defer {completion?(error)}
            if let error = error {
                NSLog("Error fetching from CloudKit: \(error)")
                return
            }
            guard let records = records else {return}
            self.messages = records.flatMap{Message(cloudKitRecord: $0)}.sort {$0.date.compare($1.date) == NSComparisonResult.OrderedAscending}
        }
    }
    
    // MARK: Public Properties
    
    static var messages = [Message](){
        
        didSet {
            dispatch_async(dispatch_get_main_queue()) {
                let nc = NSNotificationCenter.defaultCenter()
                nc.postNotificationName(ThreadController.MessagesControllerDidRefreshNotification, object: self)
            }
        }
    }
    
    static var threads = [Thread](){
        didSet {
            dispatch_async(dispatch_get_main_queue()) {
                let nc = NSNotificationCenter.defaultCenter()
                nc.postNotificationName(ThreadController.ThreadsControllerDidRefreshNotification, object: self)
            }
        }
        
        
        
        
    }
    
}













