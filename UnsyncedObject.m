//
//  UnsyncedObject.m
//  MileTracker
//
//  Created by Stine Richvoldsen on 1/11/13.
//  Copyright (c) 2013 Focus43. All rights reserved.
//

#import "UnsyncedObject.h"

@implementation UnsyncedObject

@dynamic unsyncedObjInfo; // This is a transformable type
@dynamic isNew;
@dynamic savedTime;
@dynamic objectId;


+ (UnsyncedObject *)createObjectForEntityDecriptionAndLoadWithData:(NSDictionary *)objData objectId:(NSString *)objectId
{
    UnsyncedObject *unsyncedObject = (UnsyncedObject *)[NSEntityDescription insertNewObjectForEntityForName:kUnsyncedObjectEntityName
                                                                               inManagedObjectContext:[[MTCoreDataController sharedInstance] managedObjectContext]];
    
    BOOL isNew = (objectId) ? NO : YES;
    
    if (objData) {
        NSMutableDictionary *objDict = [NSMutableDictionary dictionaryWithDictionary:tripData];
        [objDict removeObjectForKey:@"user"];
        
        [unsyncedObject setValue:tripDict forKey:@"unsyncedObjInfo"];
        [unsyncedObject setValue:[tripDict objectForKey:@"date"] forKey:@"savedTime"];
        [unsyncedObject setValue:[PFUser currentUser].objectId forKey:@"userId"];
        
    } else {
        [unsyncedObject setValue:nil forKey:@"unsyncedObjInfo"];
    }
    
    [unsyncedObject setValue:[NSNumber numberWithBool:isNew] forKey:@"isNew"];
    [unsyncedObject setValue:objectId forKey:@"objectId"];
    [unsyncedObject setValue:[PFUser currentUser].objectId forKey:@"userId"];
    
    return unsyncedObject;
}

+ (NSArray *)fetchObjectsMatching:(NSDate *)creationDate error:(NSError *)error
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:kUnsyncedObjectEntityName inManagedObjectContext:[[MTCoreDataController sharedInstance] managedObjectContext]];
    [request setEntity:entity];
    
    // All this is to account for storage making slight changes in the timestamp (really?? anyway:)
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSUInteger unitFlags = NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
    NSDateComponents *searchDateComps = [calendar components:unitFlags fromDate:creationDate];
    NSDateComponents *startComps = [searchDateComps copy];
    NSDateComponents *endComps = [searchDateComps copy];
    [startComps setSecond:searchDateComps.second - 2];
    [endComps setSecond:searchDateComps.second + 2];
    NSDate *startDate = [calendar dateFromComponents:startComps];
    NSDate *endDate = [calendar dateFromComponents:endComps];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"((savedTime >= %@) AND (savedTime <= %@))",startDate,endDate];
    [request setPredicate:predicate];
    
    return [[[MTCoreDataController sharedInstance] managedObjectContext] executeFetchRequest:request error:&error];
}

+ (NSArray *)fetchObjectsWithId:(NSString *)objectId error:(NSError *)error
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:kUnsyncedObjectEntityName inManagedObjectContext:[[MTCoreDataController sharedInstance] managedObjectContext]];
    [request setEntity:entity];
    
    NSPredicate *objectPredicate = [NSPredicate predicateWithFormat:@"(objectId == %@)",objectId];
    // we only want the objects saved by current user 
    NSPredicate *userPredicate = [NSPredicate predicateWithFormat:@"(userId == %@)",[PFUser currentUser].objectId];
    
    NSArray *searchPredicatesArray = [NSArray arrayWithObjects:objectPredicate, userPredicate, nil];
    NSPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:searchPredicatesArray];
    [request setPredicate:predicate];
    
    return [[[MTCoreDataController sharedInstance] managedObjectContext] executeFetchRequest:request error:&error];
}

@end
