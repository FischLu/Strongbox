//
//  SafeViewModel.m
//  StrongBox
//
//  Created by Mark McGuill on 20/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "Model.h"
#import "Utils.h"
#import "AutoFillManager.h"
#import "PasswordMaker.h"
#import "BackupsManager.h"
#import "NSArray+Extensions.h"
#import "DatabaseAuditor.h"
#import "Serializator.h"
#import "SampleItemsGenerator.h"
#import "DatabaseUnlocker.h"
#import "ConcurrentMutableStack.h"
#import "FileManager.h"
#import "CrossPlatform.h"

NSString* const kAuditNodesChangedNotificationKey = @"kAuditNodesChangedNotificationKey";
NSString* const kAuditProgressNotificationKey = @"kAuditProgressNotificationKey";
NSString* const kAuditCompletedNotificationKey = @"kAuditCompletedNotificationKey";
NSString* const kCentralUpdateOtpUiNotification = @"kCentralUpdateOtpUiNotification";
NSString* const kMasterDetailViewCloseNotification = @"kMasterDetailViewClose";
NSString* const kDatabaseViewPreferencesChangedNotificationKey = @"kDatabaseViewPreferencesChangedNotificationKey";
NSString* const kProStatusChangedNotificationKey = @"proStatusChangedNotification";
NSString* const kAppStoreSaleNotificationKey = @"appStoreSaleNotification";
NSString *const kWormholeAutoFillUpdateMessageId = @"auto-fill-workhole-message-id";

NSString* const kDatabaseReloadedNotificationKey = @"kDatabaseReloadedNotificationKey";
NSString* const kAsyncUpdateDone = @"kAsyncUpdateDone";
NSString* const kAsyncUpdateStarting = @"kAsyncUpdateStarting";

@interface Model ()

@property NSSet<NSString*> *cachedPinned;
@property DatabaseAuditor* auditor;
@property BOOL isAutoFillOpen;
@property BOOL forcedReadOnly;
@property BOOL isDuressDummyMode;
@property DatabaseModel* theDatabase;
@property BOOL offlineMode;

@property dispatch_queue_t asyncUpdateEncryptionQueue;
@property ConcurrentMutableStack* asyncUpdatesStack;

@property (readonly) id<ApplicationPreferences> applicationPreferences;
@property (readonly) id<SyncManagement> syncManagement;
@property (readonly) id<SpinnerUI> spinnerUi;
@property (readonly) id<DatabasePreferencesManager> databasesPreferencesManager;

@end

@implementation Model

- (id<ApplicationPreferences>)applicationPreferences {
    return CrossPlatformDependencies.defaults.applicationPreferences;
}

- (id<SyncManagement>)syncManagement {
    return CrossPlatformDependencies.defaults.syncManagement;
}

- (id<SpinnerUI>)spinnerUi {
    return CrossPlatformDependencies.defaults.spinnerUi;
}

- (id<DatabasePreferencesManager>)databasesPreferencesManager {
    return CrossPlatformDependencies.defaults.databasesPreferencesManager;
}



- (NSData*)getDuressDummyData {
    return self.applicationPreferences.duressDummyData; 
}

- (void)setDuressDummyData:(NSData*)data {
    self.applicationPreferences.duressDummyData = data;
}

- (void)dealloc {
    NSLog(@"=====================================================================");
    NSLog(@"Model DEALLOC...");
    NSLog(@"=====================================================================");
}

- (void)closeAndCleanup { 
    NSLog(@"Model closeAndCleanup...");
    if (self.auditor) {
        [self.auditor stop];
        self.auditor = nil;
    }
}

#if TARGET_OS_IPHONE

