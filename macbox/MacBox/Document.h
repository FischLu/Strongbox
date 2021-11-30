//
//  Document.h
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AbstractDatabaseFormatAdaptor.h"
#import "CompositeKeyFactors.h"
#import "DatabaseMetadata.h"
#import "ViewModel.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kModelUpdateNotificationLongRunningOperationStart; 
extern NSString* const kModelUpdateNotificationLongRunningOperationDone;
extern NSString* const kModelUpdateNotificationFullReload;
extern NSString* const kModelUpdateNotificationDatabaseChangedByOther;
extern NSString* const kModelUpdateNotificationSyncDone;
extern NSString* const kNotificationUserInfoParamKey;
extern NSString* const kNotificationUserInfoLongRunningOperationStatus;

@interface Document : NSDocument

@property (readonly) ViewModel* viewModel;
@property (readonly, nullable) DatabaseMetadata* databaseMetadata;
@property (nullable) NSString* selectedItem;
@property BOOL wasJustLocked; 

- (void)lock:(NSString*)selectedItem;



- (void)revertWithUnlock:(CompositeKeyFactors *)compositeKeyFactors
          viewController:(NSViewController*)viewController
         fromConvenience:(BOOL)fromConvenience
              completion:(void (^)(BOOL success, BOOL userCancelled, BOOL incorrectCredentials, NSError* error))completion;

- (void)revertWithUnlock:(CompositeKeyFactors *)compositeKeyFactors
          viewController:(NSViewController *)viewController
     alertOnJustPwdWrong:(BOOL)alertOnJustPwdWrong
         fromConvenience:(BOOL)fromConvenience
              completion:(void (^)(BOOL success, BOOL userCancelled, BOOL incorrectCredentials, NSError* error))completion;

- (void)performFullInteractiveSync:(NSViewController*)viewController key:(CompositeKeyFactors*)key;

- (void)reloadFromLocalWorkingCopy:(CompositeKeyFactors *)key
                    viewController:(NSViewController*)viewController
                      selectedItem:(NSString *)selectedItem;

@property (readonly) BOOL isModelLocked;
- (void)checkForRemoteChanges;
     
@end

NS_ASSUME_NONNULL_END

