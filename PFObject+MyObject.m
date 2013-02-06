/*
  PFObject+MyObject.m
  MileTracker

  Created by Stine Richvoldsen on 1/24/13.
  Copyright (c) 2013 Focus43. All rights reserved.
    
  Since PFObject can't be subclassed, I have created a category with a few utility methods. 
 
*/

#import "PFObject+MyObject.h"

@implementation PFObject (MyObject)

+ (PFObject *)tr_objectWithData:(id)data objectId:(NSString *)objectId
{
    PFObject *syncObj;
    
    if ( objectId && ![objectId isEqualToString:@""] ) {
        syncObj = [PFObject objectWithoutDataWithClassName:kPFObjectClassName objectId:objectId];
    } else {
        syncObj = [PFObject objectWithClassName:kPFObjectClassName];
    }
    
    NSMutableDictionary *dataDict = [NSMutableDictionary dictionaryWithCapacity:0];
    
    if ( [data isKindOfClass:[PFObject class]]) {
        for (NSString * key in [data allKeys]) {
            [dataDict  setObject:data[key] forKey:key];
        }
    } else {
        [dataDict addEntriesFromDictionary:data];
    }
    
    [dataDict setObject:[PFUser currentUser] forKey:@"user"];
    
    return [syncObj tr_updateWithData:dataDict];
}


- (PFObject *)tr_updateWithData:(NSDictionary *)data
{
    if (data) {
        NSArray *keys = [data allKeys];
        for (NSString *key in keys) {
            [self setObject:[data objectForKey:key] forKey:key];
        }
    }
    
    return self;
}

- (void)syncWithCloudAndDeleteManagedObject:(NSManagedObject *)obj
{
    [self saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            NSManagedObject *aManagedObject = obj;
            NSManagedObjectContext *context = [aManagedObject managedObjectContext];
            [context deleteObject:aManagedObject];
            NSError *error;
            if (![context save:&error]) {
                NSLog(@"can't delete the object- error : %@", error);
            } else {
                NSLog(@"deleted the object");
            }
        } else {
            NSLog(@"sync error = %@", error);
        }
    }];
}

- (void)deleteFromCloudAndDeleteManagedObject:(NSManagedObject *)obj
{
    [self deleteInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            NSManagedObject *aManagedObject = obj;
            NSManagedObjectContext *context = [aManagedObject managedObjectContext];
            [context deleteObject:aManagedObject];
            NSError *error;
            if (![context save:&error]) {
                NSLog(@"can't delete the object- error : %@", error);
            } else {
                NSLog(@"deleted the object");
            }
        } else {
            NSLog(@"delete error = %@", error);
        }
    }];
}

- (NSString *)tr_decimalToString:(NSNumber *)aNumber
{
    return [[[MTFormatting sharedUtility] numberFormatter] stringFromNumber:aNumber];
}

- (NSString *)tr_dateToString
{
    return [[[MTFormatting sharedUtility] dateFormatter] stringFromDate:[self objectForKey:@"date"]];
}


@end
