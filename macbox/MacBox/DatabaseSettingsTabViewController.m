//
//  DatabasePropertiesController.m
//  Strongbox
//
//  Created by Mark on 27/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabaseSettingsTabViewController.h"
#import "DatabaseConvenienceUnlockPreferences.h"
#import "AutoFillSettingsViewController.h"
#import "AutoFillManager.h"
#import "GeneralDatabaseSettings.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

@interface DatabaseSettingsTabViewController () <NSWindowDelegate>

@property ViewModel* viewModel;
@property NSInteger initialTab;

@end

@implementation DatabaseSettingsTabViewController

+ (instancetype)fromStoryboard {
    NSStoryboard* sb = [NSStoryboard storyboardWithName:@"DatabaseProperties" bundle:nil];
    return (DatabaseSettingsTabViewController*)[sb instantiateInitialController];
}

- (void)cancel:(id)sender { 
   [self.view.window close];
}

- (void)viewWillAppear {
    [super viewWillAppear];    
    self.view.window.delegate = self; 
}

- (void)setModel:(ViewModel *)model initialTab:(NSInteger)initialTab {
    self.viewModel = model;
    self.initialTab = initialTab;
    
    [self initializeTabs];
}

- (void)initializeTabs {
    NSTabViewItem* generalItem = self.tabViewItems[0];
    NSTabViewItem* convenienceUnlockItem = self.tabViewItems[1];
    NSTabViewItem* autoFillItem = self.tabViewItems[2];
    NSTabViewItem* advanced = self.tabViewItems[3];

    GeneralDatabaseSettings* general = (GeneralDatabaseSettings*)generalItem.viewController;
    general.model = self.viewModel;
    
    DatabaseConvenienceUnlockPreferences* preferences = (DatabaseConvenienceUnlockPreferences*)convenienceUnlockItem.viewController;
    preferences.model = self.viewModel;

    AdvancedDatabasePreferences* advancedPreferences = (AdvancedDatabasePreferences*)advanced.viewController;
    advancedPreferences.model = self.viewModel;

    NSViewController* iv = autoFillItem.viewController;
    AutoFillSettingsViewController* af = (AutoFillSettingsViewController*)iv;
    af.model = self.viewModel;

    self.selectedTabViewItemIndex = self.initialTab;
}

@end