- (instancetype)initAsDuressDummy:(BOOL)isAutoFillOpen
                 templateMetaData:(METADATA_PTR)templateMetaData {
    SafeMetaData* meta = [[SafeMetaData alloc] initWithNickName:templateMetaData.nickName
                                                storageProvider:templateMetaData.storageProvider
                                                       fileName:templateMetaData.fileName
                                                 fileIdentifier:templateMetaData.fileIdentifier];
    self.isDuressDummyDatabase = YES;
    
    NSData* data = [self getDuressDummyData];
    if (!data) {
        CompositeKeyFactors *cpf = [CompositeKeyFactors password:@"1234"];

        DatabaseModel* model = [[DatabaseModel alloc] initWithFormat:kKeePass compositeKeyFactors:cpf];
        
        [SampleItemsGenerator addSampleGroupAndRecordToRoot:model passwordConfig:self.applicationPreferences.passwordGenerationConfig];
        
        data = [Serializator expressToData:model format:model.originalFormat];
        
        [self setDuressDummyData:data];
    }

    DatabaseModel* model = [Serializator expressFromData:data password:@"1234"];
    
    return [self initWithDatabase:model
                         metaData:meta
                   forcedReadOnly:NO
                       isAutoFill:isAutoFillOpen
                      offlineMode:NO
                isDuressDummyMode:YES];
}

#endif

- (instancetype)initWithDatabase:(DatabaseModel *)passwordDatabase
                        metaData:(METADATA_PTR)metaData
                  forcedReadOnly:(BOOL)forcedReadOnly
                      isAutoFill:(BOOL)isAutoFill {
    return [self initWithDatabase:passwordDatabase
                         metaData:metaData
                   forcedReadOnly:forcedReadOnly
                       isAutoFill:isAutoFill
                      offlineMode:NO];
}

- (instancetype)initWithDatabase:(DatabaseModel *)passwordDatabase
                        metaData:(METADATA_PTR)metaData
                  forcedReadOnly:(BOOL)forcedReadOnly
                      isAutoFill:(BOOL)isAutoFill
                     offlineMode:(BOOL)offlineMode {
    return [self initWithDatabase:passwordDatabase
                         metaData:metaData
                   forcedReadOnly:forcedReadOnly
                       isAutoFill:isAutoFill
                      offlineMode:offlineMode
                isDuressDummyMode:NO];
}

- (instancetype)initWithDatabase:(DatabaseModel *)passwordDatabase
                        metaData:(METADATA_PTR)metaData
                  forcedReadOnly:(BOOL)forcedReadOnly
                      isAutoFill:(BOOL)isAutoFill
                     offlineMode:(BOOL)offlineMode
               isDuressDummyMode:(BOOL)isDuressDummyMode {
    if (self = [super init]) {
        if ( !passwordDatabase ) {
            return nil;
        }
        
        self.theDatabase = passwordDatabase;
        self.asyncUpdateEncryptionQueue = dispatch_queue_create("Model-AsyncUpdateEncryptionQueue", DISPATCH_QUEUE_SERIAL);
        self.asyncUpdatesStack = ConcurrentMutableStack.mutableStack;
        
        _metadata = metaData;
        _cachedPinned = [NSSet setWithArray:self.metadata.favourites];
                
        if ( self.applicationPreferences.databasesAreAlwaysReadOnly ) {
            self.forcedReadOnly = YES;
        }
        else {
            self.forcedReadOnly = forcedReadOnly;
        }
        
        self.isAutoFillOpen = isAutoFill;
        self.isDuressDummyMode = isDuressDummyMode;
        self.offlineMode = offlineMode;
        
        [self createNewAuditor];
        
        return self;
    }
    else {
        return nil;
    }
}



- (DatabaseModel *)database {
    return self.theDatabase;
}

- (void)reloadDatabaseFromLocalWorkingCopy:(VIEW_CONTROLLER_PTR)viewController 
                                completion:(void(^)(BOOL success))completion {
    if (self.isDuressDummyMode) {
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (completion) {
                completion(YES);
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:kDatabaseReloadedNotificationKey object:nil];
            });
        });
        return;
    }

    NSLog(@"reloadDatabaseFromLocalWorkingCopy....");

    
    DatabaseUnlocker* unlocker = [DatabaseUnlocker unlockerForDatabase:self.metadata viewController:viewController forceReadOnly:self.forcedReadOnly isAutoFillOpen:self.isAutoFillOpen offlineMode:self.offlineMode];
    [unlocker unlockLocalWithKey:self.database.ckfs keyFromConvenience:NO completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable innerStreamError, NSError * _Nullable error) {
        if ( result == kUnlockDatabaseResultSuccess) {
            NSLog(@"reloadDatabaseFromLocalWorkingCopy... Success ");

            self.theDatabase = model.database;
            if (completion) {
                completion(YES);
            }
            
            [self restartBackgroundAudit];

            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:kDatabaseReloadedNotificationKey object:nil];
            });
        }
        else {
            NSLog(@"Unlocking local copy for database reload request failed: %@", error);
            
            
            
            

            
            if (completion) {
                completion(NO); 
            }
        }
    }];
}



