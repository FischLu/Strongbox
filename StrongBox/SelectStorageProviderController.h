//
//  SelectStorageProviderController.h
//  StrongBox
//
//  Created by Mark on 08/09/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AbstractDatabaseFormatAdaptor.h"
#import "SelectedStorageParameters.h"

typedef void (^SelectStorageCompletion)(SelectedStorageParameters *params);

@interface SelectStorageProviderController : UITableViewController

@property (nonatomic) BOOL existing;
@property (nonatomic, copy) SelectStorageCompletion onDone;

@end
