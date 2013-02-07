//
//  MTAppDelegate.m
//  MileTracker
//
//  Created by Stine Richvoldsen on 12/14/12.
//  Copyright (c) 2012 Focus43. All rights reserved.
//

#import "MTAppDelegate.h"
#import "Reachability.h"
#import "UnsyncedObject.h"
#import "MTUnsyncedObjectValueTransformer.h"

@interface MTAppDelegate ()

- (void)syncTrips;

@end

@implementation MTAppDelegate

static NSString * const kMTAFParseAPIApplicationId = @"Vd1Qs3EyW8r7JebCa7n9X6WXjvMxa711HJfKvWqJ";
static NSString * const kMTAFParseAPIKey = @"YRQphUyGjtoTh9uowBnaezq3LAaWFhKx0gysI546";

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [Parse setApplicationId:kMTAFParseAPIApplicationId clientKey:kMTAFParseAPIKey];
    
    // register transformer
    MTUnsyncedTripValueTransformer *transformer = [[MTUnsyncedTripValueTransformer alloc] init];
    [NSValueTransformer setValueTransformer:transformer forName:@"MTUnsyncedTripValueTransformer"];
    
    // reachability notifier
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(reachabilityChanged:) name: kReachabilityChangedNotification object: nil];
    
    //	hostReach = [Reachability reachabilityWithHostName: @"api.parse.com"];
    //	[hostReach startNotifier];
    //	[self updateInterfaceWithReachability: hostReach];
	
    internetReach = [Reachability reachabilityForInternetConnection];
	[internetReach startNotifier];
	[self updateInterfaceWithReachability: internetReach];
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.

}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    Reachability *networkReachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus networkStatus = [networkReachability currentReachabilityStatus];
    
    if (networkStatus != NotReachable) {
        [self syncObjects];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void) updateInterfaceWithReachability: (Reachability*) curReach
{
    //        NetworkStatus netStatus = [curReach currentReachabilityStatus];
    if(curReach == internetReach) {
        [self syncTrips];
    }
}


- (void)syncObjects
{
    // Fetch part could be moved to model..
    NSManagedObjectContext *moc = [[MTCoreDataController sharedInstance] managedObjectContext];
    NSEntityDescription *entityDescription = [NSEntityDescription
                                              entityForName:kUnsyncedObjectEntityName inManagedObjectContext:moc];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    
    NSError *error;
    NSArray *unsyncedArray = [moc executeFetchRequest:request error:&error];
    if ( unsyncedArray != nil && [unsyncedArray count] > 0 ) {
        // if you want to communicate with user...
        UIAlertView *syncAlert = [[UIAlertView alloc] initWithTitle:@"Just a sec" message:@"Syncing with cloud" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [syncAlert show];
        
        for ( UnsyncedTrip *obj in unsyncedArray ) {
            
            PFObject *unsyncedTrip;
            
            if ( obj.isNew == [NSNumber numberWithInt:1] ) {
                unsyncedTrip = [PFObject objectWithClassName:kPFObjectClassName];
                [unsyncedTrip tr_updateWithData:obj.unsyncedObjInfo];
            } else {
                unsyncedTrip = [PFObject objectWithoutDataWithClassName:kPFObjectClassName objectId:obj.objectId];
                [unsyncedTrip tr_updateWithData:obj.unsyncedObjInfo];
            }
            
            unsyncedTrip.ACL = [PFACL ACLWithUser:[PFUser currentUser]];
            
            if (obj.unsyncedObjInfo) {
                [unsyncedTrip syncWithCloudAndDeleteManagedObject:obj];
            } else {
                [unsyncedTrip deleteFromCloudAndDeleteManagedObject:obj];
            }
            
        }
        
    }
}

@end