- (void)clearAsyncUpdateState {
    [self.asyncUpdatesStack clear];
    self.lastAsyncUpdateResult = nil;
}

- (BOOL)asyncUpdateAndSync {
    NSLog(@"asyncUpdateAndSync ENTER");

    if(self.isReadOnly) {
        NSLog(@"WARNWARN - Database is Read Only - Will not UPDATE! Last Resort. - WARNWARN");
        return NO;
    }
    
    DatabaseModel* cloneForUpdate = [self.database clone];
    [self.asyncUpdatesStack push:cloneForUpdate];
    
    dispatch_async(self.asyncUpdateEncryptionQueue, ^{
        [self dequeueOutstandingAsyncUpdateAndProcess];
    });

    NSLog(@"asyncUpdateAndSync EXIT");

    return YES;
}

- (void)dequeueOutstandingAsyncUpdateAndProcess {
    DatabaseModel* cloneForUpdate = [self.asyncUpdatesStack popAndClear]; 
    
    if ( cloneForUpdate ) {
        [self queueAsyncUpdateWithDatabaseClone:NSUUID.UUID cloneForUpdate:cloneForUpdate];
    }
    else {
        NSLog(@"NOP - No outstanding async updates found. All Done.");
    }
}

- (NSString*)getUniqueStreamingFilename {
    NSString* ret;
    
    do {
        ret = [FileManager.sharedInstance.tmpEncryptionStreamPath stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    } while ([NSFileManager.defaultManager fileExistsAtPath:ret]);
    
    return ret;
}

- (void)queueAsyncUpdateWithDatabaseClone:(NSUUID*)updateId cloneForUpdate:(DatabaseModel*)cloneForUpdate {
    NSLog(@"queueAsyncUpdateWithDatabaseClone ENTER - [%@]", NSThread.currentThread.name);
    
    _isRunningAsyncUpdate = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kAsyncUpdateDone object:nil];
    });
    
    dispatch_group_t mutex = dispatch_group_create();
    dispatch_group_enter(mutex);
    
    NSString* streamingFile = [self getUniqueStreamingFilename];
    NSOutputStream* outputStream = [NSOutputStream outputStreamToFileAtPath:streamingFile append:NO];
    [outputStream open];
    
    [Serializator getAsData:cloneForUpdate
                     format:cloneForUpdate.originalFormat
               outputStream:outputStream
                 completion:^(BOOL userCancelled, NSString * _Nullable debugXml, NSError * _Nullable error) {
        [outputStream close];
        
        [self onAsyncUpdateSerializeDone:updateId userCancelled:userCancelled streamingFile:streamingFile updateMutex:mutex error:error]; 
    }];

    dispatch_group_wait(mutex, DISPATCH_TIME_FOREVER);
    
    NSLog(@"queueAsyncUpdateWithDatabaseClone EXIT - [%@]", NSThread.currentThread.name);
}

