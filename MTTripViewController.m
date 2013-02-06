//
//  MTFirstViewController.m
//  MileTracker
//
//  Created by Stine Richvoldsen on 12/14/12.
//  Copyright (c) 2012 Focus43. All rights reserved.
//

#import "MTTripViewController.h"
#import "NSDate+TCUtils.h"
#import "UnsyncedObject.h"
#import "Reachability.h"

@interface MTTripViewController ()

- (void)showCannotSaveAlert;
- (void)dateOrTimeFieldTouched:(UITextField *)touchedField;
- (void)registerForKeyboardNotifications;
- (void)dismissKeyboard;
- (void)saveLocalVersionObjectData:(NSDictionary *)objData withNewFlag:(BOOL)flag objectId:(NSString *)objectId;

@property (strong, nonatomic) UITextField *activeTextField;
@property CGPoint originalCenter;
@property (nonatomic, strong) Reachability *networkReachability;
@property (nonatomic, strong) MBProgressHUD *hud;

@end

@implementation MTTripViewController

// Can't help myself. Still doing this...
@synthesize dateField, titleField, startOdometerField, endOdometerField;
@synthesize selectedDate;
@synthesize originalCenter, activeTextField, scrollView;
@synthesize trip, numberFormatter, networkReachability;
@synthesize actionSheetPicker = _actionSheetPicker;
@synthesize hud=_hud;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.view setBackgroundColor:[MTViewUtils backGroundColor]];
    
    if ( !self.numberFormatter ) {
        self.numberFormatter = [[NSNumberFormatter alloc] init];
        [self.numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    }

    [self registerForKeyboardNotifications];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                               initWithTarget:self
                               action:@selector(dismissKeyboard)];

    [self.scrollView addGestureRecognizer:tap];
    
    self.networkReachability = [Reachability reachabilityForInternetConnection];
        
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.originalCenter = self.view.center;
        
    // if editing
    if (self.trip) {
        self.titleField.text = [self.trip objectForKey:@"title"];
        self.dateField.text = [self.trip tr_dateToString];
        self.startOdometerField.text = [self.trip tr_startOdometerToString];
        self.endOdometerField.text = [self.trip tr_endOdometerToString];
    }

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)showCannotSaveAlert
{
    UIAlertView *cannotSaveAlert = [[UIAlertView alloc] initWithTitle:@"Uh oh..." message:@"You must enter a date and destination" delegate:nil cancelButtonTitle:@"Duh!" otherButtonTitles:nil];
    [cannotSaveAlert show];
}

- (IBAction)saveButtonTouched:(id)sender
{
    // dismiss keyboard
    [self.titleField resignFirstResponder];
    [self.dateField resignFirstResponder];
    [self.startOdometerField resignFirstResponder];
    [self.endOdometerField resignFirstResponder];
    
    if ( !([self.dateField.text isEqualToString:@""] || [self.titleField.text isEqualToString:@""]) ) {
        
        NSNumber *start = [self.numberFormatter numberFromString:self.startOdometerField.text];
        if (!start) start = [NSNumber numberWithInt:0];
        
        NSNumber *end = [self.numberFormatter numberFromString:self.endOdometerField.text];
        if (!end) end = [NSNumber numberWithInt:0];
        
        PFUser *currentUser = [PFUser currentUser];
        NSDate *tripDate = self.selectedDate ? self.selectedDate : [self.trip objectForKey:@"date"];
        NSString *objectId = (self.trip) ? self.trip.objectId : @"";
        
        NSArray *data = [NSArray arrayWithObjects:self.titleField.text, tripDate, start, end, currentUser, nil];
        NSArray *keys = [NSArray arrayWithObjects:@"title", @"date", @"startOdometer", @"endOdometer", @"user", nil];
        NSMutableDictionary *objData = [NSDictionary dictionaryWithObjects:data forKeys:keys];
        
        PFObject *tripToSave = [PFObject tr_objectWithData:objData objectId:objectId];
        
        BOOL isNewTrip = YES;
        if (self.trip) {
            isNewTrip = NO;
        }
                
        NetworkStatus networkStatus = [self.networkReachability currentReachabilityStatus];
        
        if ( networkStatus == NotReachable ) {
            
            [self saveLocalVersionObjectData:objData withNewFlag:isNewTrip objectId:objectId];
            
        } else {
            
            if (!self.hud) {
                _hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
                self.hud.delegate = self;
            }
            
            self.hud.mode		= MBProgressHUDModeIndeterminate;
            self.hud.labelText	= @"Saving trip";
            self.hud.margin		= 30;
            self.hud.yOffset	= 30;
            [self.hud show:YES];
            
            [tripToSave saveInBackgroundWithBlock: ^(BOOL succeeded, NSError *error) {
                if (succeeded) {
                    UIAlertView *successAlert = [[UIAlertView alloc] initWithTitle:@"Yessss!" message:@"Trip was saved" delegate:nil cancelButtonTitle:@"Sweet!" otherButtonTitles:nil];
                    [successAlert show];
                    
                    if (self.hud) {
                        [self.hud hide:YES afterDelay:0.5];
                    }
                    
                } else {
                    [self saveLocalVersionObjectData:objData withNewFlag:isNewTrip objectId:objectId];
                }
            }];
            
        }
        
        if ( !self.trip ) {
            self.titleField.text = @"";
            self.dateField.text = @"";
            self.startOdometerField.text = @"";
            self.endOdometerField.text = @"";
        }
        
    } else {
        [self showCannotSaveAlert];
    }
}

