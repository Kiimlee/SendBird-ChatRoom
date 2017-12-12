//
//  OpenChannelChattingViewController.swift
//  TechnicalChatTest
//
//  Created by Willy Kim on 10/12/2017.
//  Copyright © 2017 Willy Kim. All rights reserved.
//

import UIKit
import SendBirdSDK
import AVKit
import AVFoundation
import MobileCoreServices
import Photos
import NYTPhotoViewer
import FLAnimatedImage

class OpenChannelChattingViewController: UIViewController, SBDConnectionDelegate, SBDChannelDelegate, ChattingViewDelegate, UINavigationControllerDelegate {
    var openChannel: SBDOpenChannel!
    
    @IBOutlet weak var chattingView: ChattingView!
    @IBOutlet weak var navItem: UINavigationItem!
    @IBOutlet weak var bottomMargin: NSLayoutConstraint!
    @IBOutlet weak var imageViewerLoadingView: UIView!
    @IBOutlet weak var imageViewerLoadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var imageViewerLoadingViewNavItem: UINavigationItem!
    
    private var messageQuery: SBDPreviousMessageListQuery!
    private var delegateIdentifier: String!
    private var hasNext: Bool = true
    private var refreshInViewDidAppear: Bool = true
    private var isLoading: Bool = false
    private var keyboardShown: Bool = false
    
    private var photosViewController: NYTPhotosViewController!
    @IBOutlet weak var navigationBarHeight: NSLayoutConstraint!
    