- (void)onAsyncUpdateSerializeDone:(NSUUID*)updateId userCancelled:(BOOL)userCancelled streamingFile:(NSString*)streamingFile updateMutex:(dispatch_group_t)updateMutex error:(NSError * _Nullable)error {
    if (userCancelled || error) {
        
        [self onAsyncUpdateDone:updateId success:NO userCancelled:userCancelled userInteractionRequired:NO localUpdated:NO updateMutex:updateMutex error:error];
        return;
    }
    
    if (self.isDuressDummyMode) {
        NSData* data = [NSData dataWithContentsOfFile:streamingFile];
        [NSFileManager.defaultManager removeItemAtPath:streamingFile error:nil];
        
        [self setDuressDummyData:data];
        [self onAsyncUpdateDone:updateId success:YES userCancelled:NO userInteractionRequired:NO localUpdated:NO updateMutex:updateMutex error:nil];
        return;
    }

    NSError* localUpdateError;
    BOOL success = [self.syncManagement updateLocalCopyMarkAsRequiringSync:self.metadata file:streamingFile error:&localUpdateError];
    [NSFileManager.defaultManager removeItemAtPath:streamingFile error:nil];

    if (!success) { 
        [self onAsyncUpdateDone:updateId success:NO userCancelled:NO userInteractionRequired:NO localUpdated:NO updateMutex:updateMutex error:localUpdateError];
        return;
    }

    

    if (self.metadata.auditConfig.auditInBackground) {
        [self restartAudit];
    }

    
    
    if ( self.offlineMode ) { 
        [self onAsyncUpdateDone:updateId success:YES userCancelled:NO userInteractionRequired:NO localUpdated:NO updateMutex:updateMutex error:nil];
        return;
    }

    [self.syncManagement sync:self.metadata
                       interactiveVC:nil
                                 key:self.database.ckfs
                                join:NO
                          completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        if ( result == kSyncAndMergeSuccess ) {
            if(self.metadata.autoFillEnabled && self.metadata.quickTypeEnabled) {
                [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.database
                                                                   databaseUuid:self.metadata.uuid
                                                                  displayFormat:self.metadata.quickTypeDisplayFormat
                                                                alternativeUrls:self.metadata.autoFillScanAltUrls
                                                                   customFields:self.metadata.autoFillScanCustomFields
                                                                          notes:self.metadata.autoFillScanNotes
                                                   concealedCustomFieldsAsCreds:self.metadata.autoFillConcealedFieldsAsCreds
                                                 unConcealedCustomFieldsAsCreds:self.metadata.autoFillUnConcealedFieldsAsCreds];
            }

            [self onAsyncUpdateDone:updateId success:YES userCancelled:userCancelled userInteractionRequired:NO localUpdated:localWasChanged updateMutex:updateMutex error:nil];
        }
        else if (result == kSyncAndMergeError) {
            [self onAsyncUpdateDone:updateId success:NO userCancelled:userCancelled userInteractionRequired:NO localUpdated:NO updateMutex:updateMutex error:error];
        }
        else if ( result == kSyncAndMergeResultUserInteractionRequired ) {
            [self onAsyncUpdateDone:updateId success:NO userCancelled:userCancelled userInteractionRequired:YES localUpdated:NO updateMutex:updateMutex error:error];
        }
        else {
            error = [Utils createNSError:[NSString stringWithFormat:@"Unexpected result returned from async update sync: [%@]", @(result)] errorCode:-1];
            [self onAsyncUpdateDone:updateId success:NO userCancelled:userCancelled userInteractionRequired:NO localUpdated:NO updateMutex:updateMutex error:error];
        }
    }];
}

- (void)onAsyncUpdateDone:(NSUUID*)updateId
                  success:(BOOL)success
            userCancelled:(BOOL)userCancelled
  userInteractionRequired:(BOOL)userInteractionRequired
             localUpdated:(BOOL)localUpdated
              updateMutex:(dispatch_group_t)updateMutex
                    error:(NSError*)error {
    NSLog(@"onAsyncUpdateDone: updateId=%@ success=%hhd, userInteractionRequired=%hhd, localUpdated=%hhd, error=%@", updateId, success, userInteractionRequired, localUpdated, error);

    self.lastAsyncUpdateResult = [[AsyncUpdateResult alloc] init];
    self.lastAsyncUpdateResult.success = success;
    self.lastAsyncUpdateResult.error = error;
    self.lastAsyncUpdateResult.userCancelled = userCancelled;
    self.lastAsyncUpdateResult.localWasChanged = localUpdated;
    self.lastAsyncUpdateResult.userInteractionRequired = userInteractionRequired;
    
    _isRunningAsyncUpdate = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kAsyncUpdateDone object:nil];
    });
    
    dispatch_group_leave(updateMutex);
}



