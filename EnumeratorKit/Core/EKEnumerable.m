//
//  EKEnumerable.m
//  EnumeratorKit
//
//  Created by Adam Sharp on 13/05/13.
//  Copyright (c) 2013 Adam Sharp. All rights reserved.
//

#import <objc/runtime.h>
#import "EnumeratorKit.h"

#define SuppressPerformSelectorLeakWarning(Stuff) \
        do { \
            _Pragma("clang diagnostic push") \
            _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
                Stuff; \
            _Pragma("clang diagnostic pop") \
        } while (0)

@implementation EKEnumerable

+ (void)load
{
    [NSArray includeEKEnumerable];
    [NSDictionary includeEKEnumerable];
    [NSSet includeEKEnumerable];
    [NSOrderedSet includeEKEnumerable];
}

- (id<EKEnumerable>)each:(EKVisitor)block
{
    NSAssert(NO, @"expected -each: to be implemented");
    return nil;
}
- (id<EKEnumerable> (^)(EKVisitor))each
{
    return ^id<EKEnumerable>(EKVisitor block) {
        return [self each:block];
    };
}

- (id<EKEnumerable>)eachWithIndex:(EKIndexedVisitor)block
{
    __block NSUInteger i = 0;
    [self each:^(id obj) {
        block(obj, i++);
    }];
    return self;
}
- (id<EKEnumerable> (^)(EKIndexedVisitor))eachWithIndex
{
    return ^id<EKEnumerable>(EKIndexedVisitor block) {
        return [self eachWithIndex:block];
    };
}

- (NSArray *)asArray
{
    return [self take:-1];
}
- (NSArray *)take:(NSInteger)number
{
    NSMutableArray *result = [NSMutableArray array];
    EKEnumerator *e = self.asEnumerator;

    NSUInteger count = 0;
    while (e.peek && (number < 0 || ++count <= number)) {
        [result addObject:e.next];
    }

    return result;
}
- (NSArray * (^)(NSInteger))take
{
    return ^NSArray *(NSInteger number) {
        return [self take:number];
    };
}

- (NSArray *)map:(EKMapping)block
{
    NSMutableArray * result = [NSMutableArray array];
    [self each:^(id obj) {
        id mapped = block(obj);
        [result addObject:(mapped ? mapped : [NSNull null])];
    }];
    return result;
}
- (NSArray * (^)(EKMapping))map
{
    return ^NSArray *(EKMapping block) {
        return [self map:block];
    };
}

- (NSDictionary *)chunk:(EKKeyMapping)block
{
    NSMutableDictionary *chunks = [NSMutableDictionary new];
    [self each:^(id obj) {
        id<NSCopying> result = block(obj);
        id<NSCopying> key = result ? result : [NSNull null];

        if (!chunks[key]) {
            chunks[key] = [NSMutableArray new];
        }

        [chunks[key] addObject:obj];
    }];

    // ensure the chunked arrays are immutable
    return [[NSDictionary alloc] initWithDictionary:chunks copyItems:YES];
}

- (NSDictionary *(^)(EKKeyMapping))chunk
{
    return ^NSDictionary *(EKKeyMapping block){
        return [self chunk:block];
    };
}

- (NSArray *)select:(EKPredicate)block
{
    NSMutableArray * result = [NSMutableArray array];
    [self each:^(id obj) {
        if (block(obj)) {
            [result addObject:obj];
        }
    }];
    return [result copy];
}

- (NSArray *(^)(EKPredicate))select
{
    return ^NSArray *(EKPredicate block) {
        return [self select:block];
    };
}

- (NSArray *)filter:(EKPredicate)block
{
    return [self select:block];
}
- (NSArray * (^)(EKPredicate))filter
{
    return ^NSArray *(EKPredicate block) {
        return [self filter:block];
    };
}

- (NSArray *)reject:(EKPredicate)block
{
    NSMutableArray * result = [NSMutableArray array];
    [self each:^(id obj) {
        if (!block(obj)) {
            [result addObject:obj];
        }
    }];
    return [result copy];
}

