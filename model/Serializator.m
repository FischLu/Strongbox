//
//  Serializator.m
//  Strongbox
//
//  Created by Strongbox on 20/12/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "Serializator.h"
#import "StreamUtils.h"
#import "LoggingInputStream.h"
#import "Constants.h"
#import "Utils.h"
#import "KeePassDatabase.h"
#import "PwSafeDatabase.h"
#import "Kdbx4Database.h"
#import "Kdb1Database.h"
#import "NSData+Extensions.h"

@implementation Serializator

+ (NSData*_Nullable)getValidationPrefixFromUrl:(NSURL*)url {
    NSInputStream* inputStream = [NSInputStream inputStreamWithURL:url];
    
    [inputStream open];
    
    uint8_t buf[kMinimumDatabasePrefixLengthForValidation];
    NSInteger bytesRead = [inputStream read:buf maxLength:kMinimumDatabasePrefixLengthForValidation];
    
    [inputStream close];
    
    if (bytesRead > 0) {
        return [NSData dataWithBytes:buf length:bytesRead];
    }
    
    return nil;
}

+ (BOOL)isValidDatabase:(NSURL *)url error:(NSError *__autoreleasing  _Nullable *)error {
    NSData* prefix = [Serializator getValidationPrefixFromUrl:url];
    
    return [Serializator isValidDatabaseWithPrefix:prefix error:error];
}
 
+ (BOOL)isValidDatabaseWithPrefix:(NSData *)prefix error:(NSError *__autoreleasing  _Nullable *)error {
    if(prefix == nil) {
        if(error) {
            *error = [Utils createNSError:@"Database Data is Nil" errorCode:-1];
        }
        return NO;
    }
    if(prefix.length == 0) {
        if(error) {
            *error = [Utils createNSError:@"Database Data is zero length" errorCode:-1];
        }
        return NO;
    }

    NSError *pw, *k1, *k2, *k3;
        
    BOOL ret = [PwSafeDatabase isValidDatabase:prefix error:&pw] ||
        [KeePassDatabase isValidDatabase:prefix error:&k1] ||
        [Kdbx4Database isValidDatabase:prefix error:&k2] ||
        [Kdb1Database isValidDatabase:prefix error:&k3];

    if(!ret && error) {
        NSData* prefixBytes = [prefix subdataWithRange:NSMakeRange(0, MIN(12, prefix.length))];
        
        NSString* errorSummary = @"Invalid Database. Debug Info:\n";
        
        NSString* prefix = prefixBytes.hexString;
        
        if([prefix hasPrefix:@"004D534D414D415250435259"]) { 
            NSString* loc = NSLocalizedString(@"error_database_is_encrypted_ms_intune", @"It looks like your database is encrypted by Microsoft InTune probably due to corporate policy.");
            
            errorSummary = loc;
        }
        else {
            errorSummary = [errorSummary stringByAppendingFormat:@"PFX: [%@]\n", prefix];
            errorSummary = [errorSummary stringByAppendingFormat:@"PWS: [%@]\n", pw.localizedDescription];
            errorSummary = [errorSummary stringByAppendingFormat:@"KP:[%@]-[%@]\n", k1.localizedDescription, k2.localizedDescription];
            errorSummary = [errorSummary stringByAppendingFormat:@"KP1: [%@]\n", k3.localizedDescription];
        }
        
        *error = [Utils createNSError:errorSummary errorCode:-1];
    }
    
    return ret;
}

+ (DatabaseFormat)getDatabaseFormat:(NSURL *)url {
    NSData* prefix = [Serializator getValidationPrefixFromUrl:url];
    return [Serializator getDatabaseFormatWithPrefix:prefix];
}

+ (DatabaseFormat)getDatabaseFormatWithPrefix:(NSData *)prefix {
    if(prefix == nil || prefix.length == 0) {
        return kFormatUnknown;
    }
    
    NSError* error;
    if([PwSafeDatabase isValidDatabase:prefix error:&error]) {
        return kPasswordSafe;
    }
    else if ([KeePassDatabase isValidDatabase:prefix error:&error]) {
        return kKeePass;
    }
    else if([Kdbx4Database isValidDatabase:prefix error:&error]) {
        return kKeePass4;
    }
    else if([Kdb1Database isValidDatabase:prefix error:&error]) {
        return kKeePass1;
    }
    
    return kFormatUnknown;
}

+ (NSString*)getLikelyFileExtension:(NSData *)prefix {
    DatabaseFormat format = [Serializator getDatabaseFormatWithPrefix:prefix];
    
    if (format == kPasswordSafe) {
        return [PwSafeDatabase fileExtension];
    }
    else if (format == kKeePass4) {
        return [Kdbx4Database fileExtension];
    }
    else if (format == kKeePass) {
        return [KeePassDatabase fileExtension];
    }
    else if (format == kKeePass1) {
        return [Kdb1Database fileExtension];
    }
    else {
        return @"dat";
    }
}

+ (NSString*)getDefaultFileExtensionForFormat:(DatabaseFormat)format {
    if(format == kPasswordSafe) {
        return [PwSafeDatabase fileExtension];
    }
    else if (format == kKeePass) {
        return [KeePassDatabase fileExtension];
    }
    else if(format == kKeePass4) {
        return [Kdbx4Database fileExtension];
    }
    else if(format == kKeePass1) {
        return [Kdb1Database fileExtension];
    }
    
    return @"dat";
}

+ (id)getAdaptor:(DatabaseFormat)format {
    if(format == kPasswordSafe) {
        return [PwSafeDatabase class];
    }
    else if(format == kKeePass) {
        return [KeePassDatabase class];
    }
    else if(format == kKeePass4) {
        return [Kdbx4Database class];
    }
    else if(format == kKeePass1) {
        return [Kdb1Database class];
    }
    
    NSLog(@"WARN: No such adaptor for format!");
    return nil;
}