- (void)update:(VIEW_CONTROLLER_PTR)viewController handler:(void(^)(BOOL userCancelled, BOOL localWasChanged, NSError * _Nullable error))handler {
    if(self.isReadOnly) {
        handler(NO, NO, [Utils createNSError:NSLocalizedString(@"model_error_readonly_cannot_write", @"You are in read-only mode. Cannot Write!") errorCode:-1]);
        return;
    }

    [self encrypt:viewController completion:^(BOOL userCancelled, NSString * _Nullable file, NSString * _Nullable debugXml, NSError * _Nullable error) {
        if (userCancelled || error) {
            handler(userCancelled, NO, error);
            return;
        }

        [self onEncryptionDone:viewController streamingFile:file completion:handler];
    }];
}

- (void)encrypt:(VIEW_CONTROLLER_PTR)viewController completion:(void (^)(BOOL userCancelled, NSString* file, NSString*_Nullable debugXml, NSError* error))completion {
    [self.spinnerUi show:NSLocalizedString(@"generic_encrypting", @"Encrypting") viewController:viewController];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        NSString* tmpFile = [self getUniqueStreamingFilename];
        NSOutputStream* outputStream = [NSOutputStream outputStreamToFileAtPath:tmpFile append:NO];
        [outputStream open];

        [Serializator getAsData:self.database
                         format:self.database.originalFormat
                   outputStream:outputStream
                     completion:^(BOOL userCancelled, NSString * _Nullable debugXml, NSError * _Nullable error) {
            [outputStream close];            

            dispatch_async(dispatch_get_main_queue(), ^(void){
                [self.spinnerUi dismiss];

                completion(userCancelled, tmpFile, debugXml, error);
            });
        }];
    });
}

- (void)onEncryptionDone:(VIEW_CONTROLLER_PTR)viewController streamingFile:(NSString*)streamingFile completion:(void(^)(BOOL userCancelled, BOOL localWasChanged, const NSError * _Nullable error))completion {
    if (self.isDuressDummyMode) {
        NSData* data = [NSData dataWithContentsOfFile:streamingFile];
        [NSFileManager.defaultManager removeItemAtPath:streamingFile error:nil];
        [self setDuressDummyData:data];
        completion(NO, NO, nil);
        return;
    }
    
    
    
    NSError* error;
    BOOL success = [self.syncManagement updateLocalCopyMarkAsRequiringSync:self.metadata file:streamingFile error:&error];
    [NSFileManager.defaultManager removeItemAtPath:streamingFile error:nil];

    if (!success) {
        completion(NO, NO, error);
        return;
    }
    
    
    
    if (self.metadata.auditConfig.auditInBackground) {
        [self restartAudit];
    }

    if ( self.offlineMode ) { 
        completion(NO, NO, nil);
    }
    else {
        [self.syncManagement sync:self.metadata
                           interactiveVC:viewController
                                     key:self.database.ckfs
                                    join:NO
                              completion:^(SyncAndMergeResult result, BOOL localWasChanged, const NSError * _Nullable error) {
            if (result == kSyncAndMergeSuccess || result == kSyncAndMergeUserPostponedSync) {
                if(self.metadata.autoFillEnabled && self.metadata.quickTypeEnabled) {
                    [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.database
                                                                       databaseUuid:self.metadata.uuid
                                                                      displayFormat:self.metadata.quickTypeDisplayFormat
                                                                    alternativeUrls:self.metadata.autoFillScanAltUrls
                                                                       customFields:self.metadata.autoFillScanCustomFields
                                                                              notes:self.metadata.autoFillScanNotes
                                                       concealedCustomFieldsAsCreds:self.metadata.autoFillConcealedFieldsAsCreds
                                                     unConcealedCustomFieldsAsCreds:self.metadata.autoFillUnConcealedFieldsAsCreds];
                }

                completion(NO, localWasChanged, nil);
            }
            else if (result == kSyncAndMergeError) {
                completion(NO, NO, error);
            }
            else if (result == kSyncAndMergeResultUserCancelled) {
                
                NSString* message = NSLocalizedString(@"sync_could_not_sync_your_changes", @"Strongbox could not sync your changes.");
                error = [Utils createNSError:message errorCode:-1];
                completion(YES, NO, error);
            }
            else { 
                error = [Utils createNSError:[NSString stringWithFormat:@"Unexpected result returned from interactive update sync: [%@]", @(result)] errorCode:-1];
                completion(NO, NO, error);
            }
        }];
    }
}



