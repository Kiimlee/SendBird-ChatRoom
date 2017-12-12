//
//  ChattingView.swift
//  TechnicalChatTest
//
//  Created by Willy Kim on 10/12/2017.
//  Copyright © 2017 Willy Kim. All rights reserved.
//

import UIKit
import SendBirdSDK
import Alamofire
import AlamofireImage
import FLAnimatedImage

protocol ChattingViewDelegate: class {
    func loadMoreMessage(view: UIView)
    func startTyping(view: UIView)
    func endTyping(view: UIView)
    func hideKeyboardWhenFastScrolling(view: UIView)
}

class ChattingView: ReusableViewFromXib, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate {
    @IBOutlet weak var messageTextView: UITextView!
    @IBOutlet weak var chattingTableView: UITableView!
    @IBOutlet weak var inputContainerViewHeight: NSLayoutConstraint!
    var messages: [SBDBaseMessage] = []
    
    var resendableMessages: [String:SBDBaseMessage] = [:]
    var preSendMessages: [String:SBDBaseMessage] = [:]
    
    var resendableFileData: [String:[String:AnyObject]] = [:]
    var preSendFileData: [String:[String:AnyObject]] = [:]

    @IBOutlet weak var fileAttachButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    var stopMeasuringVelocity: Bool = true
    var initialLoading: Bool = true
    
    var delegate: (ChattingViewDelegate)?

    @IBOutlet weak var typingIndicatorContainerViewHeight: NSLayoutConstraint!
    @IBOutlet weak var typingIndicatorImageView: UIImageView!
    @IBOutlet weak var typingIndicatorLabel: UILabel!
    @IBOutlet weak var typingIndicatorContainerView: UIView!
    @IBOutlet weak var typingIndicatorImageHeight: NSLayoutConstraint!
    
    var incomingUserMessageSizingTableViewCell: IncomingUserMessageTableViewCell?
    var outgoingUserMessageSizingTableViewCell: OutgoingUserMessageTableViewCell?

    @IBOutlet weak var placeholderLabel: UILabel!
    
    var lastMessageHeight: CGFloat = 0
    var scrollLock: Bool = false
    
    var lastOffset: CGPoint = CGPoint(x: 0, y: 0)
    var lastOffsetCapture: TimeInterval = 0
    var isScrollingFast: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    func setup() {
        self.chattingTableView.contentInset = UIEdgeInsetsMake(0, 0, 10, 0)
        self.messageTextView.textContainerInset = UIEdgeInsetsMake(15.5, 0, 14, 0)
    }
    
    func initChattingView() {
        self.initialLoading = true
        self.lastMessageHeight = 0
        self.scrollLock = false
        self.stopMeasuringVelocity = false
        
        self.typingIndicatorContainerView.isHidden = true
        self.typingIndicatorContainerViewHeight.constant = 0
        self.typingIndicatorImageHeight.constant = 0
        
        self.messageTextView.delegate = self
        
        self.chattingTableView.register(IncomingUserMessageTableViewCell.nib(), forCellReuseIdentifier: IncomingUserMessageTableViewCell.cellReuseIdentifier())
        self.chattingTableView.register(OutgoingUserMessageTableViewCell.nib(), forCellReuseIdentifier: OutgoingUserMessageTableViewCell.cellReuseIdentifier())
        
        self.chattingTableView.delegate = self
        self.chattingTableView.dataSource = self
        
        self.initSizingCell()
    }
    
    func initSizingCell() {
        self.incomingUserMessageSizingTableViewCell = IncomingUserMessageTableViewCell.nib().instantiate(withOwner: self, options: nil)[0] as? IncomingUserMessageTableViewCell
        self.incomingUserMessageSizingTableViewCell?.isHidden = true
        self.addSubview(self.incomingUserMessageSizingTableViewCell!)
        
        self.outgoingUserMessageSizingTableViewCell = OutgoingUserMessageTableViewCell.nib().instantiate(withOwner: self, options: nil)[0] as? OutgoingUserMessageTableViewCell
        self.outgoingUserMessageSizingTableViewCell?.isHidden = true
        self.addSubview(self.outgoingUserMessageSizingTableViewCell!)
        
    }
    
    func scrollToBottom(force: Bool) {
        if self.messages.count == 0 {
            return
        }
        
        if self.scrollLock == true && force == false {
            return
        }
        
        self.chattingTableView.scrollToRow(at: IndexPath.init(row: self.messages.count - 1, section: 0), at: UITableViewScrollPosition.bottom, animated: false)
    }
    
