//
//  CloudKitManager.swift
//  SocialSuburb
//
//  Created by Patrick Pahl on 6/29/16.
//  Copyright © 2016 Patrick Pahl. All rights reserved.
//


import Foundation
import CloudKit
import UIKit

///***generic code, can use in all projects, not just this one

class CloudKitManager{
    
    private let CreationDateKey = "creationDate"
    
    let publicDatabase = CKContainer.defaultContainer().publicCloudDatabase
    let privateDatabase = CKContainer.defaultContainer().privateCloudDatabase
    
    init(){
        checkCloudKitAvailability()
        requestDiscoverabilityPermission()
    }
    
    //MARK: - User Info Discovery
    
    func fetchLoggedInUserRecord(completion: ((record: CKRecord?, error: NSError?)-> Void)?) {  //If I'm logged in, will return my record (FN 2817)
        
        CKContainer.defaultContainer().fetchUserRecordIDWithCompletionHandler { (recordID, error) in
            if let error = error,
                let completion = completion{
                completion(record: nil, error: error)
            }
            
            if let recordID = recordID,
                let completion = completion {
                self.fetchRecordWithID(recordID, completion: { (record, error) in
                    completion(record: record, error: error)
                })
            }
        }
    }
    
    //func gets first and last name of user - First NSOperation
    func fetchUserNameFromRecordID(recordID: CKRecordID, completion: ((firstName: String?, lastName: String?) -> Void)?) {  //From FN 2817, we get Fin
        
        let operation = CKDiscoverUserInfosOperation(emailAddresses: nil, userRecordIDs: [recordID])
        
        operation.discoverUserInfosCompletionBlock = { (emailsToUserInfos, userRecordIDsToUserInfos, operationError) -> Void in
            //Does not auto-complete, these are the 3 parameters that are returned to us.
            if let userRecordIDsToUserInfos = userRecordIDsToUserInfos,
                let userInfo = userRecordIDsToUserInfos[recordID],
                let completion = completion {
                completion(firstName: userInfo.displayContact?.givenName, lastName: userInfo.displayContact?.familyName)
            } else if let completion = completion {
                completion(firstName: nil, lastName: nil)
            }
        }
        
        CKContainer.defaultContainer().addOperation(operation)         //run on background thread
        
        
        
        func fetchAllDiscoverableUsers(completion: ((userInfoRecords: [CKDiscoveredUserInfo]?) -> Void)?) {     //Get all storm troopers
            
            let operation = CKDiscoverAllContactsOperation()
            
            operation.discoverAllContactsCompletionBlock = { ( discoverUserInfos, error) -> Void in
                
                if let completion = completion{
                    completion(userInfoRecords: discoverUserInfos)
                }
            }
        }
        CKContainer.defaultContainer().addOperation(operation)          //If we don't add this operation, our code won't run.
    }
    
    //MARK: -Fetch Records
    
    //Takes in a RecordID and returns a record
    func fetchRecordWithID(recordID: CKRecordID, completion: ((record: CKRecord?, error: NSError?) -> Void)?) {
        //Brings back the record for whatever item has that ID (starship, trooper, etc.)
        publicDatabase.fetchRecordWithID(recordID) { (record, error) in
            if let completion = completion {
                completion(record: record, error: error)
            }
        }
        
    }
    
    //Need type and a predicate- PREDICATE is how we are going to narrow down our search results. How we filter the records.
    //2 completions: Once record comes down, we start dealing with that record, but we also want to know when we have all the records.
    //Recordsfetchedblock: once a post is called down, it will be called each time. If 100 posts, runs 100 times
    //2nd completion: Runs once all 100 posts are called.
    func fetchRecordsWithType(type: String, predicate: NSPredicate = NSPredicate(value: true), recordFetchedBlock: ((record: CKRecord) -> Void)?, completion: ((records: [CKRecord]?, error: NSError?) -> Void)?) {         //brings back all records of that type.(All stormtrooper records)
        
        var fetchedRecords: [CKRecord] = []
        
        let query = CKQuery(recordType: type, predicate: predicate)
        
        let queryOperation = CKQueryOperation(query: query)
        
        queryOperation.recordFetchedBlock = { (fetchedRecord) -> Void in            //What this does: When the query is done, run this code.
            fetchedRecords.append(fetchedRecord)
            if let recordFetchedBlock = recordFetchedBlock{
                recordFetchedBlock(record: fetchedRecord)
            }
        }
        queryOperation.queryCompletionBlock = { (queryCursor, error) -> Void in
            if let queryCursor = queryCursor {
                //QueryCursor: There are more records out there, let's get the rest of them.
                let continuedQueryOperation = CKQueryOperation(cursor: queryCursor)
                continuedQueryOperation.recordFetchedBlock = queryOperation.recordFetchedBlock
                continuedQueryOperation.queryCompletionBlock = queryOperation.queryCompletionBlock
                self.publicDatabase.addOperation(continuedQueryOperation)
                
            } else {
                //All done getting the records at this point.
                if let completion = completion{
                    completion(records: fetchedRecords, error: error)
                }
            }
            
        }
        self.publicDatabase.addOperation(queryOperation)
    }
    
    
    func fetchCurrentUserRecords(type: String, completion: ((records: [CKRecord]?, error: NSError?) -> Void)?){
        //calls for user's record, then all of the records that belong to that specific user
        fetchLoggedInUserRecord{( record, error) in
            //Error handling
            if let record = record {            //Only want to get all the records from our current user
                let predicate = NSPredicate(format: "%K == %@", argumentArray: ["creatorUserRecordID", record.recordID])
                //Below: choose fetchRecordsWithType WITH predicate
                self.fetchRecordsWithType(type, predicate: predicate, recordFetchedBlock: nil, completion: { (records, error) in
                    if let completion = completion{
                        completion(records: records, error: error)
                    }
                })
            }
        }
    }
    //What does a predicate do? For example, I want my posts, not Nic's post. Create predicate to get only my posts. If record is equal to Patrick's record, give me that record.
    