- (AuditState)auditState {
    return self.auditor.state;
}

- (void)restartBackgroundAudit {
    if (!self.isAutoFillOpen && self.metadata.auditConfig.auditInBackground) {
         [self restartAudit];
    }
    else {
        NSLog(@"Audit not configured to run. Skipping.");
    }
}

- (void)stopAudit {
    if (self.auditor) {
        [self.auditor stop];
    }
}

- (void)stopAndClearAuditor {
    [self stopAudit];
    [self createNewAuditor];
}

- (void)createNewAuditor {
#ifndef IS_APP_EXTENSION
    NSArray<NSString*> *excluded = self.metadata.auditExcludedItems;
    NSSet<NSString*> *set = [NSSet setWithArray:excluded];

    __weak Model* weakSelf = self;
    self.auditor = [[DatabaseAuditor alloc] initWithPro:self.applicationPreferences.isProOrFreeTrial
                                         strengthConfig:self.applicationPreferences.passwordStrengthConfig
                                             isExcluded:^BOOL(Node * _Nonnull item) {
        return [weakSelf isExcludedFromAuditHelper:set uuid:item.uuid];
    }
                                             saveConfig:^(DatabaseAuditorConfiguration * _Nonnull config) {
        
        [self.databasesPreferencesManager update:weakSelf.metadata];
    }];
#endif
}

- (BOOL)isExcludedFromAudit:(NSUUID *)item {
    NSArray<NSString*> *excluded = self.metadata.auditExcludedItems;
    NSSet<NSString*> *set = [NSSet setWithArray:excluded];
    
    return [self isExcludedFromAuditHelper:set uuid:item];
}

- (BOOL)isExcludedFromAuditHelper:(NSSet<NSString*> *)set uuid:(NSUUID*)uuid {
    Node* node = [self.database getItemById:uuid];
    if ( !node.fields.qualityCheck ) { 
        return YES;
    }
    
    NSString* sid = [self.database getCrossSerializationFriendlyIdId:uuid];

    return [set containsObject:sid];
}

- (void)restartAudit {
    [self stopAndClearAuditor];

#ifndef IS_APP_EXTENSION
    [self.auditor start:self.database
                 config:self.metadata.auditConfig
            nodesChanged:^{

        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:kAuditNodesChangedNotificationKey object:nil];
        });
    }
    progress:^(double progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:kAuditProgressNotificationKey object:@(progress)];
        });
    } completion:^(BOOL userStopped) {

        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:kAuditCompletedNotificationKey object:@(userStopped)];
        });
    }];
#endif
}

- (NSUInteger)auditHibpErrorCount {
    return self.auditor ? self.auditor.haveIBeenPwnedErrorCount : 0;
}

- (NSNumber*)auditIssueCount {
    return self.auditor ? @(self.auditor.auditIssueCount) : nil;
}

- (NSUInteger)auditIssueNodeCount {
    return self.auditor ? self.auditor.auditIssueNodeCount : 0;
}

- (NSString *)getQuickAuditVeryBriefSummaryForNode:(NSUUID *)item {
    if (self.auditor) {
        return [self.auditor getQuickAuditVeryBriefSummaryForNode:item];
    }
    
    return @"";
}

- (NSString *)getQuickAuditSummaryForNode:(NSUUID *)item {
    if (self.auditor) {
        return [self.auditor getQuickAuditSummaryForNode:item];
    }
    
    return @"";
}

- (NSSet<NSNumber *> *)getQuickAuditFlagsForNode:(NSUUID *)item {
    if (self.auditor) {
        return [self.auditor getQuickAuditFlagsForNode:item];
    }
    
    return NSSet.set;
}

- (BOOL)isFlaggedByAudit:(NSUUID *)item {
    if (self.auditor) {
        NSSet<NSNumber*>* auditFlags = [self.auditor getQuickAuditFlagsForNode:item];
        return auditFlags.count > 0;
    }
    
    return NO;
}

