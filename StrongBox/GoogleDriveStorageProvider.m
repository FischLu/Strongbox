//
//  GoogleDriveStorageProvider.m
//  StrongBox
//
//  Created by Mark on 19/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GoogleDriveStorageProvider.h"
#import "SVProgressHUD.h"
#import "Constants.h"

@implementation GoogleDriveStorageProvider {
    NSMutableDictionary *_iconsByUrl;
}

+ (instancetype)sharedInstance {
    static GoogleDriveStorageProvider *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[GoogleDriveStorageProvider alloc] init];
    });
    return sharedInstance;
}

- (void)getModDate:(nonnull METADATA_PTR)safeMetaData completion:(nonnull StorageProviderGetModDateCompletionBlock)completion {
    
}

- (instancetype)init {
    if (self = [super init]) {
        _storageId = kGoogleDrive;
        _providesIcons = YES;
        _browsableNew = YES;
        _browsableExisting = YES;
        _rootFolderOnly = NO;
        _defaultForImmediatelyOfferOfflineCache = YES; 
        _supportsConcurrentRequests = NO; 
        _iconsByUrl = [[NSMutableDictionary alloc] init];
        _privacyOptInRequired = YES;
        
        return self;
    }
    else {
        return nil;
    }
}

- (void)    create:(NSString *)nickName
         extension:(NSString *)extension
              data:(NSData *)data
      parentFolder:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(DatabasePreferences *metadata, const NSError *error))completion {
    [SVProgressHUD show];

    NSString *desiredFilename = [NSString stringWithFormat:@"%@.%@", nickName, extension];

    [[GoogleDriveManager sharedInstance] create:viewController
                                      withTitle:desiredFilename
                                       withData:data
                                   parentFolder:parentFolder
                                     completion:^(GTLRDrive_File *file, NSError *error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
        });

        if (error == nil) {
            DatabasePreferences *metadata = [self getDatabasePreferences:nickName
                                              providerData:file];

            completion(metadata, error);
        }
        else {
            completion(nil, error);
        }
    }];
}

- (void)pullDatabase:(DatabasePreferences *)safeMetaData interactiveVC:(UIViewController *)viewController options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)completion {
    [[GoogleDriveManager sharedInstance] read:viewController
                         parentFileIdentifier:safeMetaData.fileIdentifier
                                     fileName:safeMetaData.fileName
                                      options:options
                                   completion:^(StorageProviderReadResult result, NSData * _Nullable data, NSDate * _Nullable dateModified, const NSError * _Nullable error) {
        if (result == kReadResultError) {
            NSLog(@"%@", error);
            [[GoogleDriveManager sharedInstance] signout];
        }
        
        completion(result, data, dateModified, error);
    }];
}

- (void)pushDatabase:(DatabasePreferences *)safeMetaData interactiveVC:(UIViewController *)viewController data:(NSData *)data completion:(StorageProviderUpdateCompletionBlock)completion {
    if (viewController) {
        [SVProgressHUD show];
    }
    
    [[GoogleDriveManager sharedInstance] update:viewController
                           parentFileIdentifier:safeMetaData.fileIdentifier
                                       fileName:safeMetaData.fileName
                                       withData:data
                                     completion:^(StorageProviderUpdateResult result, NSDate * _Nullable newRemoteModDate, const NSError * _Nullable error) {
        if (viewController) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
            });
        }
        
        if(error) {
            [[GoogleDriveManager sharedInstance] signout];
        }

        completion(result, newRemoteModDate, error);
    }];
}

