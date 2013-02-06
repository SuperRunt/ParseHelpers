//
//  UnsyncedTrip.h
//  MileTracker
//
//  Created by Stine Richvoldsen on 1/11/13.
//  Copyright (c) 2013 Focus43. All rights reserved.
//

#import <CoreData/CoreData.h>
#import <Parse/Parse.h>

@interface UnsyncedTrip : NSManagedObject

@property (nonatomic, strong) PFObject *unsyncedObjInfo;
@property (nonatomic, strong) NSNumber *isNew;
@property (nonatomic, strong) NSDate *savedTime;
@property (nonatomic, strong) NSString *objectId;

+ (UnsyncedTrip *)createTripForEntityDecriptionAndLoadWithData:(NSDictionary *)tripData objectId:(NSString *)objectId;
+ (NSArray *)fetchTripsMatching:(NSDate *)creationDate error:(NSError *)error;
+ (NSArray *)fetchTripsWithId:(NSString *)objectId error:(NSError *)error;

@end