- (NSArray *(^)(EKPredicate))reject
{
    return ^NSArray *(EKPredicate block){
        return [self reject:block];
    };
}

- (NSArray *)sort
{
    return [self.asArray sortedArrayUsingSelector:@selector(compare:)];
}
- (NSArray *)sortWith:(NSComparator)comparator
{
    return [self.asArray sortedArrayUsingComparator:comparator];
}
- (NSArray *(^)(NSComparator))sortWith
{
    return ^NSArray *(NSComparator comparator) {
        return [self sortWith:comparator];
    };
}

- (NSArray *)sortBy:(EKMapping)block
{
    return self.map(^(id i){
        return @[block(i), i];
    }).sort.map(^(id a) {
        return a[1];
    });
}
- (NSArray *(^)(EKMapping))sortBy
{
    return ^NSArray *(EKMapping block) {
        return [self sortBy:block];
    };
}

- (id)find:(EKPredicate)block
{
    id next;
    EKEnumerator *e = self.asEnumerator;
    while ((next = e.next)) {
        if (block(next)) {
            return next;
        }
    }
    return nil;
}
- (id (^)(EKPredicate))find
{
    return ^id(EKPredicate block) {
        return [self find:block];
    };
}

- (id)inject:(SEL)binaryOperation
{
    return [self inject:nil withOperation:binaryOperation];
}
- (id)inject:(id)initial withOperation:(SEL)binaryOperation
{
    return [self reduce:initial withBlock:^id(id memo, id obj) {
        SuppressPerformSelectorLeakWarning(
            return [memo performSelector:binaryOperation withObject:obj];
        );
    }];
}
- (id<EKEnumerable> (^)(id (^)(id memo, id obj)))inject
{
    return ^id(id (^block)(id,id)) {
        return [self reduce:block];
    };
}

- (id<EKEnumerable>)reduce:(id (^)(id, id))block
{
    return [self reduce:nil withBlock:block];
}
- (id<EKEnumerable>)reduce:(id)initial withBlock:(id (^)(id, id))block
{
    // if the initial can be mutable (e.g., @[] or @{}), get a mutable copy
    __block id memo = [initial respondsToSelector:@selector(mutableCopyWithZone:)] ? [initial mutableCopy] : initial;

    [self each:^(id obj) {
        if (!memo)
            memo = obj;
        else
            memo = block(memo, obj);
    }];
    return memo;
}
- (id<EKEnumerable> (^)(id, ...))reduce
{
    return ^id<EKEnumerable>(id args, ...) {
        // determine if we're using the 1 or 2 arg form from the
        // type of the first arg
        BOOL isEmptyCollection = [args respondsToSelector:@selector(count)] && [args count] == 0;
        BOOL canBeMutable = [args respondsToSelector:@selector(mutableCopyWithZone:)];
        BOOL isNSNumber = [args isKindOfClass:[NSNumber class]];

        int argc = (isEmptyCollection || canBeMutable || isNSNumber) ? 2 : 1;

        // capture the arg(s)
        id memo = nil;
        id (^block)(id,id);
        if (argc == 2) {
            va_list arglist;
            va_start(arglist, args);
            memo = args;
            block = va_arg(arglist, id);
            va_end(arglist);
        }
        else {
            block = args;
        }

        // execute the real implementation of reduce:
        return [self reduce:memo withBlock:block];
    };
}

@end


#pragma mark -

@implementation NSObject (includeEKEnumerable)

+ (void)includeEKEnumerable
{
    unsigned int methodCount;
    Method *methods = class_copyMethodList([EKEnumerable class], &methodCount);

    for (int i = 0; i < methodCount; i++) {
        SEL name = method_getName(methods[i]);
        IMP imp = method_getImplementation(methods[i]);
        const char *types = method_getTypeEncoding(methods[i]);

        class_addMethod([self class], name, imp, types);
    }

    free(methods);
}

@end
