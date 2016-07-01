//
//  CloudKitManagedObject.swift
//  SocialSuburb
//
//  Created by Patrick Pahl on 6/30/16.
//  Copyright © 2016 Patrick Pahl. All rights reserved.
//

import Foundation
import CoreData
import CloudKit


@objc protocol CloudKitManagedObject{       //protocol that will define how the app will work with CloudKit and Core Data objects.
    
    var timestamp: NSDate {get set}
    var recordIDData: NSData? {get set}     //does this have a record ID Data or not?
    var recordName: String {get set}
    var recordType: String {get}            //Should loosely align with your class names, i.e. Thread
    
    var cloudKitRecord: CKRecord? {get}
    
    init?(record: CKRecord, context: NSManagedObjectContext)        //failable init, pass in a record to create a cloudKitObject
}

extension CloudKitManagedObject{            //Gives us shared functionality that we want to work on cloudKit objects- posts, comments
    
    var isSynced: Bool{
        return recordIDData != nil          //If something has recordIDData or not is how we know if something is synced
    }
    
    var cloudKitRecordID: CKRecordID?{
        
        guard let recordIDData = recordIDData,
            let recordID = NSKeyedUnarchiver.unarchiveObjectWithData(recordIDData) as? CKRecordID else {return nil}
            return recordID
    }
    
    var cloudKitReference: CKReference? {                           /// A computed property that returns a CKReference to the object in CloudKit
        
        guard let recordID = cloudKitRecordID else {return nil}     //Will be used to help pass a list of all synced objects to CloudKit so we can request new objects.
        return CKReference(recordID: recordID, action: .None)       //***Used with 'fetchNewRecords' func, to find out what we need to grab from iCloud.
    }
    
    func update(record: CKRecord){                                  //Called after we sync to the server.
        
    self.recordIDData = NSKeyedArchiver.archivedDataWithRootObject(record.recordID)     //Only way we can save to CoreData- through NSData.
        
        do{
            try Stack.sharedStack.managedObjectContext.save()
        } catch {
            print("unable to save MOC \(error)")
        }
    }
    
    func nameForManagedObject() -> String{                          //unique name
        return NSUUID().UUIDString
    }
}







