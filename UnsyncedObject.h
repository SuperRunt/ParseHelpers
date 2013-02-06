//
//  UnsyncedObject.h
//  MileTracker
//
//  Created by Stine Richvoldsen on 1/11/13.
//  Copyright (c) 2013 Focus43. All rights reserved.
//

#import <CoreData/CoreData.h>
#import <Parse/Parse.h>

@interface UnsyncedObject : NSManagedObject

@property (nonatomic, strong) PFObject *unsyncedObjInfo;
@property (nonatomic, strong) NSNumber *isNew;
@property (nonatomic, strong) NSDate *savedTime;
@property (nonatomic, strong) NSString *objectId;

+ (UnsyncedObject *)createObjectForEntityDecriptionAndLoadWithData:(NSDictionary *)objData objectId:(NSString *)objectId;
+ (NSArray *)fetchTripsMatching:(NSDate *)creationDate error:(NSError *)error;
+ (NSArray *)fetchTripsWithId:(NSString *)objectId error:(NSError *)error;

@end
