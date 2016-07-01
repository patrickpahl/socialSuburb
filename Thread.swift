//
//  Thread.swift
//  SocialSuburb
//
//  Created by Patrick Pahl on 6/29/16.
//  Copyright © 2016 Patrick Pahl. All rights reserved.
//

import Foundation
import CoreData
import UIKit
import CloudKit

class Thread: SyncableObject, CloudKitManagedObject {

    static let typeKey = "Thread"
    static let timestampKey = "timestamp"
    
    
    convenience init?(name: String, timestamp: NSDate = NSDate(), context: NSManagedObjectContext = Stack.sharedStack.managedObjectContext){
        
        guard let entity = NSEntityDescription.entityForName(Thread.typeKey, inManagedObjectContext: context) else {return nil}
        
        self.init(entity: entity, insertIntoManagedObjectContext: context)
     
        self.name = name
        self.timestamp = timestamp
        self.recordName = self.nameForManagedObject()
        
    }
    // MARK: - SearchableRecord
    
    ////NEED search code
    
    
    // MARK: - CloudKitManagedObject
    
    var recordType: String = Thread.typeKey
    
    var cloudKitRecord: CKRecord? {
        
        let recordID = CKRecordID(recordName: recordName)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        
        record[Thread.timestampKey] = timestamp
        
        return record
    }
    
    convenience required init?(record: CKRecord, context: NSManagedObjectContext = Stack.sharedStack.managedObjectContext){
        
        guard let timestamp = record.creationDate else {return nil}
        
        guard let entity = NSEntityDescription.entityForName(Thread.typeKey, inManagedObjectContext: context) else {fatalError("CoreData failed to create entity from entity description")}
        
        self.init(entity: entity, insertIntoManagedObjectContext: context)
        
        self.timestamp = timestamp
        self.recordIDData = NSKeyedArchiver.archivedDataWithRootObject(record.recordID)
        self.recordName = record.recordID.recordName
    }
}








