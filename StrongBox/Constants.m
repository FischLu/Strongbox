//
//  Constants.m
//  Strongbox
//
//  Created by Strongbox on 22/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Constants.h"
#import "Utils.h"

@implementation Constants

const NSInteger kStorageProviderSFTPorWebDAVSecretMissingErrorCode = 172924134;

const NSInteger kStorageProviderUserInteractionRequiredErrorCode = 17292412;
NSString* const kStorageProviderUserInteractionRequiredErrorMessage = @"User Interaction Required";
const NSError* kUserInteractionRequiredError;
const NSUInteger kMinimumDatabasePrefixLengthForValidation = 192;
const NSUInteger kStreamingSerializationChunkSize = 128 * 1024; 
const size_t kMaxAttachmentTableviewIconImageSize = 4 * 1024 * 1024;

static NSString * const kMacProEditionBundleId = @"com.markmcguill.strongbox.mac.pro";
static NSString * const kProEditionBundleId = @"com.markmcguill.strongbox.pro";
static NSString * const kScotusEditionBundleId = @"com.markmcguill.strongbox.scotus";
static NSString * const kGrapheneEditionBundleId = @"com.markmcguill.strongbox.graphene";

NSString* const kCanonicalEmailFieldName = @"Email";
NSString* const kCanonicalFavouriteTag = @"Favorite";

+(void)initialize {
    if(self == [Constants class]) {
        kUserInteractionRequiredError = [Utils createNSError:kStorageProviderUserInteractionRequiredErrorMessage errorCode:kStorageProviderUserInteractionRequiredErrorCode];
    }
}

+ (NSString *)macProEditionBundleId {
    return kMacProEditionBundleId;
}

+ (NSString *)proEditionBundleId {
    return kProEditionBundleId;
}

+ (NSString *)scotusEditionBundleId {
    return kScotusEditionBundleId;
}

+ (NSString *)grapheneEditionBundleId {
    return kGrapheneEditionBundleId;
}

NSString* const kStrongboxPasteboardName = @"Strongbox-Pasteboard";
NSString* const kDragAndDropSideBarHeaderMoveInternalUti = @"com.markmcguill.strongbox.drag.and.drop.sidebar.header.move.internal.uti";
NSString* const kDragAndDropInternalUti = @"com.markmcguill.strongbox.drag.and.drop.internal.uti";
NSString* const kDragAndDropExternalUti = @"com.markmcguill.strongbox.drag.and.drop.external.uti";

@end