- (NSSet<Node *> *)getSimilarPasswordNodeSet:(NSUUID *)node {
    if (self.auditor) {
        NSSet<NSUUID*>* sims = [self.auditor getSimilarPasswordNodeSet:node];
        
        return [[sims.allObjects filter:^BOOL(NSUUID * _Nonnull obj) {
            return [self.database getItemById:obj] != nil;
        }] map:^id _Nonnull(NSUUID * _Nonnull obj, NSUInteger idx) {
            return [self.database getItemById:obj];
        }].set;
    }
    
    return NSSet.set;
}

- (NSSet<Node *> *)getDuplicatedPasswordNodeSet:(NSUUID *)node {
    if (self.auditor) {
        NSSet<NSUUID*>* dupes = [self.auditor getDuplicatedPasswordNodeSet:node];
        
        return [[dupes.allObjects filter:^BOOL(NSUUID * _Nonnull obj) {
            return [self.database getItemById:obj] != nil;
        }] map:^id _Nonnull(NSUUID * _Nonnull obj, NSUInteger idx) {
            return [self.database getItemById:obj];
        }].set;
    }
    
    return NSSet.set;
}

- (void)setItemAuditExclusion:(NSUUID *)item exclude:(BOOL)exclude {
    NSString* sid = [self.database getCrossSerializationFriendlyIdId:item];
    NSArray<NSString*> *excluded = self.metadata.auditExcludedItems;
        
    NSMutableSet<NSString*> *mutable = [NSMutableSet setWithArray:excluded];
    
    if (exclude) {
        [mutable addObject:sid];
    }
    else {
        [mutable removeObject:sid];
    }
    
    self.metadata.auditExcludedItems = mutable.allObjects;
    [self.databasesPreferencesManager update:self.metadata];
}

- (NSArray<Node*>*)getExcludedAuditItems {
    NSSet<NSString*> *excludedSet = [NSSet setWithArray:self.metadata.auditExcludedItems];
    return [self getNodesFromSerializationIds:excludedSet];
}

- (void)oneTimeHibpCheck:(NSString *)password completion:(void (^)(BOOL, NSError * _Nonnull))completion {
    if (self.auditor) {
        [self.auditor oneTimeHibpCheck:password completion:completion];
    }
    else {
        completion (NO, [Utils createNSError:@"Auditor Unavailable!" errorCode:-2345]);
    }
}



- (BOOL)isInOfflineMode {
    return self.offlineMode;
}

- (BOOL)isReadOnly {
    return self.metadata.readOnly || self.forcedReadOnly;
}

- (void)disableAndClearAutoFill {
    self.metadata.autoFillEnabled = NO;
    [self.databasesPreferencesManager update:self.metadata];
    [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
}

- (void)enableAutoFill {
    _metadata.autoFillEnabled = YES;
    [self.databasesPreferencesManager update:self.metadata];
}




- (Node*)addNewGroup:(Node *_Nonnull)parentGroup title:(NSString*)title {
    BOOL keePassGroupTitleRules = self.database.originalFormat != kPasswordSafe;
    
    Node* newGroup = [[Node alloc] initAsGroup:title parent:parentGroup keePassGroupTitleRules:keePassGroupTitleRules uuid:nil];
    
    if ( [self.database addChild:newGroup destination:parentGroup] ) {
        return newGroup;
    }

    return nil;
}

- (Node *)addItem:(Node *)parent item:(Node *)item {
    if ( [self.database addChild:item destination:parent] ) {
        return item;
    }
    return nil;
}

- (BOOL)canRecycle:(NSUUID *)itemId {
    return [self.database canRecycle:itemId];
}

- (void)deleteItems:(const NSArray<Node *> *)items {
    [self.database deleteItems:items];

    
    
    for (Node* item in items) {
        if([self isPinned:item.uuid]) {
            [self togglePin:item.uuid];
        }
    }
}

- (BOOL)recycleItems:(const NSArray<Node *> *)items {
    BOOL ret = [self.database recycleItems:items];
    
    if (ret) { 
        for (Node* item in items) {
            if([self isPinned:item.uuid]) {
                [self togglePin:item.uuid];
            }
        }
    }
    
    return ret;
}

- (void)launchUrl:(Node *)item {
    NSURL* launchableUrl = [self.database launchableUrlForItem:item];
        
    if ( !launchableUrl ) {
        NSLog(@"Could not get launchable URL for item.");
        return;
    }
    
    [self launchLaunchableUrl:launchableUrl];
}

- (void)launchUrlString:(NSString*)urlString {
    NSURL* launchableUrl = [self.database launchableUrlForUrlString:urlString];
        
    if ( !launchableUrl ) {
        NSLog(@"Could not get launchable URL for string.");
        return;
    }
    
    [self launchLaunchableUrl:launchableUrl];
}

- (void)launchLaunchableUrl:(NSURL*)launchableUrl {
#if TARGET_OS_IPHONE
#ifndef IS_APP_EXTENSION
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (@available (iOS 10.0, *)) {
            [UIApplication.sharedApplication openURL:launchableUrl options:@{} completionHandler:^(BOOL success) {
                if (!success) {
                    NSLog(@"Couldn't launch this URL!");
                }
            }];
        }
        else {
            [UIApplication.sharedApplication openURL:launchableUrl];
        }
    });
