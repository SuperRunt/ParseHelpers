Parse Helpers for iOS

Parse (parse.com) is a great alternative to creating your own service for storage of data, 
but I ran into some issues with the Parse iOS SDK. Mostly dealing with creating, updating 
and deleting of PFObjects while offline. There's obviously more than one way to solve 
this, and I got lots of inspiration from the interwebs. Figured I'd share my solution in 
hopes it could help out someone else. 

PFObject can't be subclassed, so I created a category with a few utility methods and some 
methods for creating and syncing objects. 

When offline, I store any updates or new entries using CoreData. You can see the data 
structure and methods creating and fetching stored objects in the UnsyncedObjects class.

In the app delegate, you'll see how I sync the data with the server when back online. 

I tried to use the PFQueryTableViewController, but I couldn't since the objects property 
(the list of PFObjects returned when the controller runs it's queryForTable). The 
LogViewController is a UITableViewController subclass, and it has a method called 
syncWithUnsavedData that 'mixes' the cached objects and the objects that are in the 
persistent store. It's a little messy, but it works...

The TripViewController deals with creating new and updating existing objects while offline. 
