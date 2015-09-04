//
//  UIChatBubbleTableViewController.swift
//  UIChatBubble
//
//  Created by Yang Zhen on 15/7/4.
//  Copyright (c) 2015 Yang Zhen. All rights reserved.
//

import UIKit
import CocoaAsyncSocket

enum TAG: Int {
    case header = 1
    case body   = 2
}

class UIChatBubbleTableViewController: UITableViewController, UITableViewDataSource, UITextFieldDelegate,
                                       NSNetServiceDelegate, NSNetServiceBrowserDelegate, GCDAsyncSocketDelegate
{
    var service : NSNetService!
    var socket  : GCDAsyncSocket!
    
    var cellDataArray = [ChatBubbleCellData]()
    var ifCellRegistered = false
    @IBOutlet weak var senderTextField: UITextField!
    
    // Load test data here
    override func viewDidLoad()
    {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyle.None
        loadTestData()
        senderTextField.delegate = self
        startTalking()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        senderTextField.becomeFirstResponder()
    }
    
    // Send button on keyboard action
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        senderTextField.resignFirstResponder()
        if sendText() {
            addMessage(senderTextField.text, date: NSDate(timeIntervalSinceNow: -24*60*60), type: ChatBubbleMessageType.MyMessage)
            tableView.reloadData()
            senderTextField.text = ""
        }
        return true
    }
    
    
    func parseHeader(data: NSData) -> UInt {
        var out: UInt = 0
        data.getBytes(&out, length: sizeof(UInt))
        return out
    }
    
    func handleResponseBody(data: NSData) {
        var receivedText : String
        if let message = NSString(data: data, encoding: NSUTF8StringEncoding) {
            receivedText = message as String
            addMessage(receivedText, date: NSDate(timeIntervalSinceNow: -24*60*60+30), type: ChatBubbleMessageType.YourMessage)
            tableView.reloadData()
        }
    }

    func sendText() -> Bool{
        if let data = self.senderTextField.text.dataUsingEncoding(NSUTF8StringEncoding) {
            var header = data.length
            let headerData = NSData(bytes: &header, length: sizeof(UInt))
            self.socket.writeData(headerData, withTimeout: -1.0, tag: TAG.header.rawValue)
            self.socket.writeData(data, withTimeout: -1.0, tag: TAG.body.rawValue)
            return true
        }
        return false
    }

    
    func startTalking () {
        self.socket = GCDAsyncSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
        var error : NSError?
        if self.socket.acceptOnPort(0, error: &error){
            self.service = NSNetService(domain: "local.", type: "_ugurtemiz._tcp", name: "Ugur's iPhone", port: Int32(self.socket.localPort))
            self.service.delegate = self
            self.service.publish()
        } else {
            println("Error occured with acceptOnPort. Error \(error)")
        }
    }
    
    /*
    *  Delegates of NSNetService
    **/
    
    func netServiceDidPublish(sender: NSNetService) {
        println("Bonjour service published. domain: \(sender.domain), type: \(sender.type), name: \(sender.name), port: \(sender.port)")
    }
    
    func netService(sender: NSNetService, didNotPublish errorDict: [NSObject : AnyObject]) {
        println("Unable to create socket. domain: \(sender.domain), type: \(sender.type), name: \(sender.name), port: \(sender.port), Error \(errorDict)")
    }
    
    /*
    *  END OF Delegates
    **/
    
    /*
    *  Delegates of GCDAsyncSokcket
    **/
    
    func socket(sock: GCDAsyncSocket!, didAcceptNewSocket newSocket: GCDAsyncSocket!) {
        println("Did accept new socket")
        self.socket = newSocket
        
        self.socket.readDataToLength(UInt(sizeof(UInt64)), withTimeout: -1.0, tag: 0)
        println("Connected to " + self.service.name)
    }
    
    func socketDidDisconnect(sock: GCDAsyncSocket!, withError err: NSError!) {
        println("Socket disconnected: error \(err)")
        if self.socket == socket {
            println("Disconnected from " + self.service.name)
        }
    }
    
    func socket(sock: GCDAsyncSocket!, didReadData data: NSData!, withTag tag: Int) {
        if data.length == sizeof(UInt) {
            let bodyLength: UInt = self.parseHeader(data)
            sock.readDataToLength(bodyLength, withTimeout: -1, tag: TAG.body.rawValue)
        } else {
            self.handleResponseBody(data)
            sock.readDataToLength(UInt(sizeof(UInt)), withTimeout: -1, tag: TAG.header.rawValue)
        }
    }
    
    func socket(sock: GCDAsyncSocket!, didWriteDataWithTag tag: Int) {
        println("Write data with tag of \(tag)")
    }
    
    /*
    *  END OF Delegates
    **/

    
    
    // Number of rows in TableView
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return cellDataArray.count
    }
    
    // Get TableViewCell here
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let data = cellDataArray[indexPath.row]
        let cell: UIChatBubbleTableViewCell
        
        if ifCellRegistered
        {
            let reusableCell: AnyObject = tableView.dequeueReusableCellWithIdentifier("UIChatBubbleTableViewCell", forIndexPath: indexPath)
            cell = reusableCell as! UIChatBubbleTableViewCell
        }
        else
        {
            let cellArray = NSBundle.mainBundle().loadNibNamed("UIChatBubbleTableViewCell", owner: self, options: nil)
            cell = cellArray[0] as! UIChatBubbleTableViewCell
            
            //register UIChatBubbleTableViewCell
            let nib = UINib(nibName: "UIChatBubbleTableViewCell", bundle: NSBundle.mainBundle())
            self.tableView.registerNib(nib, forCellReuseIdentifier: "UIChatBubbleTableViewCell")
            ifCellRegistered = true
        }
        
        cell.frame.size.width = self.tableView.frame.width
        cell.data = cellDataArray[indexPath.row]
        
        return cell
    }
    
    // TableViewCell's height
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat
    {
        return cellDataArray[indexPath.row].cellHeight
    }
    
    // TableView's header
    override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
    {
        let headerLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.tableView.frame.width, height: 10))
        headerLabel.font = UIFont(name: "Helvetica", size: 10.0)!
        headerLabel.text = "Messages"
        headerLabel.textAlignment = NSTextAlignment.Center
        headerLabel.textColor = UIColor.grayColor()
        return headerLabel
    }
    
    // Use this func to add message
    func addMessage(text: String, date: NSDate, type: ChatBubbleMessageType)
    {
        let message = ChatBubbleMessage(text: text, date: date, type: type)
        let ifHideDate: Bool
        if cellDataArray.count == 0 || date.timeIntervalSinceDate(cellDataArray[cellDataArray.count-1].message.date) > 60
        {
            ifHideDate = false
        }
        else
        {
            ifHideDate = true
        }
        let cellData = ChatBubbleCellData(message: message, hideDate: ifHideDate)
        cellDataArray.append(cellData)
    }
    
    // Add test data here
    func loadTestData()
    {
        addMessage("Hi!", date: NSDate(timeIntervalSinceNow: -24*60*60), type: ChatBubbleMessageType.MyMessage)
        addMessage("嗨！", date: NSDate(timeIntervalSinceNow: -24*60*60+30), type: ChatBubbleMessageType.YourMessage)
        addMessage("这是一条用来测试的中文字符串", date: NSDate(timeIntervalSinceNow: -12*60*60), type: ChatBubbleMessageType.MyMessage)
        addMessage("this is a string", date: NSDate(timeIntervalSinceNow: -12*60*60+30), type: ChatBubbleMessageType.YourMessage)
        addMessage("this is a very very very very very very very very very very very very very very very very very very very very very very very very very very very very long string", date: NSDate(timeIntervalSinceNow: -30), type: ChatBubbleMessageType.MyMessage)
        addMessage("这是一条非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常长的字符串", date: NSDate(), type: ChatBubbleMessageType.YourMessage)
    }

}

