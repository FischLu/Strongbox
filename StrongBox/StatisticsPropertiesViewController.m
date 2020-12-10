//
//  StatisticsPropertiesViewController.m
//  Strongbox
//
//  Created by Mark on 21/03/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "StatisticsPropertiesViewController.h"
#import "MutableOrderedDictionary.h"
#import "GenericKeyValueTableViewCell.h"

@interface StatisticsPropertiesViewController ()

@property MutableOrderedDictionary<NSString*, NSString*>* statistics;
@property MutableOrderedDictionary<NSString*, NSString*> *metadataKvps;
@property MutableOrderedDictionary<NSString*, NSString*> *customData;

@end

const static NSUInteger kSectionPropertiesIdx = 0;
const static NSUInteger kSectionStatisticsIdx = 1;
const static NSUInteger kSectionCustomDataIdx = 2;

const static NSUInteger kSectionCount = 3;
static NSString* const kGenericKeyValueCellId = @"GenericKeyValueTableViewCell";

@implementation StatisticsPropertiesViewController

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.tableView registerNib:[UINib nibWithNibName:kGenericKeyValueCellId bundle:nil] forCellReuseIdentifier:kGenericKeyValueCellId];

    [self loadStatistics];
    
    self.metadataKvps = [self.viewModel.database.metadata filteredKvpForUIWithFormat:self.viewModel.database.format];
    
    self.customData = self.viewModel.database.metadata.customData;
}

- (void)loadStatistics {
    self.statistics = [[MutableOrderedDictionary alloc] init];

    self.statistics[NSLocalizedString(@"mac_database_summary_number_of_folders", @"Number of Groups")] = [NSString stringWithFormat:@"%lu", (unsigned long)self.viewModel.database.numberOfGroups];
    self.statistics[NSLocalizedString(@"mac_database_summary_number_of_entries", @"Number of Entries")] = [NSString stringWithFormat:@"%lu", (unsigned long)self.viewModel.database.numberOfRecords];
    self.statistics[NSLocalizedString(@"mac_database_summary_unique_usernames", @"Unique Usernames")] = [NSString stringWithFormat:@"%lu", (unsigned long)[self.viewModel.database.usernameSet count]];
    self.statistics[NSLocalizedString(@"mac_database_summary_unique_passwords", @"Unique Passwords")] = [NSString stringWithFormat:@"%lu", (unsigned long)[self.viewModel.database.passwordSet count]];
    
    if ( self.viewModel.database.mostPopularUsername ) {
        self.statistics[NSLocalizedString(@"mac_database_summary_most_popular_username", @"Most Popular Username")] = self.viewModel.database.mostPopularUsername;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return kSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ( section == kSectionStatisticsIdx ) {
        return self.statistics.count;
    }
    else if ( section == kSectionPropertiesIdx ) {
        return self.metadataKvps.count;
    }
    else if ( section == kSectionCustomDataIdx ) {
        return self.customData.count;
    }
    
    return [super tableView:tableView numberOfRowsInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    GenericKeyValueTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];

    NSString* key = @"";
    NSString* value = @"";

    if ( indexPath.section == kSectionStatisticsIdx ) {
        key = self.statistics.allKeys[indexPath.row];
        value = self.statistics[key];
    }
    else if( indexPath.section == kSectionPropertiesIdx ) {
        key = self.metadataKvps.allKeys[indexPath.row];
        value = self.metadataKvps[key];
    }
    else if ( indexPath.section == kSectionCustomDataIdx ) {
        key = self.customData.allKeys[indexPath.row];
        value = self.customData[key];
    }

    [cell setKey:key value:value editing:NO useEasyReadFont:NO];
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ( section == kSectionStatisticsIdx ) {
        return NSLocalizedString(@"properties_vc_header_statistics", @"Statistics");
    }
    else if ( section == kSectionPropertiesIdx ) {
        return NSLocalizedString(@"properties_vc_header_basic", @"Properties");
    }
    else if ( section == kSectionCustomDataIdx ) {
        return NSLocalizedString(@"properties_vc_header_custom_data", @"Custom Data");
    }
    
    return [super tableView:tableView titleForHeaderInSection:section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if ( section == kSectionStatisticsIdx ) {
        
    }
    else if ( section == kSectionPropertiesIdx ) {
        
    }
    else if ( section == kSectionCustomDataIdx ) {
        return NSLocalizedString(@"properties_vc_footer_custom_data", @"Custom Data used by plugins and various other applications.");
    }

    return [super tableView:tableView titleForFooterInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if ( section == kSectionCustomDataIdx && self.customData.count == 0 ) {
        return CGFLOAT_MIN;
    }
    
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if ( section == kSectionCustomDataIdx && self.customData.count == 0 ) {
        return CGFLOAT_MIN;
    }

    return UITableViewAutomaticDimension;
}

@end
