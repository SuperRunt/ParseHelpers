//
//  MTSecondViewController.h
//  MileTracker
//
//  Created by Stine Richvoldsen on 12/14/12.
//  Copyright (c) 2012 Focus43. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Parse/Parse.h>

@interface MTLogViewController : UITableViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, retain) NSString *className;

@end