    func scrollToPosition(position: Int) {
        if self.messages.count == 0 {
            return
        }
        
        self.chattingTableView.scrollToRow(at: IndexPath.init(row: position, section: 0), at: UITableViewScrollPosition.top, animated: false)
    }
    
    func startTypingIndicator(text: String) {
        // Typing indicator
        self.typingIndicatorContainerView.isHidden = false
        self.typingIndicatorLabel.text = text
        
        self.typingIndicatorContainerViewHeight.constant = 26.0
        self.typingIndicatorImageHeight.constant = 26.0
        self.typingIndicatorContainerView.layoutIfNeeded()

        if self.typingIndicatorImageView.isAnimating == false {
            var typingImages: [UIImage] = []
            for i in 1...50 {
                let typingImageFrameName = String.init(format: "%02d", i)
                typingImages.append(UIImage(named: typingImageFrameName)!)
            }
            self.typingIndicatorImageView.animationImages = typingImages
            self.typingIndicatorImageView.animationDuration = 1.5
            
            DispatchQueue.main.async {
                self.typingIndicatorImageView.startAnimating()
            }
        }
    }
    
    func endTypingIndicator() {
        DispatchQueue.main.async {
            self.typingIndicatorImageView.stopAnimating()
        }

        self.typingIndicatorContainerView.isHidden = true
        self.typingIndicatorContainerViewHeight.constant = 0
        self.typingIndicatorImageHeight.constant = 0
        
        self.typingIndicatorContainerView.layoutIfNeeded()
    }
    
    // MARK: UITextViewDelegate
    func textViewDidChange(_ textView: UITextView) {
        if textView == self.messageTextView {
            if textView.text.count > 0 {
                self.placeholderLabel.isHidden = true
                if self.delegate != nil {
                    self.delegate?.startTyping(view: self)
                }
            }
            else {
                self.placeholderLabel.isHidden = false
                if self.delegate != nil {
                    self.delegate?.endTyping(view: self)
                }
            }
        }
    }
    