- (void)      list:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, const NSError *))completion {

    GTLRDrive_File *parent = (GTLRDrive_File *)parentFolder;
    NSMutableArray *driveFiles = [[NSMutableArray alloc] init];

    [[GoogleDriveManager sharedInstance] getFilesAndFolders:viewController
                                           withParentFolder:(parent ? parent.identifier : nil)
                                                 completion:^(BOOL userCancelled, NSArray *folders, NSArray *files, NSError *error)
    {
        if (error == nil) {
            NSArray *sorted = [folders sortedArrayUsingComparator:^NSComparisonResult (id obj1, id obj2) {
                GTLRDrive_File *f1 = (GTLRDrive_File *)obj1;
                GTLRDrive_File *f2 = (GTLRDrive_File *)obj2;

                return [f1.name compare:f2.name
                                options:NSCaseInsensitiveSearch];
            }];

            [driveFiles addObjectsFromArray:sorted];

            sorted = [files sortedArrayUsingComparator:^NSComparisonResult (id obj1, id obj2) {
                GTLRDrive_File *f1 = (GTLRDrive_File *)obj1;
                GTLRDrive_File *f2 = (GTLRDrive_File *)obj2;

                return [f1.name compare:f2.name
                                options:NSCaseInsensitiveSearch];
            }];

            [driveFiles addObjectsFromArray:sorted];

            completion(NO, [self mapToStorageBrowserItems:driveFiles], nil);
        }
        else {
            [[GoogleDriveManager sharedInstance] signout];
            completion(userCancelled, nil, error);
        }
    }];
}

- (void)readWithProviderData:(NSObject *)providerData viewController:(UIViewController *)viewController options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)completionHandler {
    [SVProgressHUD showWithStatus:NSLocalizedString(@"storage_provider_status_reading", @"A storage provider is in the process of reading. This is the status displayed on the progress dialog. In english:  Reading...")];

    GTLRDrive_File *file = (GTLRDrive_File *)providerData;
    
    [[GoogleDriveManager sharedInstance] readWithOnlyFileId:viewController
                                             fileIdentifier:file.identifier
                                               dateModified:file.modifiedTime.date
                                                 completion:^(StorageProviderReadResult result, NSData * _Nullable data, NSDate * _Nullable dateModified, const NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
        });

        if ( error ) {
            [[GoogleDriveManager sharedInstance] signout];
            completionHandler(kReadResultError, nil, nil, error);
        }
        else {
            completionHandler(kReadResultSuccess, data, dateModified, nil);
        }
    }];
}

- (NSArray<StorageBrowserItem *> *)mapToStorageBrowserItems:(NSArray<GTLRDrive_File *> *)items {
    NSMutableArray<StorageBrowserItem *> *ret = [[NSMutableArray alloc]initWithCapacity:items.count];

    for (GTLRDrive_File *item in items) {
        StorageBrowserItem *mapped = [StorageBrowserItem alloc];

        mapped.name = item.name;
        mapped.folder = [item.mimeType isEqual:@"application/vnd.google-apps.folder"];
        mapped.providerData = item;

        [ret addObject:mapped];
    }

    return ret;
}

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController
      completion:(void (^)(UIImage *image))completionHandler {
    GTLRDrive_File *file = (GTLRDrive_File *)providerData;

    if (_iconsByUrl[file.iconLink] == nil) {
        [[GoogleDriveManager sharedInstance] fetchUrl:viewController
                                              withUrl:file.iconLink
                                           completion:^(NSData *data, NSError *error) {
                                               if (error == nil && data) {
                                                   UIImage *image = [UIImage imageWithData:data];

                                                   if (image) {
                                                       self->_iconsByUrl[file.iconLink] = image;

                                                       completionHandler(image);
                                                    }
                                               }
                                               else {
                                               NSLog(@"An error occurred downloading icon: %@", error);
                                               }
                                           }];
    }
    else {
        completionHandler(_iconsByUrl[file.iconLink]);
    }
}

- (DatabasePreferences *)getDatabasePreferences:(NSString *)nickName providerData:(NSObject *)providerData {
    GTLRDrive_File *file = (GTLRDrive_File *)providerData;
    NSString *parent = (file.parents)[0];

    return [DatabasePreferences templateDummyWithNickName:nickName
                                  storageProvider:self.storageId
                                         fileName:file.name
                                   fileIdentifier:parent];
}

- (void)delete:(DatabasePreferences *)safeMetaData completion:(void (^)(const NSError *))completion {
    
}

@end