- (void)saveLocalVersionObjectData:(NSDictionary *)objData withNewFlag:(BOOL)isNew objectId:(NSString*)objectId
{
    UIAlertView *problemAlert = [[UIAlertView alloc] initWithTitle:@"Network problem" message:@"You're offline, so the trip will be saved locally and backed up in the cloud when you're back online." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [problemAlert show];
        
    if ( isNew ) {
        [UnsyncedObject createObjectForEntityDecriptionAndLoadWithData:objData objectId:nil];
    } else {        
        NSError *error = nil;
        NSArray *results = [UnsyncedObject fetchTripsWithId:objectId error:error];
        
        if ( !error && results && [results count] > 0 ) {
            // record already exists
            [[results objectAtIndex:0] setValue:objData forKey:@"unsyncedObjInfo"];
            [[[MTCoreDataController sharedInstance] managedObjectContext] save:&error];
            
        } else {
            [UnsyncedObject createObjectForEntityDecriptionAndLoadWithData:objData objectId:objectId];
        }
        
    }
    
    // Save object right away, to have access to it in the log
    [[MTCoreDataController sharedInstance] saveContext];
    
    if (self.hud) {
        [self.hud hide:YES afterDelay:0.5];
    }
}

- (void)dateOrTimeFieldTouched:(UITextField *)touchedField
{
    [self.titleField resignFirstResponder];
    [self.startOdometerField resignFirstResponder];
    [self.endOdometerField resignFirstResponder];
    
    NSDate *pickerDate = self.trip ? [self.trip objectForKey:@"date"] : [NSDate date];
    _actionSheetPicker = [[ActionSheetDatePicker alloc] initWithTitle:@""
                                                       datePickerMode:UIDatePickerModeDate
                                                         selectedDate:pickerDate
                                                               target:self
                                                               action:@selector(dateWasSelected:element:)
                                                               origin:touchedField];
    
    [self.actionSheetPicker addCustomButtonWithTitle:@"Today" value:[NSDate date]];
    [self.actionSheetPicker addCustomButtonWithTitle:@"Yesterday" value:[[NSDate date] TC_dateByAddingCalendarUnits:NSDayCalendarUnit amount:-1]];
    self.actionSheetPicker.hideCancel = NO;
    [self.actionSheetPicker showActionSheetPicker];
}

- (void)dateWasSelected:(NSDate *)selDate element:(id)element
{
    self.selectedDate = selDate;
    UITextField *currentField = (UITextField *)element;
    currentField.text = [[[MTFormatting sharedUtility] dateFormatter] stringFromDate:selDate];
}

- (NSDate *)dateSetToMidnightUsingDate:(NSDate *)aDate
{
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *components = [gregorian components:NSUIntegerMax fromDate:aDate];
    [components setHour:0];
    [components setMinute:0];
    [components setSecond:0];
    
    return [gregorian dateFromComponents: components];
}

// Sent to the delegate when a PFUser is signed up.
- (void)signUpViewController:(PFSignUpViewController *)signUpController didSignUpUser:(PFUser *)user {
    [self dismissModalViewControllerAnimated:YES]; // Dismiss the PFSignUpViewController
}

// Sent to the delegate when the sign up attempt fails.
- (void)signUpViewController:(PFSignUpViewController *)signUpController didFailToSignUpWithError:(NSError *)error {
    NSLog(@"Failed to sign up...");
}

// Sent to the delegate when the sign up screen is dismissed.
- (void)signUpViewControllerDidCancelSignUp:(PFSignUpViewController *)signUpController {
    NSLog(@"User dismissed the signUpViewController");
}

# pragma mark - Text Field Delegate methods

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if ( textField == self.dateField ) {
        [self dateOrTimeFieldTouched:textField];
        
        return false;
    }
    
    return true;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    self.activeTextField = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    self.activeTextField = nil;
}

# pragma mark - keyboard notification handlers 

- (void)dismissKeyboard
{
    [self.activeTextField resignFirstResponder];
}

- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];    
}

- (void)keyboardWasShown:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    
    if ( !scrollView.contentInset.bottom == contentInsets.bottom ) {
        scrollView.contentInset = contentInsets;
        scrollView.scrollIndicatorInsets = contentInsets;
    }
    
    CGRect aRect = self.view.frame;
    aRect.size.height -= kbSize.height;
    if (!CGRectContainsPoint(aRect, self.activeTextField.frame.origin) ) {
        CGPoint scrollPoint = CGPointMake(0.0, self.activeTextField.frame.origin.y - 25);
        [scrollView setContentOffset:scrollPoint animated:YES];
    }
}

- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    scrollView.contentInset = contentInsets;
    scrollView.scrollIndicatorInsets = contentInsets;
    
    // This scrolls the screen back to the top. Not sure I like it....
    CGPoint scrollPoint = CGPointMake(0.0, 0.0);
    [scrollView setContentOffset:scrollPoint animated:YES];
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController
{
    NSLog(@"didSelectViewController");
}

@end