    private var minMessageTimestamp: Int64 = Int64.max
    private var dumpedMessages: [SBDBaseMessage] = []
    private var cachedMessage: Bool = true
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        let titleView: UILabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width - 100, height: 64))
        titleView.attributedText = Utils.generateNavigationTitle(mainTitle: String(format:"%@(%ld)", self.openChannel.name), subTitle: "")
        titleView.numberOfLines = 2
        titleView.textAlignment = NSTextAlignment.center
        
        let titleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(clickReconnect))
        titleView.isUserInteractionEnabled = true
        titleView.addGestureRecognizer(titleTapRecognizer)
        
        self.navItem.titleView = titleView
        
        let negativeLeftSpacer = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.fixedSpace, target: nil, action: nil)
        negativeLeftSpacer.width = -2
        let negativeRightSpacer = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.fixedSpace, target: nil, action: nil)
        negativeRightSpacer.width = -2
        
        let leftCloseItem = UIBarButtonItem(image: UIImage(named: "btn_close"), style: UIBarButtonItemStyle.done, target: self, action: #selector(close))
        let rightOpenMoreMenuItem = UIBarButtonItem(image: UIImage(named: "btn_more"), style: UIBarButtonItemStyle.done, target: self, action: #selector(openMoreMenu))
        
        self.navItem.leftBarButtonItems = [negativeLeftSpacer, leftCloseItem]
        self.navItem.rightBarButtonItems = [negativeRightSpacer, rightOpenMoreMenuItem]
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(notification:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidHide(notification:)), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillTerminate(notification:)), name: NSNotification.Name.UIApplicationWillTerminate, object: nil)
        
        let negativeLeftSpacerForImageViewerLoading = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.fixedSpace, target: nil, action: nil)
        negativeLeftSpacerForImageViewerLoading.width = -2
        
        let leftCloseItemForImageViewerLoading = UIBarButtonItem(image: UIImage(named: "btn_close"), style: UIBarButtonItemStyle.done, target: self, action: #selector(close))
        
        self.imageViewerLoadingViewNavItem.leftBarButtonItems = [negativeLeftSpacerForImageViewerLoading, leftCloseItemForImageViewerLoading]

        self.delegateIdentifier = self.description
        SBDMain.add(self as SBDChannelDelegate, identifier: self.delegateIdentifier)
        SBDMain.add(self as SBDConnectionDelegate, identifier: self.delegateIdentifier)
        
        self.chattingView.sendButton.addTarget(self, action: #selector(sendMessage), for: UIControlEvents.touchUpInside)
        
        self.hasNext = true
        self.refreshInViewDidAppear = true
        self.isLoading = false
        
        self.chattingView.sendButton.addTarget(self, action: #selector(sendMessage), for: UIControlEvents.touchUpInside)
        
        self.dumpedMessages = Utils.loadMessagesInChannel(channelUrl: self.openChannel.channelUrl)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.refreshInViewDidAppear {
            self.minMessageTimestamp = Int64.max
            self.chattingView.initChattingView()
            self.chattingView.delegate = self
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.refreshInViewDidAppear {
            if self.dumpedMessages.count > 0 {
                self.chattingView.messages.append(contentsOf: self.dumpedMessages)
                
                self.chattingView.chattingTableView.reloadData()
                self.chattingView.chattingTableView.layoutIfNeeded()
                
                let viewHeight = UIScreen.main.bounds.size.height - self.navigationBarHeight.constant - self.chattingView.inputContainerViewHeight.constant - 10
                let contentSize = self.chattingView.chattingTableView.contentSize
                
                if contentSize.height > viewHeight {
                    let newContentOffset = CGPoint(x: 0, y: contentSize.height - viewHeight)
                    self.chattingView.chattingTableView.setContentOffset(newContentOffset, animated: false)
                }
                
                self.cachedMessage = true
                self.loadPreviousMessage(initial: true)
                
                return
            }
            else {
                self.cachedMessage = false
                self.minMessageTimestamp = Int64.max
                self.loadPreviousMessage(initial: true)
            }
        }
        
        self.refreshInViewDidAppear = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        Utils.dumpMessages(messages: self.chattingView.messages, resendableMessages: self.chattingView.resendableMessages, resendableFileData: self.chattingView.resendableFileData, preSendMessages: self.chattingView.preSendMessages, channelUrl: self.openChannel.channelUrl)
    }
    
    @objc private func keyboardDidShow(notification: Notification) {
        self.keyboardShown = true
        let keyboardInfo = notification.userInfo
        let keyboardFrameBegin = keyboardInfo?[UIKeyboardFrameEndUserInfoKey]
        let keyboardFrameBeginRect = (keyboardFrameBegin as! NSValue).cgRectValue
        DispatchQueue.main.async {
            self.bottomMargin.constant = keyboardFrameBeginRect.size.height
            self.view.layoutIfNeeded()
            self.chattingView.stopMeasuringVelocity = true
            self.chattingView.scrollToBottom(force: false)
        }
    }
    
    @objc private func keyboardDidHide(notification: Notification) {
        self.keyboardShown = false
        DispatchQueue.main.async {
            self.bottomMargin.constant = 0
            self.view.layoutIfNeeded()
            self.chattingView.scrollToBottom(force: false)
        }
    }
    
    @objc private func applicationWillTerminate(notification: Notification) {
        Utils.dumpMessages(messages: self.chattingView.messages, resendableMessages: self.chattingView.resendableMessages, resendableFileData: self.chattingView.resendableFileData, preSendMessages: self.chattingView.preSendMessages, channelUrl: self.openChannel.channelUrl)
    }
    
    @objc private func close() {
        self.openChannel.exitChannel { (error) in
            self.dismiss(animated: false) {
                
            }
        }
    }
    
    @objc private func openMoreMenu() {
        DispatchQueue.main.async {
            let plvc = ParticipantListViewController()
            plvc.openChannel = self.openChannel
            self.refreshInViewDidAppear = false
            self.present(plvc, animated: false, completion: nil)
        }
    }
    
    private func loadPreviousMessage(initial: Bool) {
        var timestamp: Int64 = 0
        if initial {
            self.hasNext = true
            timestamp = Int64.max
        }
        else {
            timestamp = self.minMessageTimestamp
        }
        
        if self.hasNext == false {
            return
        }
        
        if self.isLoading {
            return
        }
        
        self.isLoading = true
        
        self.openChannel.getPreviousMessages(byTimestamp: timestamp, limit: 30, reverse: !initial, messageType: SBDMessageTypeFilter.all, customType: "") { (messages, error) in
            if error != nil {
                self.isLoading = false
                
                return
            }
            
            self.cachedMessage = false
            
            if messages?.count == 0 {
                self.hasNext = false
            }
            
            if initial {
                self.chattingView.messages.removeAll()
                
                for item in messages! {
                    let message: SBDBaseMessage = item as SBDBaseMessage
                    self.chattingView.messages.append(message)
                    if self.minMessageTimestamp > message.createdAt {
                        self.minMessageTimestamp = message.createdAt
                    }
                }
                
                let resendableMessagesKeys = self.chattingView.resendableMessages.keys
                for item in resendableMessagesKeys {
                    let key = item as String
                    self.chattingView.messages.append(self.chattingView.resendableMessages[key]!)
                }
                
                let preSendMessagesKeys = self.chattingView.preSendMessages.keys
                for item in preSendMessagesKeys {
                    let key = item as String
                    self.chattingView.messages.append(self.chattingView.preSendMessages[key]!)
                }

                self.chattingView.initialLoading = true
                
                if (messages?.count)! > 0 {
                    DispatchQueue.main.async {
                        self.chattingView.chattingTableView.reloadData()
                        self.chattingView.chattingTableView.layoutIfNeeded()
                        
                        var viewHeight: CGFloat
                        if self.keyboardShown {
                            viewHeight = self.chattingView.chattingTableView.frame.size.height - 10
                        }
                        else {
                            viewHeight = UIScreen.main.bounds.size.height - self.navigationBarHeight.constant - self.chattingView.inputContainerViewHeight.constant - 10
                        }

                        let contentSize = self.chattingView.chattingTableView.contentSize
                        
                        if contentSize.height > viewHeight {
                            let newContentOffset = CGPoint(x: 0, y: contentSize.height - viewHeight)
                            self.chattingView.chattingTableView.setContentOffset(newContentOffset, animated: false)
                        }
                    }
                }
                
                self.chattingView.initialLoading = false
                self.isLoading = false
            }
            else {
                if (messages?.count)! > 0 {
                    for item in messages! {
                        let message: SBDBaseMessage = item as SBDBaseMessage
                        self.chattingView.messages.insert(message, at: 0)
                        
                        if self.minMessageTimestamp > message.createdAt {
                            self.minMessageTimestamp = message.createdAt
                        }
                    }
                    
                    DispatchQueue.main.async {
                        let contentSizeBefore = self.chattingView.chattingTableView.contentSize
                        
                        self.chattingView.chattingTableView.reloadData()
                        self.chattingView.chattingTableView.layoutIfNeeded()
                        
                        let contentSizeAfter = self.chattingView.chattingTableView.contentSize
                        
                        let newContentOffset = CGPoint(x: 0, y: contentSizeAfter.height - contentSizeBefore.height)
                        self.chattingView.chattingTableView.setContentOffset(newContentOffset, animated: false)
                    }
                }
                
                self.isLoading = false
            }
        }
    }
    
    @objc private func sendMessage() {
        if self.chattingView.messageTextView.text.count > 0 {
            let message = self.chattingView.messageTextView.text
            self.chattingView.messageTextView.text = ""
            
            do {
                let detector: NSDataDetector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
                let matches = detector.matches(in: message!, options: NSRegularExpression.MatchingOptions.init(rawValue: 0), range: NSMakeRange(0, (message?.count)!))
                var url: URL? = nil
                for item in matches {
                    let match = item as NSTextCheckingResult
                    url = match.url
                    break
                }
                
                if url != nil {
                    let tempModel = OutgoingGeneralUrlPreviewTempModel()
                    tempModel.createdAt = Int64(NSDate().timeIntervalSince1970 * 1000)
                    tempModel.message = message
                    
                    self.chattingView.messages.append(tempModel)
                    DispatchQueue.main.async {
                        self.chattingView.chattingTableView.reloadData()
                        DispatchQueue.main.async {
                            self.chattingView.scrollToBottom(force: true)
                        }
                    }
                    return
                }
            }
            catch {
            }
            
            self.chattingView.sendButton.isEnabled = false
            let preSendMessage = self.openChannel.sendUserMessage(message, data: "", customType: "", targetLanguages: [], completionHandler: { (userMessage, error) in
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(150), execute: {
                    let preSendMessage = self.chattingView.preSendMessages[(userMessage?.requestId)!] as! SBDUserMessage
                    self.chattingView.preSendMessages.removeValue(forKey: (userMessage?.requestId)!)
                    
                    if error != nil {
                        self.chattingView.resendableMessages[(userMessage?.requestId)!] = userMessage
                        self.chattingView.chattingTableView.reloadData()
                        DispatchQueue.main.async {
                            self.chattingView.scrollToBottom(force: true)
                        }
                        
                        return
                    }
                    
                    let index = IndexPath(row: self.chattingView.messages.index(of: preSendMessage)!, section: 0)
                    self.chattingView.chattingTableView.beginUpdates()
                    self.chattingView.messages[self.chattingView.messages.index(of: preSendMessage)!] = userMessage!
                    
                    UIView.setAnimationsEnabled(false)
                    self.chattingView.chattingTableView.reloadRows(at: [index], with: UITableViewRowAnimation.none)
                    UIView.setAnimationsEnabled(true)
                    self.chattingView.chattingTableView.endUpdates()
                    
                    DispatchQueue.main.async {
                        self.chattingView.scrollToBottom(force: true)
                    }
                })
            })
            
            self.chattingView.preSendMessages[preSendMessage.requestId!] = preSendMessage
            DispatchQueue.main.async {
                if self.chattingView.preSendMessages[preSendMessage.requestId!] == nil {
                    return
                }
                self.chattingView.chattingTableView.beginUpdates()
                self.chattingView.messages.append(preSendMessage)
                
                UIView.setAnimationsEnabled(false)
                
                self.chattingView.chattingTableView.insertRows(at: [IndexPath(row: self.chattingView.messages.index(of: preSendMessage)!, section: 0)], with: UITableViewRowAnimation.none)
                UIView.setAnimationsEnabled(true)
                self.chattingView.chattingTableView.endUpdates()
                
                DispatchQueue.main.async {
                    self.chattingView.scrollToBottom(force: true)
                    self.chattingView.sendButton.isEnabled = true
                }
            }
        }
    }
    
    @objc func clickReconnect() {
        if SBDMain.getConnectState() != SBDWebSocketConnectionState.open && SBDMain.getConnectState() != SBDWebSocketConnectionState.connecting {
            SBDMain.reconnect()
        }
    }
    
    // MARK: SBDConnectionDelegate
    func didStartReconnection() {
        if self.navItem.titleView != nil && self.navItem.titleView is UILabel {
            DispatchQueue.main.async {
                (self.navItem.titleView as! UILabel).attributedText = Utils.generateNavigationTitle(mainTitle: String(format:"%@(%ld)", self.openChannel.name, self.openChannel.participantCount), subTitle: "ReconnectedSubtitle")
            }
        }
    }
    
    func didSucceedReconnection() {
        self.loadPreviousMessage(initial: true)
        
        self.openChannel.refresh { (error) in
            if error == nil {
                DispatchQueue.main.async {
                    if self.navItem.titleView != nil && self.navItem.titleView is UILabel {
                        (self.navItem.titleView as! UILabel).attributedText = Utils.generateNavigationTitle(mainTitle: String(format:"%@(%ld)", self.openChannel.name, self.openChannel.participantCount), subTitle: "ReconnectedSubtitle")
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1)) {
                        if self.navItem.titleView != nil && self.navItem.titleView is UILabel {
                            (self.navItem.titleView as! UILabel).attributedText = Utils.generateNavigationTitle(mainTitle: String(format:"%@(%ld)", self.openChannel.name, self.openChannel.participantCount), subTitle: "")
                        }
                    }
                }
            }
        }
    }
    
    func didFailReconnection() {
        if self.navItem.titleView != nil && self.navItem.titleView is UILabel {
            DispatchQueue.main.async {
                (self.navItem.titleView as! UILabel).attributedText = Utils.generateNavigationTitle(mainTitle: String(format:"%@(%ld)", self.openChannel.name, self.openChannel.participantCount), subTitle: "Error")
            }
        }
    }
    
    // MARK: SBDChannelDelegate
    func channel(_ sender: SBDBaseChannel, didReceive message: SBDBaseMessage) {
        if sender == self.openChannel {
            
            DispatchQueue.main.async {
                UIView.setAnimationsEnabled(false)
                self.chattingView.messages.append(message)
                self.chattingView.chattingTableView.reloadData()
                UIView.setAnimationsEnabled(true)
                DispatchQueue.main.async {
                    self.chattingView.scrollToBottom(force: false)
                }
            }
        }
    }
    
    func channelDidUpdateReadReceipt(_ sender: SBDGroupChannel) {

    }
    
    func channelDidUpdateTypingStatus(_ sender: SBDGroupChannel) {

    }
    
    func channel(_ sender: SBDGroupChannel, userDidJoin user: SBDUser) {

    }
    
    func channel(_ sender: SBDGroupChannel, userDidLeave user: SBDUser) {

    }
    
    func channel(_ sender: SBDOpenChannel, userDidEnter user: SBDUser) {
        
    }
    
    func channel(_ sender: SBDOpenChannel, userDidExit user: SBDUser) {
        
    }
    
    func channel(_ sender: SBDOpenChannel, userWasMuted user: SBDUser) {
        
    }
    
    func channel(_ sender: SBDOpenChannel, userWasUnmuted user: SBDUser) {
        
    }
    
    func channel(_ sender: SBDOpenChannel, userWasBanned user: SBDUser) {
        
    }
    
    func channel(_ sender: SBDOpenChannel, userWasUnbanned user: SBDUser) {
        
    }
    
    func channelWasFrozen(_ sender: SBDOpenChannel) {
        
    }
    
    func channelWasUnfrozen(_ sender: SBDOpenChannel) {
        
    }
    
    func channelWasChanged(_ sender: SBDBaseChannel) {
        if sender == self.openChannel {
            DispatchQueue.main.async {
                self.navItem.title = String(format:"%@(%ld)", self.openChannel.participantCount)
            }
        }
    }
    
    func channelWasDeleted(_ channelUrl: String, channelType: SBDChannelType) {
        let vc = UIAlertController(title: "Error", message: "Error", preferredStyle: UIAlertControllerStyle.alert)
        let closeAction = UIAlertAction(title: "Error", style: UIAlertActionStyle.cancel) { (action) in
            self.close()
        }
        vc.addAction(closeAction)
        DispatchQueue.main.async {
            self.present(vc, animated: true, completion: nil)
        }
    }
    
    func channel(_ sender: SBDBaseChannel, messageWasDeleted messageId: Int64) {
        if sender == self.openChannel {
            for message in self.chattingView.messages {
                if message.messageId == messageId {
                    self.chattingView.messages.remove(at: self.chattingView.messages.index(of: message)!)
                    DispatchQueue.main.async {
                        self.chattingView.chattingTableView.reloadData()
                    }
                    break
                }
            }
        }
    }
    
    // MARK: ChattingViewDelegate
    func loadMoreMessage(view: UIView) {
        if self.cachedMessage {
            return
        }
        
        self.loadPreviousMessage(initial: false)
    }
    
    func startTyping(view: UIView) {
        
    }
    
    func endTyping(view: UIView) {
        
    }
    
    func hideKeyboardWhenFastScrolling(view: UIView) {
        if self.keyboardShown == false {
            return
        }
        
        DispatchQueue.main.async {
            self.bottomMargin.constant = 0
            self.view.layoutIfNeeded()
            self.chattingView.scrollToBottom(force: false)
        }
        self.view.endEditing(true)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}

class OutgoingGeneralUrlPreviewTempModel: SBDBaseMessage {
    var message: String?
}