    func fetchRecordsFromDateRange(type: String, fromDate: NSDate, toDate: NSDate, completion: ((records: [CKRecord]?, error: NSError?)-> Void)?) {
        let startDatePredicate = NSPredicate(format: "%K > %@", argumentArray: [CreationDateKey, fromDate])         //Records from range
        let endDatePredicate = NSPredicate(format: "%k < %@", argumentArray: [CreationDateKey, toDate])
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [startDatePredicate, endDatePredicate])
        
        self.fetchRecordsWithType(type, predicate: predicate, recordFetchedBlock: nil) { (records, error) in
            if let completion = completion{
                completion(records: records, error: error)
            }
        }
    }
    
    //predicate for the start date and one for end date, then compounding them.
    
    
    //MARK: - Delete
    
    func deleteRecordWithID(recordID: CKRecordID, completion: ((recordID: CKRecordID?, error: NSError?) -> Void)?) {
        
        publicDatabase.deleteRecordWithID(recordID) { (record, error) in
            
            if let completion = completion{
                completion(recordID: recordID, error: error)
            }
        }
    }
    
    func deleteRecordsWithID(recordIDs: [CKRecordID], completion: ((records: [CKRecord]?, recordIds: [CKRecordID]?, error: NSError?) -> Void)?){
        
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
        operation.queuePriority = .High
        operation.savePolicy = .IfServerRecordUnchanged
        operation.qualityOfService = .UserInitiated             //performing work specified by the user.
        operation.modifyRecordsCompletionBlock = {(records, recordIDs, error) -> Void in
            if let completion = completion{
                completion(records: records, recordIds: recordIDs, error: error)
            }
        }
        CKContainer.defaultContainer().addOperation(operation)
    }
    
    //MARK: - SAVE/MODIFY
    
    func saveRecords(records: [CKRecord], perRecordCompletion: ((record: CKRecord?, error: NSError?) -> Void)?, completion: ((records: [CKRecord]?, error: NSError?) -> Void)?) {
        modifyRecords(records, perRecordCompletion: perRecordCompletion) { (records, error) in
            if let completion = completion {
                completion(records: records, error: error)
            }
        }
    }
    
    func saveRecord(record: CKRecord, completion: ((record: CKRecord?, error: NSError?) -> Void)?){
        
        publicDatabase.saveRecord(record) { (record, error) in
            if let completion = completion{
                completion(record: record, error: error)
            }
        }
    }
    
    
    func modifyRecords(records: [CKRecord], perRecordCompletion: ((record: CKRecord?, error: NSError?) -> Void)?, completion: ((records: [CKRecord]?, error: NSError?) -> Void)?) {
        
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.queuePriority = .High
        operation.savePolicy = .ChangedKeys
        operation.qualityOfService = .UserInteractive
        
        operation.perRecordCompletionBlock = { (record, error) -> Void in
            if let perRecordCompletion = perRecordCompletion {
                perRecordCompletion(record: record, error: error)
                
            }
        }
        operation.modifyRecordsCompletionBlock = { (records, recordIDs, error) -> Void in
            if let completion = completion {
                completion(records: records, error: error)
            }
        }
        publicDatabase.addOperation(operation)
    }
    
    
    //MARK: - ClOUDKIT PERMISSIONS
    
    
    func checkCloudKitAvailability(){
        
        CKContainer.defaultContainer().accountStatusWithCompletionHandler { (accountStatus, error) in       //is cloudKit available
            switch accountStatus{
            case .Available:
                print("CloudKit is available")
            default:
                self.handleCloudKitNotAvailable(accountStatus, error: error)
            }
        }
    }
    
    
    func handleCloudKitNotAvailable(accountStatus: CKAccountStatus, error: NSError?) {          //prepare your excuse, find out what to say
        
        var errorText = "Sync is disabled \n"
        if let error = error {
            errorText += error.localizedDescription
        }
        
        switch accountStatus {
            
        case .Restricted:
            errorText += "iCloud is not available due to restrictions"
        case .NoAccount:
            errorText += "There is no iCloud account setup. \n Mange in Settings"
        default:
            break
        }
        displayCloudKitNotAvailableError(errorText)
        
    }
    
    
    func displayCloudKitNotAvailableError(errorText: String) {                              //Giving the excuse here.
        
        dispatch_async(dispatch_get_main_queue(), {                     //import UIKit, can tell if not auto-completing for alerts.
            let alertController = UIAlertController(title: "iCloud Sync Error", message: errorText, preferredStyle: .Alert)
            let dismissAction = UIAlertAction(title: "Ok", style: .Cancel, handler: nil)
            
            alertController.addAction(dismissAction)
            //we're in cloudkit, need to present there
            
            if let AppDelegate = UIApplication.sharedApplication().delegate,
                let appWindow = AppDelegate.window!,                                //! bc we know for a fact we have a window
                let rootViewController = appWindow.rootViewController {
                rootViewController.presentViewController(alertController, animated: true, completion: nil)
                
            }
        })
        
    }
    
    //MARK: - CloudKit Discoverability
    
    func requestDiscoverabilityPermission() {               //Can you play? Are you available?
        CKContainer.defaultContainer().statusForApplicationPermission(.UserDiscoverability) { (permissionStatus, error) in
            if permissionStatus == .InitialState {
                CKContainer.defaultContainer().requestApplicationPermission(.UserDiscoverability, completionHandler: { (permissionStatus, error) in
                    self.handleCloudKitPermissionStatus(permissionStatus,error: error)
                })
            } else {
                self.handleCloudKitPermissionStatus(permissionStatus, error: error)
            }
            
        }
    }
    
    func handleCloudKitPermissionStatus(permissionStatus: CKApplicationPermissionStatus, error: NSError?){      //Finding out Y/N of availability
        if permissionStatus == .Granted {                                                                       //If N, prepare excuse
            print("User Discoverability permission granted. User may process with full access.")
        } else {
            var errorText = "Sync is disabled \n"
            if let error = error {
                errorText += error.localizedDescription
            }
            switch permissionStatus {
            case .Denied:
                errorText += "You have denied User Discoverability permissions. You may be unable to use certain features that require User Discoverability."
            case .CouldNotComplete:
                errorText += "Unable to vertify User Discoverability permissions. You may have a connectivity issue. Please try again."
            default:
                break
                
            }
            displayCloudKitPermissionNotGrantedError(errorText)
        }
    }
    
    func displayCloudKitPermissionNotGrantedError(errorText: String) {                  //Break it to them, give your excuse.
        dispatch_async(dispatch_get_main_queue(), {
            let alertController = UIAlertController(title: "iCloud permissions error", message: errorText, preferredStyle: .Alert)
            let dismissAction = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
            alertController.addAction(dismissAction)
            if let appDelegate = UIApplication.sharedApplication().delegate,
                let appWindow = appDelegate.window!,
                let rootViewController = appWindow.rootViewController {
                rootViewController.presentViewController(alertController, animated: true, completion: nil)
            }
        })
    }
    
    // MARK: - Subscriptions
    
    func subscribe(type: String, predicate: NSPredicate, subscriptionID: String, contentAvailable: Bool, alertBody: String? = nil, desiredKeys: [String]? = nil, options: CKSubscriptionOptions, completion: ((subscription: CKSubscription?, error: NSError?) -> Void)?) {
        
        let subscription = CKSubscription(recordType: type, predicate: predicate, subscriptionID: subscriptionID, options: options)
        
        let notificationInfo = CKNotificationInfo()
        notificationInfo.alertBody = alertBody
        notificationInfo.shouldSendContentAvailable = contentAvailable
        notificationInfo.desiredKeys = desiredKeys                        //Other keys we can include in subscription, who commented on what post
        
        subscription.notificationInfo = notificationInfo
        
        publicDatabase.saveSubscription(subscription) { (subscription, error) in        //Once we have everything, we can save to pub database
            
            if let completion = completion{                                             //We'll either get back subscription or error
                completion(subscription: subscription, error: error)
            }
        }
    }
    
    
    func unsubscribe(subscriptionID: String, completion: ((subscriptionID: String?, error: NSError?) -> Void)?) {       //Need SubID to unsubscribe
        
        publicDatabase.deleteSubscriptionWithID(subscriptionID) { (subscriptionID, error) in
                                                                            //Save to publicDatabase, bc thats where we keep our cloudkit info
            if let completion = completion{
                completion(subscriptionID: subscriptionID, error: error)
            }
        }
        
    }
    
    func fetchSubscriptions(completion: ((subscriptions: [CKSubscription]?, error: NSError?) -> Void)?){        //Fetch by CKSubscription
        
        publicDatabase.fetchAllSubscriptionsWithCompletionHandler { (subscriptions, error) in               //Go to pubDatabase, fetch all subs
            if let completion = completion{
                completion(subscriptions: subscriptions, error: error)
            }
        }
    }
                                                                                                            //Fetch one specific subscription
    func fetchSubscription(subscriptionID: String, completion: ((subscription: CKSubscription?, error: NSError?) -> Void)?){    //Need the sub ID
        
        publicDatabase.fetchSubscriptionWithID(subscriptionID) { (subscription, error) in                   //find the subID in the pub database.
            if let completion = completion{
                completion(subscription: subscription, error: error)
            }
        }
    }
    
    
    
}
