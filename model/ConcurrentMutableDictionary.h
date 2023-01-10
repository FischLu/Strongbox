//
//  ConcurrentMutableDictionary.h
//  Strongbox
//
//  Created by Strongbox on 20/07/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConcurrentMutableDictionary<KeyType, ValueType> : NSObject

+ (instancetype)mutableDictionary;

- (void)setObject:(id)object forKey:(nonnull id<NSCopying>)forKey;
- (nullable ValueType)objectForKey:(nonnull KeyType)key;
- (void)removeObjectForKey:(nonnull id<NSCopying>)forKey;

- (id)objectForKeyedSubscript:(KeyType)key;
- (void)setObject:(ValueType)obj forKeyedSubscript:(KeyType)key;

- (void)removeAllObjects;

@property (readonly) NSArray<KeyType>* allKeys;

@end

NS_ASSUME_NONNULL_END