#endif
#else
    if ( !launchableUrl ) {
        NSLog(@"Could not get launchable URL for item.");
        return;
    }
    
    if (@available(macOS 10.15, *)) {
        [[NSWorkspace sharedWorkspace] openURL:launchableUrl
                                 configuration:NSWorkspaceOpenConfiguration.configuration
                             completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
            if ( error ) {
                NSLog(@"Launch URL done. Error = [%@]", error);
            }
        }];
    } else {
        [[NSWorkspace sharedWorkspace] openURL:launchableUrl];
    }
#endif
}



- (NSArray<Node*>*)pinnedNodes {
    return [self getNodesFromSerializationIds:self.pinnedSet];
}

- (NSSet<NSString*>*)pinnedSet {
    return self.cachedPinned;
}

- (BOOL)isPinned:(NSUUID *)itemId {
    if(self.cachedPinned.count == 0) {
        return NO;
    }
    
    NSString* sid = [self.database getCrossSerializationFriendlyIdId:itemId];
    
    return [self.cachedPinned containsObject:sid];
}

- (void)togglePin:(NSUUID *)itemId {
    NSString* sid = [self.database getCrossSerializationFriendlyIdId:itemId];

    NSMutableSet<NSString*>* favs = self.cachedPinned.mutableCopy;
    
    if([self isPinned:itemId]) {
        [favs removeObject:sid];
    }
    else {
        [favs addObject:sid];
    }
    
    
    
    __weak Model* weakSelf = self;
    NSArray<Node*>* pinned = [self.database.effectiveRootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        NSString* sid = [weakSelf.database getCrossSerializationFriendlyIdId:node.uuid];
        return [favs containsObject:sid];
    }];
    
    NSArray<NSString*>* trimmed = [pinned map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        NSString* sid = [weakSelf.database getCrossSerializationFriendlyIdId:obj.uuid];
        return sid;
    }];
    self.cachedPinned = [NSSet setWithArray:trimmed];

    self.metadata.favourites = trimmed;
    
    [self.databasesPreferencesManager update:self.metadata];
}



- (NSString *)generatePassword {
    PasswordGenerationConfig* config = self.applicationPreferences.passwordGenerationConfig;
    return [PasswordMaker.sharedInstance generateForConfigOrDefault:config];
}



- (NSArray<Node*>*)getNodesFromSerializationIds:(NSSet<NSString*>*)set {
    NSMutableArray<Node*>* ret = @[].mutableCopy;
    
    for (NSString *sid in set) {
        Node* node = [self.database getItemByCrossSerializationFriendlyId:sid];
        
        if (node) {
            [ret addObject:node];
        }
    }
    
    return [ret sortedArrayUsingComparator:finderStyleNodeComparator];
}

- (NSArray<Node *>*)allNodes {
    return self.database.effectiveRootGroup.allChildren;
}

-(NSArray<Node *> *)allRecords {
    return self.database.effectiveRootGroup.allChildRecords;
}

-(NSArray<Node *> *)allGroups {
    return self.database.effectiveRootGroup.allChildGroups;
}

@end
