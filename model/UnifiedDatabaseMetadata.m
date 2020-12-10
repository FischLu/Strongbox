//
//  UnifiedDatabaseMetadata.m
//  Strongbox
//
//  Created by Strongbox on 05/12/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UnifiedDatabaseMetadata.h"
#import "KeePassConstants.h"
#import "PwSafeSerialization.h"
#import "PwSafeDatabase.h"
#import "Argon2KdfCipher.h"
#import "NSUUID+Zero.h"
#import "KeePassCiphers.h"
#import "Utils.h"
#import "NSDate+Extensions.h"

static const uint32_t kKdb1DefaultVersion = 0x00030004;

static NSString* const kKdb4DefaultFileVersion = @"4.0";
static const uint32_t kKdb4DefaultInnerRandomStreamId = kInnerStreamChaCha20;

static NSString* const kKP3DefaultFileVersion = @"3.1";
static const uint32_t kKP3DefaultInnerRandomStreamId = kInnerStreamSalsa20;

@implementation UnifiedDatabaseMetadata

+ (instancetype)withDefaultsForFormat:(DatabaseFormat)format {
    return [[UnifiedDatabaseMetadata alloc] initWithDefaultsForFormat:format];
}

- (instancetype)initWithDefaultsForFormat:(DatabaseFormat)format {
    self = [super init];
    
    if (self) {
        self.transformRounds = kDefaultTransformRounds; 
        self.generator = kStrongboxGenerator;
        self.compressionFlags = kGzipCompressionFlag;
        self.cipherUuid = aesCipherUuid();
        self.historyMaxItems = @(kDefaultHistoryMaxItems);
        self.historyMaxSize = @(kDefaultHistoryMaxSize);
        self.recycleBinEnabled = YES;
        self.recycleBinGroup = NSUUID.zero;
        self.recycleBinChanged = [NSDate date];
        self.kdfParameters = [[Argon2KdfCipher alloc] initWithDefaults].kdfParameters; 
        self.flags = kFlagsAes | kFlagsSha2; 
        self.versionInt = kKdb1DefaultVersion; 
        self.keyStretchIterations = DEFAULT_KEYSTRETCH_ITERATIONS; 
        self.innerRandomStreamId = kKdb4DefaultInnerRandomStreamId; 

        
        
        if ( format == kPasswordSafe ) {
            self.recycleBinEnabled = NO;
            self.version = [NSString stringWithFormat:@"%ld.%ld", (long)kPwSafeDefaultVersionMajor, (long)kPwSafeDefaultVersionMinor];
        }
        else if ( format == kKeePass4 ) {
            self.version = kKdb4DefaultFileVersion;
        }
        else if ( format == kKeePass ) {
            self.version = kKP3DefaultFileVersion;
            self.innerRandomStreamId = kKP3DefaultInnerRandomStreamId;
        }
        else if (format == kKeePass1) {
            self.recycleBinEnabled = NO; 
        }
        else {
            NSLog(@"WARNWARN: No DEFAULTS set for this format! WARNWARN");
        }
    }
    
    return self;
}

- (MutableOrderedDictionary<NSString *,NSString *> *)filteredKvpForUIWithFormat:(DatabaseFormat)format {
    if ( format == kKeePass1 ) {
        return [self kvpForUiKdb1];
    }
    else if ( format == kPasswordSafe ) {
        return [self kvpForUiPSafe3];
    }
    else if ( format == kKeePass4 ) {
        return [self kvpForUiKp4];
    }
    else if ( format == kKeePass ) {
        return [self kvpForUiKp];
    }
    else {
        NSLog(@"WARNWARN: No kvpForUi set for this format! WARNWARN");
        return nil;
    }
}

- (MutableOrderedDictionary<NSString*, NSString*>*)kvpForUiKdb1 {
    MutableOrderedDictionary<NSString*, NSString*>* kvps = [[MutableOrderedDictionary alloc] init];
    
    kvps[NSLocalizedString(@"database_metadata_field_format", @"Database Format")] = @"KeePass 1";
    kvps[NSLocalizedString(@"database_metadata_field_outer_encryption", @"Outer Encryption")] = ((self.flags & kFlagsAes) == kFlagsAes) ? @"AES-256" : @"TwoFish";
    kvps[NSLocalizedString(@"database_metadata_field_transform_rounds", @"Transform Rounds")] = [NSString stringWithFormat:@"%u", (uint32_t)self.transformRounds];
    
    return kvps;
}

- (MutableOrderedDictionary<NSString*, NSString*>*)kvpForUiPSafe3 {
    MutableOrderedDictionary<NSString*, NSString*>* kvps = [[MutableOrderedDictionary alloc] init];
    
    [kvps addKey:NSLocalizedString(@"database_metadata_field_format", @"Database Format")
        andValue:@"Password Safe 3"];
    
    [kvps addKey:NSLocalizedString(@"database_metadata_field_password_safe_version", @"Password Safe File Version")  andValue:self.version];
    
    [kvps addKey:NSLocalizedString(@"database_metadata_field_password_key_stretch_iterations", @"Key Stretch Iterations")
        andValue:[NSString stringWithFormat:@"%lu", (unsigned long)self.keyStretchIterations]];
    
    if (self.lastUpdateTime) {
        [kvps addKey:NSLocalizedString(@"database_metadata_field_last_update_time", @"Last Update Time")
            andValue:self.lastUpdateTime.friendlyDateString]; 
    }
    
    if (self.lastUpdateUser.length) {
        [kvps addKey:NSLocalizedString(@"database_metadata_field_last_update_user", @"Last Update User")
            andValue:self.lastUpdateUser];
    }
    
    [kvps addKey:NSLocalizedString(@"database_metadata_field_last_update_host", @"Last Update Host")
        andValue:self.lastUpdateHost];
    [kvps addKey:NSLocalizedString(@"database_metadata_field_last_update_app", @"Last Update App")
        andValue:self.lastUpdateApp];

    return kvps;
}

