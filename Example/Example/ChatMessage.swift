//
//  ChatMessage.swift
//  Example
//
//  Created by CrazyWisdom on 16/1/1.
//  Copyright © 2016年 emqtt.io. All rights reserved.
//

import Foundation

class ChatMessage {
    let id: UInt16
    let sender: String
    let content: String

    init(sender: String, content: String, id: UInt16) {
        self.sender = sender
        self.content = content
        self.id = id
    }
}
