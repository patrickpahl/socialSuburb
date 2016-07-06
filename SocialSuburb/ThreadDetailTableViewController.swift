//
//  ThreadDetailTableViewController.swift
//  SocialSuburb
//
//  Created by Patrick Pahl on 6/29/16.
//  Copyright © 2016 Patrick Pahl. All rights reserved.
//

import UIKit

class ThreadDetailTableViewController: UITableViewController {
    
    // MARK: IBOutlets
    @IBOutlet weak var textField: UITextField!
    
    var thread: Thread?
    
    // MARK: IBActions
    @IBAction func sendButtonTapped(sender: AnyObject) {                                ///Send Code ADDED
        
        guard let messageText = textField.text else {return}
        textField.resignFirstResponder()
        
        // TESTING
        if let thread = thread {
            ThreadController.sharedController.addMessageToThread(messageText, thread: thread) { (success) in
                /// CODE HERE???
            }
        }
    }
    
    func messagesWereUpdated(notification: NSNotification) {                             /// Messages were updated ADDED
        tableView.reloadData()
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {                        ///Text field should return ADDED
        textField.resignFirstResponder()
        return true
    }
    
    override func viewDidLoad() {                                                       ///VDL: Need NSNotificationCenter or addObserver code???
        super.viewDidLoad()
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Table view data source
    ///Num of Sections in Table View: Commented out
    //    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    //        // #warning Incomplete implementation, return the number of sections
    //        return 0
    //    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {        ///Num rows in section: Need to complete
        //            ThreadController.sharedController.
        return 0
    }
    
    let dateFormatter: NSDateFormatter = {                                              ///Date formatter: Need this?
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.doesRelativeDateFormatting = true
        formatter.timeStyle = .ShortStyle
        return formatter
    }()
    
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("MessageCell", forIndexPath: indexPath)
        
        
        return cell
    }
    
    
    /*
     // Override to support conditional editing of the table view.
     override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
     // Return false if you do not want the specified item to be editable.
     return true
     }
     */
    
    /*
     // Override to support editing the table view.
     override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
     if editingStyle == .Delete {
     // Delete the row from the data source
     tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
     } else if editingStyle == .Insert {
     // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
     }
     }
     */
    
    /*
     // Override to support rearranging the table view.
     override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
     
     }
     */
    
    /*
     // Override to support conditional rearranging of the table view.
     override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
     // Return false if you do not want the item to be re-orderable.
     return true
     }
     */
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
}
