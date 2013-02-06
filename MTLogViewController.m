//
//  MTSecondViewController.m
//  MileTracker
//
//  Created by Stine Richvoldsen on 12/14/12.
//  Copyright (c) 2012 Focus43. All rights reserved.
//

#import "MTLogViewController.h"
#import "MTLogTableViewCell.h"
#import "Reachability.h"
#import "UnsyncedObject.h"


@interface MTLogViewController ()

@property (nonatomic, strong) MBProgressHUD *hud;
@property (nonatomic, strong) NSArray *listObjects;
@property (nonatomic, strong) Reachability *networkReachability;
@property (nonatomic, assign) int objectsPerPage;
@property (nonatomic, assign) int currentPage;
@property (nonatomic, strong) NSIndexPath *loadMoreIdxPath;

- (void)loadObjects;
- (PFQuery *)queryForTable;
- (void)refreshTable;
- (void)syncWithUnsavedData;
- (UITableViewCell *)loadMoreTripsCell;
- (UITableViewCell *)noTripsCell;

@end

@implementation MTLogViewController

@synthesize dateFormatter, reloadObjectsOnBackAction, networkReachability;
@synthesize trips = _trips;
@synthesize hud=_hud;
@synthesize objectsPerPage, currentPage = _currentPage, loadMoreIdxPath = _loadMoreIdxPath;

- (id)initWithCoder:(NSCoder *)aCoder
{
    self = [super initWithCoder:aCoder];
    if (self) {
        
        // The className to query on
        self.className = kPFObjectClassName;
        
        self.objectsPerPage = 9;
        _currentPage = 1;
        
        self.networkReachability = [Reachability reachabilityForInternetConnection];
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Whether the built-in pagination is enabled
    self.tableView.pagingEnabled = YES;
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl = refreshControl;
    [refreshControl addTarget:self action:@selector(refreshTable) forControlEvents:UIControlEventValueChanged];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self loadObjects];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:kDetailViewSegue]) {
        MTTripViewController *tripDetailViewController = segue.destinationViewController;
        MTLogTableViewCell *cell = (MTLogTableViewCell *)sender;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        tripDetailViewController.trip = [self.objects objectAtIndex:indexPath.row];
        
        tripDetailViewController.navigationItem.title = @"Edit Details";
        
        self.reloadObjectsOnBackAction = true;
        
    } 
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)loadObjects
{
    if (!self.hud) {
        _hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        self.hud.delegate = self;
    }
    
    self.hud.mode		= MBProgressHUDModeIndeterminate;
    self.hud.labelText	= @"Loading Trips";
    self.hud.margin		= 30;
    self.hud.yOffset	= 30;
    [self.hud show:YES];

    NetworkStatus networkStatus = [networkReachability currentReachabilityStatus];
   
    [self.queryForTable findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        self.listObjects = objects;
        if ( networkStatus == NotReachable ) {
            [self syncWithUnsavedData];
        }

        if (!error) {
            [self.tableView reloadData];
            
            NSIndexPath *idxPath = [NSIndexPath indexPathForRow:[objects count]-9 inSection:0];
            [self.tableView scrollToRowAtIndexPath:idxPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
        }
        
        if (self.hud) {
            [self.hud hide:YES afterDelay:0.5];
        }
    
    }];
}