- (MutableOrderedDictionary<NSString*, NSString*>*)kvpForUiKp4 {
    MutableOrderedDictionary<NSString*, NSString*>* kvps = [[MutableOrderedDictionary alloc] init];

    [kvps addKey:NSLocalizedString(@"database_metadata_field_format", @"Database Format") andValue:@"KeePass 2"];
    [kvps addKey:NSLocalizedString(@"database_metadata_field_keepass_version", @"KeePass File Version")  andValue:self.version];
    [kvps addKey:NSLocalizedString(@"database_metadata_field_generator", @"Database Generator") andValue:self.generator];
    
    [kvps addKey:NSLocalizedString(@"database_metadata_field_key_derivation", @"Key Derivation") andValue:keyDerivationAlgorithmString(self.kdfParameters.uuid)];
    
    if([self.kdfParameters.uuid isEqual:argon2CipherUuid()]) {
        static NSString* const kParameterMemory = @"M";
        VariantObject* vo = self.kdfParameters.parameters[kParameterMemory];
        if(vo && vo.theObject) {
            uint64_t memory = ((NSNumber*)vo.theObject).longLongValue;

            [kvps addKey:NSLocalizedString(@"database_metadata_field_argon2_memory", @"Argon 2 Memory") andValue:friendlyMemorySizeString(memory)];
        }
    }
    
    [kvps addKey:NSLocalizedString(@"database_metadata_field_outer_encryption", @"Outer Encryption") andValue:outerEncryptionAlgorithmString(self.cipherUuid)];
    [kvps addKey:NSLocalizedString(@"database_metadata_field_compressed", @"Compressed")  andValue:localizedYesOrNoFromBool( self.compressionFlags == kGzipCompressionFlag)];
    [kvps addKey:NSLocalizedString(@"database_metadata_field_inner_encryption", @"Inner Encryption") andValue:innerEncryptionString(self.innerRandomStreamId)];
    
    if(self.historyMaxItems != nil) {
        [kvps addKey:NSLocalizedString(@"database_metadata_field_max_history_items", @"Max History Items") andValue:[NSString stringWithFormat:@"%ld", self.historyMaxItems.longValue]];
    }
    
    if(self.historyMaxSize != nil) {
        NSString* size = friendlyMemorySizeString(self.historyMaxSize.integerValue);
        [kvps addKey:NSLocalizedString(@"database_metadata_field_max_history_size", @"Max History Size") andValue:size];
    }
    
    [kvps addKey:NSLocalizedString(@"database_metadata_field_recycle_bin_enabled", @"Recycle Bin Enabled") andValue:localizedYesOrNoFromBool(self.recycleBinEnabled)];
    
    return kvps;
}

- (MutableOrderedDictionary<NSString*, NSString*>*)kvpForUiKp {
    MutableOrderedDictionary<NSString*, NSString*>* kvps = [[MutableOrderedDictionary alloc] init];
    
    [kvps addKey:NSLocalizedString(@"database_metadata_field_format", @"Database Format") andValue:@"KeePass 2"];
    [kvps addKey:NSLocalizedString(@"database_metadata_field_keepass_version", @"KeePass File Version")  andValue:self.version];
    [kvps addKey:NSLocalizedString(@"database_metadata_field_generator", @"Database Generator") andValue:self.generator];
    [kvps addKey:NSLocalizedString(@"database_metadata_field_outer_encryption", @"Outer Encryption") andValue:outerEncryptionAlgorithmString(self.cipherUuid)];
    [kvps addKey:NSLocalizedString(@"database_metadata_field_compressed", @"Compressed")  andValue:localizedYesOrNoFromBool(self.compressionFlags == kGzipCompressionFlag)];
    [kvps addKey:NSLocalizedString(@"database_metadata_field_transform_rounds", @"Transform Rounds") andValue:[NSString stringWithFormat:@"%llu", self.transformRounds]];

    [kvps addKey:NSLocalizedString(@"database_metadata_field_inner_encryption", @"Inner Encryption") andValue:innerEncryptionString(self.innerRandomStreamId)];

    if(self.historyMaxItems != nil) {
        [kvps addKey:NSLocalizedString(@"database_metadata_field_max_history_items", @"Max History Items") andValue:[NSString stringWithFormat:@"%ld", self.historyMaxItems.longValue]];
    }
    
    if(self.historyMaxSize != nil) {
        NSString* size = friendlyMemorySizeString(self.historyMaxSize.integerValue);
        [kvps addKey:NSLocalizedString(@"database_metadata_field_max_history_size", @"Max History Size") andValue:size];
    }
    
    [kvps addKey:NSLocalizedString(@"database_metadata_field_recycle_bin_enabled", @"Recycle Bin Enabled") andValue:localizedYesOrNoFromBool(self.recycleBinEnabled)];
    
    return kvps;
}


@end
