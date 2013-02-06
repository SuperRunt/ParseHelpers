//
//  MTUnsyncedObjectValueTransformer.m
//  MileTracker
//
//  Created by Stine Richvoldsen on 1/15/13.
//  Copyright (c) 2013 Focus43. All rights reserved.
//

#import "MTUnsyncedObjectValueTransformer.h"

@implementation MTUnsyncedObjectValueTransformer

+ (Class)transformedValueClass
{
	return [NSData class];
}

+ (BOOL)allowsReverseTransformation
{
	return YES;
}

- (id)transformedValue:(id)value
{
    NSString * error;
   
    return [NSPropertyListSerialization dataFromPropertyList:value format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
     
}

- (id)reverseTransformedValue:(id)value
{
    NSError *error;
    NSMutableDictionary *objectData = [NSPropertyListSerialization propertyListWithData:value options:NSPropertyListMutableContainersAndLeaves format:nil error:&error];
    // create an empty PFObject with stored object id (this needs to be set here so Parse doesn't think this is a new object)
    PFObject *obj = [PFObject objectWithoutDataWithClassName:kPFObjectClassName objectId:[objectData objectForKey:@"objectId"]];
    // objectId isn't valid PFObject key/value so we remove it here
    [objectData removeObjectForKey:@"objectId"];
    // set user object here 
    [objectData setObject:[PFUser currentUser] forKey:@"user"];
    // add all the data to the empty object
    return [objbj tr_updateWithData:objectData];
}

@end

