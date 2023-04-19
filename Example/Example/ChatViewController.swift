//
//  ChatViewController.swift
//  Example
//
//  Created by CrazyWisdom on 15/12/24.
//  Copyright © 2015年 emqtt.io. All rights reserved.
//

import CocoaMQTT
import UIKit

class ChatViewController: UIViewController {
    var animal: String? {
        didSet {
            animalAvatarImageView.image = UIImage(named: animal!)
            if let animal = animal {
                switch animal {
                case "Sheep":
                    sloganLabel.text = "Four legs good, two legs bad."
                case "Pig":
                    sloganLabel.text = "All animals are equal."
                case "Horse":
                    sloganLabel.text = "I will work harder."
                default:
                    break
                }
            }
        }
    }

    var mqtt5: CocoaMQTT5?
    var mqtt: CocoaMQTT?
    var client: String?
    var mqttVersion: String?

    var messages: [ChatMessage] = [] {
        didSet {
            tableView.reloadData()
            scrollToBottom()
        }
    }

    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var messageTextView: UITextView! {
        didSet {
            messageTextView.layer.cornerRadius = 5
        }
    }
    @IBOutlet private weak var animalAvatarImageView: UIImageView!
    @IBOutlet private weak var sloganLabel: UILabel!

    @IBOutlet private weak var messageTextViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var inputViewBottomConstraint: NSLayoutConstraint!

    @IBOutlet private weak var sendMessageButton: UIButton! {
        didSet {
            sendMessageButton.isEnabled = false
        }
    }

    @IBAction private func sendMessage() {
        let message = messageTextView.text

        let publishProperties = MqttPublishProperties()
        publishProperties.contentType = "JSON"

        if mqttVersion == "3.1.1" {
            mqtt!.publish("chat/room/animals/client/" + animal!, withString: message!, qos: .qos1)
        } else if mqttVersion == "5.0" {
            mqtt5!.publish("chat/room/animals/client/" + animal!, withString: message!, qos: .qos1, DUP: true, retained: false, properties: publishProperties)
        }

        messageTextView.text = ""
        sendMessageButton.isEnabled = false
        messageTextViewHeightConstraint.constant = messageTextView.contentSize.height
        messageTextView.layoutIfNeeded()
        view.endEditing(true)
    }

    @IBAction private func disconnect() {
        if mqttVersion == "3.1.1" {
            mqtt!.disconnect()
        } else if mqttVersion == "5.0" {
            mqtt5!.disconnect()
            // or
            // mqtt5!.disconnect(reasonCode: CocoaMQTTDISCONNECTReasonCode.disconnectWithWillMessage, userProperties: ["userone":"hi"])
        }

        _ = navigationController?.popViewController(animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.isHidden = true
        animal = tabBarController?.selectedViewController?.tabBarItem.title

        // automaticallyAdjustsScrollViewInsets = false
        if #available(iOS 11.0, *) {
            self.tableView.contentInsetAdjustmentBehavior = .never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }

        messageTextView.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 50

        let name = NSNotification.Name(rawValue: "MQTTMessageNotification" + animal!)

        if mqttVersion == "3.1.1" {
            NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.receivedMessage(notification:)), name: name, object: nil)
        } else if mqttVersion == "5.0" {
            NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.receivedMqtt5Message(notification:)), name: name, object: nil)
        }

        let disconnectNotification = NSNotification.Name(rawValue: "MQTTMessageNotificationDisconnect")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ChatViewController.disconnectMessage(notification:)),
            name: disconnectNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ChatViewController.keyboardChanged(notification:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func keyboardChanged(notification: NSNotification) {
        let userInfo = notification.userInfo as! [String: AnyObject]
        let keyboardValue = userInfo["UIKeyboardFrameEndUserInfoKey"]
        let bottomDistance = UIScreen.main.bounds.size.height -
            (navigationController?.navigationBar.frame.height)! - keyboardValue!.cgRectValue.origin.y

        if bottomDistance > 0 {
            inputViewBottomConstraint.constant = bottomDistance
        } else {
            inputViewBottomConstraint.constant = 0
        }
        view.layoutIfNeeded()
    }

    @objc func disconnectMessage(notification: NSNotification) {
        disconnect()
    }

    @objc func receivedMessage(notification: NSNotification) {
        let userInfo = notification.userInfo as! [String: AnyObject]
        let content = userInfo["message"] as! String
        let topic = userInfo["topic"] as! String
        let id = UInt16(userInfo["id"] as! UInt16)
        let sender = topic.replacingOccurrences(of: "chat/room/animals/client/", with: "")
        let chatMessage = ChatMessage(sender: sender, content: content, id: id)
        messages.append(chatMessage)
    }

    @objc func receivedMqtt5Message(notification: NSNotification) {
        let userInfo = notification.userInfo as! [String: AnyObject]
        let message = userInfo["message"] as! String
        let topic = userInfo["topic"] as! String
        let id = UInt16(userInfo["id"] as! UInt16)
        // let sender = userInfo["animal"] as! String
        let sender = topic.replacingOccurrences(of: "chat/room/animals/client/", with: "")
        let content = String(message.filter { !"\0".contains($0) })
        let chatMessage = ChatMessage(sender: sender, content: content, id: id)
        print("sendersendersender =  \(sender)")
        messages.append(chatMessage)
    }

    func scrollToBottom() {
        let count = messages.count
        if count > 3 {
            let indexPath = IndexPath(row: count - 1, section: 0)
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }
}

extension ChatViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        if textView.contentSize.height != textView.frame.size.height {
            let textViewHeight = textView.contentSize.height
            if textViewHeight < 100 {
                messageTextViewHeightConstraint.constant = textViewHeight
                textView.layoutIfNeeded()
            }
        }

        if textView.text.isEmpty {
            sendMessageButton.isEnabled = false
        } else {
            sendMessageButton.isEnabled = true
        }
    }
}

extension ChatViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = messages[indexPath.row]
        let animal = String(describing: tabBarController?.selectedViewController?.tabBarItem.title!)
        print("message.sender: \(message.sender)    animal:\(animal)   message.content:\( message.content)"   )

        if message.sender == animal {
            let cell = tableView.dequeueReusableCell(withIdentifier: "rightMessageCell", for: indexPath) as! ChatRightMessageCell
            cell.contentLabel.text = message.content
            cell.avatarImageView.image = UIImage(named: animal!)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "leftMessageCell", for: indexPath) as! ChatLeftMessageCell
            cell.contentLabel.text = message.content
            cell.avatarImageView.image = UIImage(named: "other")
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        view.endEditing(true)
    }
}