- (void)refreshTable
{
    NetworkStatus networkStatus = [networkReachability currentReachabilityStatus];
    
    if ( networkStatus == NotReachable ) {
        UIAlertView *problemAlert = [[UIAlertView alloc] initWithTitle:@"Network problem" message:@"Seems like your device is offline, so only cached results can be displayed." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [problemAlert show];
    } else {
        [self loadObjects];
        NSIndexPath *idxPath = [NSIndexPath indexPathForRow:0 inSection:0];
        [self.tableView scrollToRowAtIndexPath:idxPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
    
    [self.refreshControl endRefreshing];
}


- (PFQuery *)queryForTable
{
    PFQuery *query = [PFQuery queryWithClassName:self.className];
    
    [query whereKey:@"user" equalTo:[PFUser currentUser]];
    [query orderByDescending:@"date"];
    query.limit = self.objectsPerPage * _currentPage;
        
    // Since Pull To Refresh is enabled, query against the network by default.
    if (self.tableView.pagingEnabled) {
        query.cachePolicy = kPFCachePolicyNetworkOnly;
    }
    
    // If no objects are loaded in memory, we look to the cache first to fill the table
    // and then subsequently do a query against the network. Unless we're offline.
    NetworkStatus networkStatus = [networkReachability currentReachabilityStatus];

    if (self.listObjects.count == 0) {
        if ( networkStatus != NotReachable ) {
            query.cachePolicy = kPFCachePolicyCacheThenNetwork;
        } else {
            query.cachePolicy = kPFCachePolicyCacheOnly;
        }
    } else {
        if ( networkStatus == NotReachable ) {
            query.cachePolicy = kPFCachePolicyCacheOnly;
        }
    }
    
    return query;
}

- (void)syncWithUnsavedData
{
    NetworkStatus networkStatus = [networkReachability currentReachabilityStatus];
    
    if (networkStatus == NotReachable) {
        // Compare w unsynced objects
        // TODO: move fetch into the Model - getAll
        NSManagedObjectContext *moc = [[MTCoreDataController sharedInstance] managedObjectContext];
        NSEntityDescription *entityDescription = [NSEntityDescription entityForName:kUnsyncedObjectEntityName inManagedObjectContext:moc];
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        [request setEntity:entityDescription];
        
        NSError *error;
        NSArray *unsyncedFetchArray = [moc executeFetchRequest:request error:&error];
        
        NSMutableArray *unsyncedNewArray = [NSMutableArray arrayWithCapacity:0];
        NSMutableArray *unsyncedExistingArray = [NSMutableArray arrayWithCapacity:0];
        NSMutableArray *unsyncedDeletedArray = [NSMutableArray arrayWithCapacity:0];
        NSMutableArray *newObjectsArray = [NSMutableArray arrayWithCapacity:0];
       
        if ( [unsyncedFetchArray count] > 0 ) {
            
            for ( UnsyncedObject *obj in unsyncedFetchArray ) {
                
                if ( obj.unsyncedObjInfo ) {
                    PFObject *trip = [PFObject tr_objectWithData:obj.unsyncedObjInfo objectId:obj.objectId];
                    if ( ![obj.isNew boolValue] ) {
                        [unsyncedExistingArray addObject:trip];
                    } else {
                        [unsyncedNewArray addObject:trip];
                    }
                } else {
                    [unsyncedDeletedArray addObject:obj.objectId];
                }
            }
            
            // Set up the new object array
            [newObjectsArray addObjectsFromArray:unsyncedNewArray];
            [newObjectsArray addObjectsFromArray:self.listObjects];
                        
            if ( [unsyncedExistingArray count] > 0 ) {
                // compare trips and update self.objects with the latest data
                for ( PFObject *obj in unsyncedExistingArray ) {
                    NSPredicate *shouldUpdatePred = [NSPredicate predicateWithFormat:@"(objectId == %@)",obj.objectId];
                    
                    NSUInteger index = [newObjectsArray indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                        return [shouldUpdatePred evaluateWithObject:obj];
                    }];
                    
                    if ( index != NSNotFound ) {
                        [newObjectsArray replaceObjectAtIndex:index withObject:obj];
                    }
                }
            }
            
            if ( [unsyncedDeletedArray count] > 0 ) {
                
                for ( NSString *objId in unsyncedDeletedArray ) {
                    NSPredicate *shouldDeletePred = [NSPredicate predicateWithFormat:@"(objectId == %@)",objId];
                    
                    NSUInteger index = [newObjectsArray indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                        return [shouldDeletePred evaluateWithObject:obj];
                    }];
                    
                    if ( index != NSNotFound ) {
                        [newObjectsArray removeObjectAtIndex:index];
                    }
                }
            }
            
            self.listObjects = newObjectsArray;
        }
        
    }

    if (self.hud) {
        [self.hud hide:YES afterDelay:0.5];
    }
}

- (UITableViewCell *)loadMoreTripsCell
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    
    UILabel* loadMore =[[UILabel alloc]initWithFrame: cell.frame];
    loadMore.backgroundColor = [UIColor clearColor];
    loadMore.textAlignment = NSTextAlignmentCenter;
    loadMore.font = [UIFont boldSystemFontOfSize:18];
    if ( [self.listObjects count] > self.objectsPerPage ) {
        loadMore.text = @"Load more trips...";
    } else {
        loadMore.text = @"";
    }
    
    [cell addSubview:loadMore];
    
    cell.tag = kLoadCellTag;
    
    return cell;
}

