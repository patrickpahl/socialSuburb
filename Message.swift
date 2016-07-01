//
//  Message.swift
//  SocialSuburb
//
//  Created by Patrick Pahl on 6/29/16.
//  Copyright © 2016 Patrick Pahl. All rights reserved.
//

import Foundation
import CoreData
import UIKit
import CloudKit

class Message: SyncableObject, CloudKitManagedObject {

    static let typeKey = "Message"
    static let textKey = "text"
    static let threadKey = "thread"
    static let timestampKey = "timestamp"
    
    
    convenience init?(thread: Thread, text: String, timestamp: NSDate = NSDate(), context: NSManagedObjectContext = Stack.sharedStack.managedObjectContext){
        
        guard let entity = NSEntityDescription.entityForName(Message.typeKey, inManagedObjectContext: context) else {return nil}
        
        self.init(entity: entity, insertIntoManagedObjectContext: context)
        
        self.text = text
        self.timestamp = timestamp
        self.thread = thread
        self.recordName = self.nameForManagedObject()           //For cloudKit
    }

    
    /// MARK: - SearchableRecord


    //MARK: - CloudKitManagedObject

    var recordType: String = Message.typeKey
    
    var cloudKitRecord: CKRecord?{
        
        let recordID = CKRecordID(recordName: recordName)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        
        record[Message.timestampKey] = timestamp
        record[Message.textKey] = text
        
        guard let thread = thread,
            let threadRecord = thread.cloudKitRecord else {fatalError("message does not have thread relationship")}
        
        record[Message.threadKey] = CKReference(record: threadRecord, action: .DeleteSelf)
        
        return record
    }
    
    convenience required init?(record: CKRecord, context: NSManagedObjectContext = Stack.sharedStack.managedObjectContext) {
        
    guard let timestamp = record.creationDate,
        let text = record[Message.typeKey] as? String,
        let threadReference = record[Message.threadKey] as? CKReference else {return nil}
        
        guard let entity = NSEntityDescription.entityForName(Message.typeKey, inManagedObjectContext: context) else {fatalError("coreData failed to create entity from entity description")}
        
        self.init(entity: entity, insertIntoManagedObjectContext: context)
        
        self.timestamp = timestamp
        self.text = text
        self.recordIDData = NSKeyedArchiver.archivedDataWithRootObject(record.recordID)
        self.recordName = record.recordID.recordName
        
        if let thread = ThreadController.sharedController.threadWithName(threadReference.recordID.recordName){
            self.thread = thread
        }
    }
}