+ (NSData *)expressToData:(DatabaseModel *)database format:(DatabaseFormat)format {
    __block NSData* ret;

    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    [Serializator getAsData:database format:format completion:^(BOOL userCancelled, NSData * _Nullable data, NSString * _Nullable debugXml, NSError * _Nullable error) {
        if (userCancelled || error) {
            NSLog(@"Error: expressToData [%@]", error);
        }
        else {
            ret = data;
        }
        dispatch_group_leave(group);
    }];

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    return ret;
}

+ (void)getAsData:(DatabaseModel *)database format:(DatabaseFormat)format completion:(SaveCompletionBlock)completion {
    [database performPreSerializationTidy]; 

    id<AbstractDatabaseFormatAdaptor> adaptor = [Serializator getAdaptor:format];

    [adaptor save:database completion:completion];
}

+ (DatabaseModel *)expressFromData:(NSData *)data password:(NSString *)password {
    return [self expressFromData:data password:password config:DatabaseModelConfig.defaults];
}

+ (DatabaseModel *)expressFromData:(NSData *)data password:(NSString *)password config:(DatabaseModelConfig *)config {
    DatabaseFormat format = [Serializator getDatabaseFormatWithPrefix:data];
    id<AbstractDatabaseFormatAdaptor> adaptor = [Serializator getAdaptor:format];
    if (adaptor == nil) {
       return nil;
    }

    __block DatabaseModel* model = nil;
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    NSInputStream* stream = [NSInputStream inputStreamWithData:data];
    [stream open];
    [adaptor read:stream
              ckf:[CompositeKeyFactors password:password]
    xmlDumpStream:nil
sanityCheckInnerStream:config.sanityCheckInnerStream
       completion:^(BOOL userCancelled, DatabaseModel * _Nullable database, NSError * _Nullable error) {
        [stream close];
      
        if(userCancelled || database == nil || error) {
            NSLog(@"Error: expressFromData = [%@]", error);
            model = nil;
        }
        else {
            model = database;
        }
        
        dispatch_group_leave(group);
    }];

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    return model;
}




+ (void)fromUrlOrLegacyData:(NSURL *)url
                 legacyData:(NSData *)legacyData
                        ckf:(CompositeKeyFactors *)ckf
                     config:(DatabaseModelConfig *)config
                 completion:(void (^)(BOOL, DatabaseModel * _Nullable, const NSError * _Nullable))completion {
    if (url) {
        [Serializator fromUrl:url ckf:ckf config:config completion:completion];
    }
    else {
        [Serializator fromLegacyData:legacyData ckf:ckf config:config completion:completion];
    }
}

+ (void)fromLegacyData:legacyData
                   ckf:(CompositeKeyFactors *)ckf
                config:(DatabaseModelConfig*)config
            completion:(nonnull DeserializeCompletionBlock)completion {
    NSInputStream* stream = [NSInputStream inputStreamWithData:legacyData];
    
    DatabaseFormat format = [Serializator getDatabaseFormatWithPrefix:legacyData];

    [Serializator fromStreamWithFormat:stream
                                    ckf:ckf
                                 config:config
                                 format:format
                          xmlDumpStream:nil
                             completion:completion];
}

+ (void)fromUrl:(NSURL *)url
            ckf:(CompositeKeyFactors *)ckf
         config:(DatabaseModelConfig *)config
     completion:(nonnull DeserializeCompletionBlock)completion {
    [Serializator fromUrl:url ckf:ckf config:config xmlDumpStream:nil  completion:completion];
}

+ (void)fromUrl:(NSURL *)url
            ckf:(CompositeKeyFactors *)ckf
         config:(DatabaseModelConfig *)config
  xmlDumpStream:(NSOutputStream *)xmlDumpStream
     completion:(nonnull DeserializeCompletionBlock)completion {
    DatabaseFormat format = [Serializator getDatabaseFormat:url];
     
    NSInputStream* stream = [NSInputStream inputStreamWithURL:url];
    
    
    
    
    [Serializator fromStreamWithFormat:stream
                                    ckf:ckf
                                 config:config
                                 format:format
                          xmlDumpStream:xmlDumpStream
                             completion:completion];
}

+ (void)fromStreamWithFormat:(NSInputStream *)stream
                         ckf:(CompositeKeyFactors *)ckf
                      config:(DatabaseModelConfig*)config
                      format:(DatabaseFormat)format
               xmlDumpStream:(NSOutputStream*_Nullable)xmlDumpStream
                  completion:(nonnull DeserializeCompletionBlock)completion {
    id<AbstractDatabaseFormatAdaptor> adaptor = [Serializator getAdaptor:format];

    if (adaptor == nil) {
        completion(NO, nil, nil);
        return;
    }
    
    NSTimeInterval startDecryptTime = NSDate.timeIntervalSinceReferenceDate;
    
    [stream open];
        
    [adaptor read:stream
              ckf:ckf
    xmlDumpStream:xmlDumpStream
     sanityCheckInnerStream:config.sanityCheckInnerStream
       completion:^(BOOL userCancelled, DatabaseModel * _Nullable database, NSError * _Nullable error) {
        [stream close];
        
        NSLog(@"====================================== PERF ======================================");
        NSLog(@"DESERIALIZE [%f] seconds", NSDate.timeIntervalSinceReferenceDate - startDecryptTime);
        NSLog(@"====================================== PERF ======================================");

        if(userCancelled || database == nil || error) {
            completion(userCancelled, nil ,error);
        }
        else {
            completion(NO, database, nil);
        }
    }];
}


@end