- (UITableViewCell *)noTripsCell
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    
    UILabel* noTrips =[[UILabel alloc]initWithFrame: cell.frame];
    noTrips.backgroundColor = [UIColor clearColor];
    noTrips.textAlignment = NSTextAlignmentCenter;
    noTrips.font = [UIFont boldSystemFontOfSize:18];
    noTrips.text = @"You don't have any trips saved yet...";
    [cell addSubview:noTrips];
    
    cell.userInteractionEnabled = NO;
    cell.tag = kNoTripsCellTag;
    
    return cell;
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ( [self.listObjects count] == 0 ) {
        return [self noTripsCell];
    }
    
    if ( indexPath.row < [self.listObjects count] ) {
        
        MTLogTableViewCell *cell = nil;
        static NSString *CellIdentifier = kTripCellIdentifier;
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        
        if (cell == nil) {
            cell = [[MTLogTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        }
        
        PFObject *trip = [self.listObjects objectAtIndex:indexPath.row];
        cell.titleLabel.text = [trip objectForKey:@"title"];
        cell.dateLabel.text = [trip tr_dateToString];
        cell.distanceLabel.text = [trip tr_totalDistanceString];
        return cell;
        
    } else {
        _loadMoreIdxPath = indexPath;
        return [self loadMoreTripsCell];
        
    }
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.listObjects count] + 1;
}

 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
 {
     if (editingStyle == UITableViewCellEditingStyleDelete) {
         
         NetworkStatus networkStatus = [networkReachability currentReachabilityStatus];
         
         if (networkStatus == NotReachable) {
             PFObject *objectToDelete = [self.listObjects objectAtIndex:indexPath.row];
             
             NSError *error = nil;
             NSArray *results = [UnsyncedObject fetchTripsWithId:objectToDelete.objectId error:error];
             
             if ( !error && results && [results count] > 0 ) {
                 // record already exists => just delete it!delete from Core Data
                 [[[MTCoreDataController sharedInstance] managedObjectContext] deleteObject:[results objectAtIndex:0]];
             } else {
                 [UnsyncedObject createTripForEntityDecriptionAndLoadWithData:nil objectId:objectToDelete.objectId];
             }
             
             [[[MTCoreDataController sharedInstance] managedObjectContext] save:&error];
             if (error) {
                 NSLog(@"can't save");
             } else {
                 // Delete the row
                 [self loadObjects];
             }
             
         } else {
             
             [[self.listObjects objectAtIndex:indexPath.row] deleteInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                 
                 if (!succeeded) {
                     if ([error code] == kPFErrorConnectionFailed ) {
                         NSLog(@"connection failure: %@", error);
                     } else {
                         NSLog(@"error when deleting: %@", error);
                     }
                     
                 } else {
                     // Delete the row
                     [self loadObjects];
                 }
             }];
         }
         
     } 
 }

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ( indexPath.row == self.loadMoreIdxPath.row) {
        _currentPage ++;
        [self loadObjects];
    } else {
        [self performSegueWithIdentifier:kDetailViewSegue sender:self];
    }
}


@end
