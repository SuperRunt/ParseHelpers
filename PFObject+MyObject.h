/*
 PFObject+MyObject.m
 MileTracker
 
 Created by Stine Richvoldsen on 1/24/13.
 Copyright (c) 2013 Focus43. All rights reserved.
 
 Since PFObject can't be subclassed, I have created a category with a few utility methods.
 
 */

#import <Parse/Parse.h>

@interface PFObject (MyObject)

+ (PFObject *)tr_objectWithData:(id)data objectId:(NSString *)objectId;

- (PFObject *)tr_updateWithData:(NSDictionary *)data;
- (void)deleteFromCloudAndDeleteManagedObject:(NSManagedObject *)obj;
- (void)syncWithCloudAndDeleteManagedObject:(NSManagedObject *)obj;

- (NSString *)tr_decimalToString:(NSNumber *)aNumber;
- (NSString *)tr_dateToString;

@end
