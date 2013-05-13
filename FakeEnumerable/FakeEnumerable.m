//
//  FakeEnumerable.m
//  FakeEnumerable
//
//  Created by Adam Sharp on 13/05/13.
//  Copyright (c) 2013 Adam Sharp. All rights reserved.
//

#import "FakeEnumerable.h"

#define SuppressPerformSelectorLeakWarning(Stuff) \
            do { \
                _Pragma("clang diagnostic push") \
                _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
                    Stuff; \
                _Pragma("clang diagnostic pop") \
            } while (0)

@implementation FakeEnumerable

- (id)each
{
    NSAssert(NO, @"-each must be overridden by subclass");
    return nil;
}
- (id)each:(void (^)(id))block
{
    NSAssert(NO, @"-each: must be overridden by subclass");
    return nil;
}

- (id)map
{
    return nil;
}
- (id)map:(id (^)(id))block
{
    NSMutableArray * result = [NSMutableArray array];
    [self each:^(id obj) {
        [result addObject:block(obj)];
    }];
    return result;
}

- (id)sortBy:(id (^)(id))block
{
    return nil;
}

- (id)filter:(BOOL (^)(id))block
{
    NSMutableArray * result = [NSMutableArray array];
    [self each:^(id obj) {
        if (block(obj)) {
            [result addObject:obj];
        }
    }];
    return result;
}

- (id)inject:(SEL)binaryOperation
{
    return [self reduce:^id(id memo, id obj) {
        SuppressPerformSelectorLeakWarning(
            return [memo performSelector:binaryOperation withObject:obj];
        );
    }];
}

- (id)reduce:(id (^)(id, id))block
{
    __block id memo;
    [self each:^(id obj) {
        if (!memo)
            memo = obj;
        else
            memo = block(memo, obj);
    }];
    return memo;
}

@end
