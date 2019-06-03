//
//  NewSafeFormatController.m
//  Strongbox-iOS
//
//  Created by Mark on 06/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "SelectDatabaseFormatTableViewController.h"
#import "SelectStorageProviderController.h"

@interface SelectDatabaseFormatTableViewController ()

@property (weak, nonatomic) IBOutlet UITableViewCell *cellKeePass2Advanced;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellKeePass2Classic;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPasswordSafe;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellKeePass1;

@end

@implementation SelectDatabaseFormatTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.delegate = self;

    [self bindExistingFormat];
}

- (void)bindExistingFormat {
    self.cellKeePass2Advanced.accessoryType = (self.existingFormat == kKeePass4) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellKeePass2Classic.accessoryType = (self.existingFormat == kKeePass) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellPasswordSafe.accessoryType = (self.existingFormat == kPasswordSafe) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellKeePass1.accessoryType = (self.existingFormat == kKeePass1) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.toolbar.hidden = YES;
    self.navigationController.toolbarHidden = YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    DatabaseFormat selectedFormat;
    
    switch (indexPath.row) {
        case 0:
            selectedFormat = kKeePass4;
            break;
        case 1:
            selectedFormat = kKeePass;
            break;
        case 2:
            selectedFormat = kPasswordSafe;
            break;
        case 3:
            selectedFormat = kKeePass1;
            break;
        default:
            selectedFormat = kKeePass4;
            NSLog(@"WARN: Unknown Index Path!!");
            break;
    }
    
    NSLog(@"Selected: %d", selectedFormat);

    [self bindExistingFormat];
    
    self.onSelectedFormat(selectedFormat);    
}

@end
