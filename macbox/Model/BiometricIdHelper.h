//
//  BiometricIdHelper.h
//  Macbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MacDatabasePreferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface BiometricIdHelper : NSObject

+ (instancetype)sharedInstance;

- (void)authorize:(MacDatabasePreferences*)database completion:(void (^)(BOOL success, NSError *error))completion;
- (void)authorize:(NSString * _Nullable)fallbackTitle database:(MacDatabasePreferences*)database completion:(void (^)(BOOL, NSError *))completion;
- (void)authorize:(NSString * _Nullable)fallbackTitle
           reason:(NSString * _Nullable)reason
         database:(MacDatabasePreferences *)database
       completion:(void (^)(BOOL, NSError *))completion;

@property (readonly) BOOL isTouchIdUnlockAvailable;
@property (readonly) BOOL isWatchUnlockAvailable;
@property (readonly) NSString* biometricIdName;

@property BOOL dummyMode;
@property BOOL biometricsInProgress;

@end

NS_ASSUME_NONNULL_END
