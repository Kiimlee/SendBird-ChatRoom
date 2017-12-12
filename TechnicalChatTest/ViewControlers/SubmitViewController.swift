//
//  SubmitViewController.swift
//  TechnicalChatTest
//
//  Created by Willy Kim on 10/12/2017.
//  Copyright © 2017 Willy Kim. All rights reserved.
//

import UIKit
import SendBirdSDK

class SubmitViewController: UIViewController {

    @IBOutlet weak var introLabel: UILabel!
    @IBOutlet weak var nicknameTextField: UITextField!
    @IBOutlet weak var idTextField: UITextField!
    @IBOutlet weak var backgroundView: UIView!
    
    private var channels: [SBDOpenChannel] = []
    private var openChannelListQuery: SBDOpenChannelListQuery?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setInterface()
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setInterface() {
        self.introLabel.text = "Please enter the id and nickname\n of your choice"
        self.introLabel.lineBreakMode = .byWordWrapping
        self.introLabel.numberOfLines = 2
        self.introLabel.center.x = self.view.center.x
        self.introLabel.sizeToFit()
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tap(gesture:)))
        self.view.isUserInteractionEnabled = true
        self.view.addGestureRecognizer(tapRecognizer)
        setGradient()
    }
    
    let gradient = CAGradientLayer()

    func setGradient(){
        if self.backgroundView != nil{
            gradient.removeFromSuperlayer()
            let startColor = UIColor(red: 0.0/255.0, green: 186.0/255.0, blue: 255.0/255.0, alpha: 1)
            let endColor = UIColor(red: 67.0/255.0, green: 226.0/255.0, blue: 220.0/255.0, alpha: 1)
            gradient.colors = [endColor.cgColor, startColor.cgColor]
            var backBounds = self.backgroundView!.bounds
            backBounds.size.width = backBounds.size.width + 300
            gradient.frame = backBounds
            gradient.startPoint = CGPoint(x: 0, y: 1)
            gradient.endPoint = CGPoint(x: 1, y: 0)
            self.backgroundView!.backgroundColor = UIColor.clear
            self.backgroundView!.layer.addSublayer(gradient)
        }
    }
    
    @IBAction func getConnected(_ sender: Any) {
        let trimmedNickname: String = (self.nicknameTextField.text?.trimmingCharacters(in: NSCharacterSet.whitespaces))!
        let trimmedId: String = (self.idTextField.text?.trimmingCharacters(in: NSCharacterSet.whitespaces))!

        if trimmedNickname.count > 0 && trimmedId.count > 0{
            if self.nicknameTextField.text?.isEmpty == true || self.idTextField.text?.isEmpty == true {
                self.alertView(text: "One of the text field is empty please enter a nickname/id")
            } else {
                self.nicknameTextField.isEnabled = false
                self.idTextField.isEnabled = false
                
                SBDMain.connect(withUserId: self.idTextField.text!, completionHandler: { (user, error) in
                    if error != nil {
                        self.alertView(text: "Connect failed")
                        DispatchQueue.main.async {
                            self.nicknameTextField.isEnabled = true
                            self.idTextField.isEnabled = false
                        }
                        return
                    }
                    if SBDMain.getPendingPushToken() != nil {
                        SBDMain.registerDevicePushToken(SBDMain.getPendingPushToken()!, unique: true, completionHandler: { (status, error) in
                            if error == nil {
                                if status == SBDPushTokenRegistrationStatus.pending {
                                    print("Push registeration is pending.")
                                }
                                else {
                                    print("APNS Token is registered.")
                                }
                            }
                            else {
                                print("APNS registration failed.")
                            }
                        })
                    }
                    SBDMain.updateCurrentUserInfo(withNickname: trimmedNickname, profileUrl: nil, completionHandler: { (error) in
                        DispatchQueue.main.async {
                            self.nicknameTextField.isEnabled = true
                            self.idTextField.isEnabled = false
                        }
                        
                        if error != nil {
                            // Put alert
                            self.alertView(text: "UpdateCurrentUserInfo failed")
                            SBDMain.disconnect(completionHandler: {
                            })
                            
                            return
                        }
                        UserDefaults.standard.set(SBDMain.getCurrentUser()?.userId, forKey: "sendbird_user_id")
                        UserDefaults.standard.set(SBDMain.getCurrentUser()?.nickname, forKey: "sendbird_user_nickname")
                    })
                    
                    DispatchQueue.main.async {
                        self.getChannelList()
                    }
                })
            }
        }
    }
    
    func alertView(text: String) {
        let alert = UIAlertController(title: "Error", message: text, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func getChannelList() {
        self.openChannelListQuery = SBDOpenChannel.createOpenChannelListQuery()
        self.openChannelListQuery?.limit = 20
        
        self.openChannelListQuery?.loadNextPage(completionHandler: { (channels, error) in
            if error != nil {
                return
            }
            
            for channel in channels! {
                self.channels.append(channel)
            }
            
            self.channels.first?.enter { (error) in
                let vc = OpenChannelChattingViewController(nibName: "OpenChannelChattingViewController", bundle: Bundle.main)
                vc.openChannel = self.channels.first
                DispatchQueue.main.async {
                    self.present(vc, animated: false, completion: nil)
                }
            }
        })
    }
    
    @objc func tap(gesture: UITapGestureRecognizer) {
        self.idTextField.resignFirstResponder()
        self.nicknameTextField.resignFirstResponder()
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
