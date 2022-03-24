#ifndef _DatabaseModel_h
#define _DatabaseModel_h

#import <Foundation/Foundation.h>
#import "Node.h"
#import "DatabaseAttachment.h"
#import "DatabaseFormat.h"
#import "UnifiedDatabaseMetadata.h"
#import "NodeHierarchyReconstructionData.h"
#import "CompositeKeyFactors.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseModel : NSObject

@property (nonatomic, readonly) Node* rootNode;

@property (nonatomic, readonly) DatabaseFormat originalFormat;
@property (nonatomic, readonly) Node* effectiveRootGroup;
@property (nonatomic, readonly, nonnull) UnifiedDatabaseMetadata* meta;
@property (nonatomic, nonnull) CompositeKeyFactors *ckfs;

@property (nonatomic) NSDictionary<NSUUID*, NSDate*> *deletedObjects;

@property (readonly) NSArray<DatabaseAttachment*> *attachmentPool;
@property (readonly) NSDictionary<NSUUID*, NodeIcon*>* iconPool;

- (instancetype)init;

- (instancetype)clone;

- (instancetype)initWithFormat:(DatabaseFormat)format;

- (instancetype)initWithCompositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors;

- (instancetype)initWithFormat:(DatabaseFormat)format
           compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors;

- (instancetype)initWithFormat:(DatabaseFormat)format
           compositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors
                      metadata:(UnifiedDatabaseMetadata*)metadata;

- (instancetype)initWithFormat:(DatabaseFormat)format
           compositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors
                      metadata:(UnifiedDatabaseMetadata*)metadata
                          root:(Node *_Nullable)root;

- (instancetype)initWithFormat:(DatabaseFormat)format
           compositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors
                      metadata:(UnifiedDatabaseMetadata*)metadata
                          root:(Node *_Nullable)root
                deletedObjects:(NSDictionary<NSUUID *, NSDate *> *)deletedObjects
                      iconPool:(NSDictionary<NSUUID *, NodeIcon *> *)iconPool;



- (void)rebuildFastMaps; 



- (void)changeKeePassFormat:(DatabaseFormat)newFormat;

- (void)performPreSerializationTidy;
- (NSSet<Node*>*)getMinimalNodeSet:items;

- (BOOL)setItemTitle:(Node*)item title:(NSString*)title;

- (NSURL*_Nullable)launchableUrlForItem:(Node*)item;
- (NSURL*_Nullable)launchableUrlForUrlString:(NSString*)urlString;



- (void)deleteItems:(const NSArray<Node *> *)items;
- (void)deleteItems:(const NSArray<Node *> *)items undoData:(NSArray<NodeHierarchyReconstructionData*>*_Nullable*_Nullable)undoData;
- (void)unDelete:(NSArray<NodeHierarchyReconstructionData*>*)undoData;



@property BOOL recycleBinEnabled;
@property (nullable, readonly) NSUUID* recycleBinNodeUuid;   
@property (nullable, readonly) NSDate* recycleBinChanged;
@property (nullable, readonly) Node* recycleBinNode;
@property (nullable, readonly) Node* keePass1BackupNode;

- (BOOL)canRecycle:(NSUUID*)itemId;
- (BOOL)recycleItems:(const NSArray<Node *> *)items;
- (BOOL)recycleItems:(const NSArray<Node *> *)items undoData:(NSArray<NodeHierarchyReconstructionData*>*_Nullable*_Nullable)undoData;
- (void)undoRecycle:(NSArray<NodeHierarchyReconstructionData*>*)undoData;



- (BOOL)validateMoveItems:(const NSArray<Node*>*)items destination:(Node*)destination;
- (BOOL)moveItems:(const NSArray<Node*>*)items destination:(Node*)destination;
- (BOOL)moveItems:(const NSArray<Node *> *)items destination:(Node*)destination undoData:(NSArray<NodeHierarchyReconstructionData*>*_Nullable*_Nullable)undoData;
- (void)undoMove:(NSArray<NodeHierarchyReconstructionData*>*)undoData;



