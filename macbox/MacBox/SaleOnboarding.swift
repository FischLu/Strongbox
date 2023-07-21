//
//  SaleOnboarding.swift
//  MacBox
//
//  Created by Strongbox on 18/07/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Cocoa

@available(macOS 11.0, *)
class SaleOnboardingModule: OnboardingModule {
    var isAppModal: Bool = false
    var window: NSWindow? = nil
    
    var shouldDisplay: Bool {
        return false
    }
    
    var windowController : NSWindowController? = nil
    
    func instantiateViewController(completion: @escaping (() -> Void)) -> NSViewController {
        let ret = SwiftUIViewFactory.makeSaleOfferViewController(saleEndDate: Date(), existingSubscriber: false) { [weak self] in
            self?.redeemSale()
        } onLifetimeHandler: { [weak self] in
            self?.showLifetimePurchaseScreen()
        } dismissHandler: {
            completion()
        }
        
        return ret
    }

    func redeemSale ( ) {


    }
    
    func showLifetimePurchaseScreen ( ) {







        
        
    }
}
