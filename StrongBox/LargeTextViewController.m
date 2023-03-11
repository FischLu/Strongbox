//
//  LargeTextViewController.m
//  Strongbox
//
//  Created by Mark on 23/10/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "LargeTextViewController.h"
#import "FontManager.h"
#import "ColoredStringHelper.h"
#import "AppPreferences.h"
#import "Utils.h"

@interface LargeTextViewController ()

@property (weak, nonatomic) IBOutlet UILabel *labelLargeText;
@property (weak, nonatomic) IBOutlet UIImageView *qrCodeImageView;
@property (weak, nonatomic) IBOutlet UIButton *buttonShowQrCode;

@end

@implementation LargeTextViewController

+ (instancetype)fromStoryboard {
    UIStoryboard* sb = [UIStoryboard storyboardWithName:@"LargeTextView" bundle:nil];
    return [sb instantiateInitialViewController];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.buttonShowQrCode setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
       
    UIImage* img = [Utils getQrCode:self.string pointSize:self.qrCodeImageView.frame.size.width];
    self.qrCodeImageView.image = img;
    self.qrCodeImageView.hidden = NO;
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(labelTapped)];
    
    tapGestureRecognizer.numberOfTapsRequired = 1;
    
    [self.labelLargeText addGestureRecognizer:tapGestureRecognizer];
    self.labelLargeText.userInteractionEnabled = YES;

    if (!self.colorize) {
        self.labelLargeText.font = FontManager.sharedInstance.easyReadFontForTotp;
        self.labelLargeText.text = self.string;
    }
    else {
        BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        BOOL colorBlind = AppPreferences.sharedInstance.colorizeUseColorBlindPalette;
    
        self.labelLargeText.attributedText = [ColoredStringHelper getColorizedAttributedString:self.string
                                                                                      colorize:YES
                                                                                      darkMode:dark
                                                                                    colorBlind:colorBlind font:FontManager.sharedInstance.easyReadFontForTotp];
    }
}

- (IBAction)onDismiss:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)labelTapped {
}

- (IBAction)onShowQrCode:(id)sender {
    self.qrCodeImageView.hidden = !self.qrCodeImageView.hidden;
}

@end
