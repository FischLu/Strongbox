//
//  HeaderWithTextButton.swift
//  MacBox
//
//  Created by Strongbox on 27/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Cocoa

class HeaderWithTextButton: NSTableCellView {
    @IBOutlet var labelHeader: NSTextField!
    @IBOutlet weak var button: ClickableTextField!
    
    override func awakeFromNib() {
    }
    
    var onButtonClickedCallback : (() -> Void)?
    var field: DetailsViewField?
    
    func setContent(_ field: DetailsViewField,
                    onButtonClicked: (() -> Void)? = nil) {
        self.field = field
        
        labelHeader.stringValue = field.name
        button.stringValue = field.value
        
        self.onButtonClickedCallback = onButtonClicked

        button.onClick = { [weak self] in
            self?.onClicked()
        }
    }
        
    func onClicked() {
        
        
        if let onButtonClickedCallback {
            onButtonClickedCallback()
        }
    }
}