- (BOOL)reorderItem:(Node*)item to:(NSInteger)to; 
- (BOOL)reorderChildFrom:(NSUInteger)from to:(NSInteger)to parentGroup:parentGroup;



- (BOOL)validateAddChildren:(NSArray<Node *>*)items destination:(Node *)destination;

- (BOOL)addChildren:(NSArray<Node *>*)items destination:(Node *)destination;
- (BOOL)addChildren:(NSArray<Node *>*)items destination:(Node *)destination suppressFastMapsRebuild:(BOOL)suppressFastMapsRebuild;

- (BOOL)insertChildren:(NSArray<Node *>*)items
           destination:(Node *)destination
            atPosition:(NSInteger)position;

- (void)removeChildren:(NSArray<NSUUID *>*)itemIds;



- (void)addHistoricalNode:(Node*)item originalNodeForHistory:(Node*)originalNodeForHistory;



- (BOOL)isDereferenceableText:(NSString*)text;
- (NSString*)dereference:(NSString*)text node:(Node*)node;
- (NSString *)getPathDisplayString:(Node *)vm;
- (NSString *)getPathDisplayString:(Node *)vm
                  includeRootGroup:(BOOL)includeRootGroup
       rootGroupNameInsteadOfSlash:(BOOL)rootGroupNameInsteadOfSlash
                includeFolderEmoji:(BOOL)includeFolderEmoji
                          joinedBy:(NSString*)joinedBy;

- (NSString *)getSearchParentGroupPathDisplayString:(Node *)vm;
- (NSString *)getSearchParentGroupPathDisplayString:(Node *)vm prependSlash:(BOOL)prependSlash;

- (BOOL)isTitleMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin;
- (BOOL)isUsernameMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin;
- (BOOL)isPasswordMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin;
- (BOOL)isUrlMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin;
- (BOOL)isTagsMatches:(NSString*)searchText node:(Node*)node checkPinYin:(BOOL)checkPinYin;
- (BOOL)isAllFieldsMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin;
- (NSArray<NSString*>*)getSearchTerms:(NSString *)searchText;

- (NSString*)getHtmlPrintString:(NSString*)databaseName;



@property (nonatomic, readonly, nonnull) NSArray<Node*> *expiredEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *nearlyExpiredEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *totpEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *attachmentEntries;

@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchable;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchableTrueRoot;

@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchableNoneExpiredEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchableEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allActiveEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allActiveGroups;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchableGroups;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allActive;

@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull usernameSet;
@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull emailSet;
@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull urlSet;
@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull passwordSet;
@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull customFieldKeySet;
@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull tagSet;

@property (nonatomic, readonly) NSString* _Nonnull mostPopularUsername;
@property (nonatomic, readonly) NSArray<NSString*>* mostPopularUsernames;

@property (nonatomic, readonly) NSString* _Nonnull mostPopularEmail;
@property (nonatomic, readonly) NSArray<NSString*>* mostPopularEmails;
@property (nonatomic, readonly) NSArray<NSString*>* mostPopularTags;

@property (nonatomic, readonly) NSInteger numberOfRecords;
@property (nonatomic, readonly) NSInteger numberOfGroups;

@property (readonly) BOOL isUsingKeePassGroupTitleRules;



- (NSString*_Nullable)getCrossSerializationFriendlyIdId:(NSUUID *)nodeId;
- (Node *_Nullable)getItemByCrossSerializationFriendlyId:(NSString*)serializationId;

- (Node*_Nullable)getItemById:(NSUUID*)uuid;
- (NSArray<NSUUID*>*)getItemIdsForTag:(NSString*)tag;

- (BOOL)addTag:(NSUUID*)itemId tag:(NSString*)tag;
- (BOOL)removeTag:(NSUUID*)itemId tag:(NSString*)tag;

- (BOOL)preOrderTraverse:(BOOL (^)(Node* node))function; 

@end

#endif 

NS_ASSUME_NONNULL_END
