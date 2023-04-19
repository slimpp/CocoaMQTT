//
//  ChatLeftMessageCell.swift
//  Example
//
//  Created by CrazyWisdom on 15/12/25.
//  Copyright © 2015年 emqtt.io. All rights reserved.
//

import UIKit

class ChatLeftMessageCell: UITableViewCell {
    @IBOutlet private weak var contentLabel: UILabel! {
        didSet {
            contentLabel.numberOfLines = 0
        }
    }
    @IBOutlet private weak var avatarImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = UITableViewCell.SelectionStyle.none
    }
}