    // MARK: UITableViewDelegate
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.stopMeasuringVelocity = false
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.stopMeasuringVelocity = true
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == self.chattingTableView {
            if self.stopMeasuringVelocity == false {
                let currentOffset = scrollView.contentOffset
                let currentTime = NSDate.timeIntervalSinceReferenceDate
                
                let timeDiff = currentTime - self.lastOffsetCapture
                if timeDiff > 0.1 {
                    let distance = currentOffset.y - self.lastOffset.y
                    let scrollSpeedNotAbs = distance * 10 / 1000
                    let scrollSpeed = fabs(scrollSpeedNotAbs)
                    if scrollSpeed > 0.5 {
                        self.isScrollingFast = true
                    }
                    else {
                        self.isScrollingFast = false
                    }
                    
                    self.lastOffset = currentOffset
                    self.lastOffsetCapture = currentTime
                }
                
                if self.isScrollingFast {
                    if self.delegate != nil {
                        self.delegate?.hideKeyboardWhenFastScrolling(view: self)
                    }
                }
            }
            
            if scrollView.contentOffset.y + scrollView.frame.size.height + self.lastMessageHeight < scrollView.contentSize.height {
                self.scrollLock = true
            }
            else {
                self.scrollLock = false
            }
            
            if scrollView.contentOffset.y == 0 {
                if self.messages.count > 0 && self.initialLoading == false {
                    if self.delegate != nil {
                        self.delegate?.loadMoreMessage(view: self)
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat = 0
        
        let msg = self.messages[indexPath.row]
        
        if msg is SBDUserMessage {
            let userMessage = msg as! SBDUserMessage
            let sender = userMessage.sender
            
            if sender?.userId == SBDMain.getCurrentUser()?.userId {
                if indexPath.row > 0 {
                    self.outgoingUserMessageSizingTableViewCell?.setPreviousMessage(aPrevMessage: self.messages[indexPath.row - 1])
                }
                else {
                    self.outgoingUserMessageSizingTableViewCell?.setPreviousMessage(aPrevMessage: nil)
                }
                self.outgoingUserMessageSizingTableViewCell?.setModel(aMessage: userMessage)
                height = (self.outgoingUserMessageSizingTableViewCell?.getHeightOfViewCell())!
            }
            else {
                    if indexPath.row > 0 {
                        self.incomingUserMessageSizingTableViewCell?.setPreviousMessage(aPrevMessage: self.messages[indexPath.row - 1])
                    }
                    else {
                        self.incomingUserMessageSizingTableViewCell?.setPreviousMessage(aPrevMessage: nil)
                    }
                    self.incomingUserMessageSizingTableViewCell?.setModel(aMessage: userMessage)
                    height = (self.incomingUserMessageSizingTableViewCell?.getHeightOfViewCell())!
                }
            }
        
        if self.messages.count > 0 && self.messages.count - 1 == indexPath.row {
            self.lastMessageHeight = height
        }
        
        return height
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForFooterInSection section: Int) -> CGFloat {
        return 0
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
    }
    
    // MARK: UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell?
        
        let msg = self.messages[indexPath.row]
        
        if msg is SBDUserMessage {
            let userMessage = msg as! SBDUserMessage
            let sender = userMessage.sender
            
            if sender?.userId == SBDMain.getCurrentUser()?.userId {
                cell = tableView.dequeueReusableCell(withIdentifier: OutgoingUserMessageTableViewCell.cellReuseIdentifier())
                cell?.frame = CGRect(x: (cell?.frame.origin.x)!, y: (cell?.frame.origin.y)!, width: (cell?.frame.size.width)!, height: (cell?.frame.size.height)!)
                if indexPath.row > 0 {
                    (cell as! OutgoingUserMessageTableViewCell).setPreviousMessage(aPrevMessage: self.messages[indexPath.row - 1])
                }
                else {
                    (cell as! OutgoingUserMessageTableViewCell).setPreviousMessage(aPrevMessage: nil)
                }
                (cell as! OutgoingUserMessageTableViewCell).setModel(aMessage: userMessage)
                
                if self.preSendMessages[userMessage.requestId!] != nil {
                    (cell as! OutgoingUserMessageTableViewCell).showSendingStatus()
                }
                else {
                    if self.resendableMessages[userMessage.requestId!] != nil {
                        (cell as! OutgoingUserMessageTableViewCell).showMessageControlButton()
                    }
                    else {
                        (cell as! OutgoingUserMessageTableViewCell).showMessageDate()
                        (cell as! OutgoingUserMessageTableViewCell).showUnreadCount()
                    }
                }
            }
            else {
                cell = tableView.dequeueReusableCell(withIdentifier: IncomingUserMessageTableViewCell.cellReuseIdentifier())
                cell?.frame = CGRect(x: (cell?.frame.origin.x)!, y: (cell?.frame.origin.y)!, width: (cell?.frame.size.width)!, height: (cell?.frame.size.height)!)
                if indexPath.row > 0 {
                    (cell as! IncomingUserMessageTableViewCell).setPreviousMessage(aPrevMessage: self.messages[indexPath.row - 1])
                }
                else {
                    (cell as! IncomingUserMessageTableViewCell).setPreviousMessage(aPrevMessage: nil)
                }
                (cell as! IncomingUserMessageTableViewCell).setModel(aMessage: userMessage)
            }
        }
        return cell!
    }
}

class CustomURLCache: URLCache {
    static let sharedInstance: CustomURLCache = {
        let instance = CustomURLCache(memoryCapacity: 10 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024, diskPath: nil)
        
        URLCache.shared = instance
        
        return instance
    }()
}


extension FLAnimatedImageView {
    func setAnimatedImageWithURL(url: URL, success: ((FLAnimatedImage) -> Void)?, failure: ((Error?) -> Void)?) -> Void {
        let request = URLRequest.init(url: url)
        let session = URLSession.init(configuration: URLSessionConfiguration.default)
        (session.dataTask(with: request) { (data, response, error) in
            if error != nil {
                if failure != nil {
                    failure!(error!)
                }
                
                session.invalidateAndCancel()
                
                return
            }
            
            let resp: HTTPURLResponse = response as! HTTPURLResponse
            if resp.statusCode >= 200 && resp.statusCode < 300 {
                let cachedResponse = CachedURLResponse(response: response!, data: data!)
                CustomURLCache.sharedInstance.storeCachedResponse(cachedResponse, for: request)
                let animatedImage = FLAnimatedImage(animatedGIFData: data)
                
                if animatedImage != nil {
                    if success != nil {
                        success!(animatedImage!)
                    }
                }
                else {
                    if failure != nil {
                        failure!(nil)
                    }
                }
            }
            else {
                if failure != nil {
                    failure!(nil)
                }
            }
            
            session.invalidateAndCancel()
        }).resume()
    }
    
    static func cachedImageForURL(url: URL) -> Data? {
        let request = URLRequest(url: url)
        let cachedResponse: CachedURLResponse? = CustomURLCache.sharedInstance.cachedResponse(for: request)
        if cachedResponse != nil {
            return cachedResponse?.data
        }
        else {
            return nil
        }
    }
}

