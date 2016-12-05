//
//  Filter.m
//  TaskExplorer
//
//  Created by Patrick Wardle on 2/21/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Task.h"
#import "Consts.h"
#import "Filter.h"
#import "ItemBase.h"
#import "Utilities.h"
#import "Connection.h"
#import "AppDelegate.h"

//binary filter keywords
NSString * const BINARY_KEYWORDS[] = {@"#apple", @"#nonapple", @"#signed", @"#unsigned", @"#flagged", @"#encrypted", @"#packed", @"#notfound"};

@implementation Filter

//@synthesize fileFilters;
@synthesize binaryFilters;

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //alloc file filter keywords
        //fileFilters = [NSMutableArray array];
        
        //alloc binary filter keywords
        binaryFilters = [NSMutableArray array];

        //init binary filters
        for(NSUInteger i=0; i < sizeof(BINARY_KEYWORDS)/sizeof(BINARY_KEYWORDS[0]); i++)
        {
            //add
            [self.binaryFilters addObject:BINARY_KEYWORDS[i]];
        }
    }
    
    return self;
}

//determine if search string is #keyword
-(BOOL)isKeyword:(NSString*)searchString
{
    //for now just check in binary keywords
    return [self.binaryFilters containsObject:searchString];
}

//filter tasks
// ->name, path, pid
-(void)filterTasks:(NSString*)filterText items:(NSMutableDictionary*)items results:(NSMutableArray*)results
{
    //task
    Task* task = nil;
    
    //first reset any previous filter'd items
    [results removeAllObjects];
    
    //process #keyword filtering
    // ->note: already checked its a full/matching keyword
    if(YES == [filterText hasPrefix:@"#"])
    {
        //prep UI for filtering
        // ->config/show overlay, etc
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]) prepUIForFiltering:PANE_TOP];
        
        //in background filter by keyword
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //nap a 1/2second to let message show up
            [NSThread sleepForTimeInterval:0.5];
            
            //filter
            // ->calls back in UI to refresh when done!
            [self filterByKeyword:(NSString*)filterText items:items.allValues results:(NSMutableArray*)results];
            
        });
    }
    
    //not keyword
    // ->do normal search here...
    else
    {
        //sync
        @synchronized(items)
        {

        //iterate over all tasks
        for(NSNumber* taskKey in items)
        {
            //extract task
            task = items[taskKey];
            
            //check path first
            // ->mostly likely to match
            if( (nil != task.binary.path) &&
                (NSNotFound != [task.binary.path rangeOfString:filterText options:NSCaseInsensitiveSearch].location) )
            {
                //save match
                [results addObject:task];
                
                //next
                continue;
            }
            
            //check name
            if( (nil != task.binary.name) &&
                (NSNotFound != [task.binary.name rangeOfString:filterText options:NSCaseInsensitiveSearch].location) )
            {
                //save match
                [results addObject:task];
                
                //next
                continue;
            }
            
            //check pid
            if(NSNotFound != [[task.pid stringValue] rangeOfString:filterText options:NSCaseInsensitiveSearch].location)
            {
                //save match
                [results addObject:task];
                
                //next
                continue;
            }

        }//all tasks
        
        }//sync
        
    }//normal filtering
        
    return;
}

//filter tasks
// ->name, path, pid
-(void)filterByKeyword:(NSString*)filterText items:(NSArray*)items results:(NSMutableArray*)results
{
    //pane
    NSUInteger pane = PANE_TOP;

    //sync
    @synchronized(items)
    {
        //sanity check
        if(0 == items.count)
        {
            //bail
            goto bail;
        }
    
        //handle tasks
        if(YES == [items.firstObject isKindOfClass:[Task class]])
        {
            //set pane
            pane = PANE_TOP;
            
            //iterate over all items
            for(id item in items)
            {
                //check if task's binary matches filter
                if(YES == [self binaryFulfillsKeyword:filterText binary:((Task*)item).binary])
                {
                    //add
                    [results addObject:item];
                }
            }
        }
        //handle dylibs
        else if(YES == [items.firstObject isKindOfClass:[Binary class]])
        {
            //set pane
            pane = PANE_BOTTOM;
            
            //iterate over all items
            for(id item in items)
            {
                //check if dylib's binary matches filter
                if(YES == [self binaryFulfillsKeyword:filterText binary:((Binary*)item)])
                {
                    //add
                    [results addObject:item];
                }
            }
        }
    
    } //sync
    
    //tell the UI we are done
    dispatch_async(dispatch_get_main_queue(), ^{
        
        //finalize UI
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]) finalizeFiltration:pane];
        
    });
    
//bail
bail:
    
    return;
}

//filter dylibs and files
// ->name and path
-(void)filterFiles:(NSString*)filterText items:(NSMutableArray*)items results:(NSMutableArray*)results
{
    //first reset filter'd items
    [results removeAllObjects];
    
    //process #keyword filtering for dylibs
    // ->note: already checked its a full/matching keyword
    if( (YES == [filterText hasPrefix:@"#"]) &&
        (YES == [items.firstObject isKindOfClass:[Binary class]]) )
    {
        //prep UI for filtering
        // ->config/show overlay, etc
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]) prepUIForFiltering:PANE_BOTTOM];
        
        //in background filter by keyword
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //nap a 1/2second to let message show up
            [NSThread sleepForTimeInterval:0.5];
            
            //filter
            // ->calls back in UI to refresh when done!
            [self filterByKeyword:(NSString*)filterText items:items results:(NSMutableArray*)results];
            
        });
    }

    //not keyword
    // ->do normal search here...
    else
    {
        //sync
        @synchronized(items)
        {
        
        //iterate over all items
        for(ItemBase* item in items)
        {
            //check path first
            // ->most likely to match
            if( (nil != item.path) &&
                (NSNotFound != [item.path rangeOfString:filterText options:NSCaseInsensitiveSearch].location) )
            {
                //save match
                [results addObject:item];
                
                //next
                continue;
            }

            //check name
            if( (nil != item.name) &&
                (NSNotFound != [item.name rangeOfString:filterText options:NSCaseInsensitiveSearch].location) )
            {
                //save match
                [results addObject:item];
                
                //next
                continue;
            }
            
        }//all items
            
        }//sync
        
    }//normal filtering
    
    return;
}

//filter network connections
-(void)filterConnections:(NSString*)filterText items:(NSMutableArray*)items results:(NSMutableArray*)results
{
    //first reset filter'd items
    [results removeAllObjects];
    
    //sync
    @synchronized(items)
    {
        //iterate over all tasks
        for(Connection* item in items)
        {
            //check local ip
            if( (nil != item.localIPAddr) &&
                (NSNotFound != [item.localIPAddr rangeOfString:filterText options:NSCaseInsensitiveSearch].location) )
            {
                //save match
                [results addObject:item];
                
                //next
                continue;
            }
            
            //check local port
            if( (nil != item.localIPAddr) &&
                (NSNotFound != [[NSString stringWithFormat:@"%d", [item.localPort unsignedShortValue]] rangeOfString:filterText options:NSCaseInsensitiveSearch].location) )
            {
                //save match
                [results addObject:item];
                
                //next
                continue;
            }
            
            //check remote ip
            if( (nil != item.remoteIPAddr) &&
                (NSNotFound != [item.remoteIPAddr rangeOfString:filterText options:NSCaseInsensitiveSearch].location) )
            {
                //save match
                [results addObject:item];
                
                //next
                continue;
            }
            
            //check remote port
            if( (nil != item.remoteIPAddr) &&
                (NSNotFound != [[NSString stringWithFormat:@"%d", [item.remotePort unsignedShortValue]] rangeOfString:filterText options:NSCaseInsensitiveSearch].location) )
            {
                //save match
                [results addObject:item];
                
                //next
                continue;
            }
            
            //check family
            if( (nil != item.family) &&
                (NSNotFound != [item.family rangeOfString:filterText options:NSCaseInsensitiveSearch].location) )
            {
                //save match
                [results addObject:item];
                
                //next
                continue;
            }
            
            //check protocol
            if( (nil != item.proto) &&
                (NSNotFound != [item.proto rangeOfString:filterText options:NSCaseInsensitiveSearch].location) )
            {
                //save match
                [results addObject:item];
                
                //next
                continue;
            }
            
            //check state
            if( (nil != item.state) &&
                (NSNotFound != [item.state rangeOfString:filterText options:NSCaseInsensitiveSearch].location) )
            {
                //save match
                [results addObject:item];
                
                //next
                continue;
            }
            
            //check DNS name
            if( (nil != item.remoteName) &&
                (NSNotFound != [item.remoteName rangeOfString:filterText options:NSCaseInsensitiveSearch].location) )
            {
                //save match
                [results addObject:item];
                
                //next
                continue;
            }
            
        }//all connections
    
    }//sync
    
    return;
}

//check if a binary fulfills a keyword
-(BOOL)binaryFulfillsKeyword:(NSString*)keyword binary:(Binary*)binary
{
    //flag
    BOOL fulfills = NO;
    
    //handle '#apple'
    // ->signed by apple
    if( (YES == [keyword isEqualToString:@"#apple"]) &&
        (YES == [self isApple:binary]) )
    {
        //happy
        fulfills = YES;
        
        //bail
        goto bail;
    }
    
    //handle '#nonapple'
    // ->not signed by apple
    else if( (YES == [keyword isEqualToString:@"#nonapple"]) &&
        (YES != [self isApple:binary]) )
    {
        //happy
        fulfills = YES;
        
        //bail
        goto bail;
    }
    
    //handle '#signed'
    // ->signed
    else if( (YES == [keyword isEqualToString:@"#signed"]) &&
             (YES == [self isSigned:binary]) )
    {
        //happy
        fulfills = YES;
        
        //bail
        goto bail;
    }
    
    //handle '#unsigned'
    // ->not signed
    else if( (YES == [keyword isEqualToString:@"#unsigned"]) &&
             (YES != [self isSigned:binary]) )
    {
        //happy
        fulfills = YES;
        
        //bail
        goto bail;
    }
    
    //handle '#flagged'
    // ->flagged by VT
    else if( (YES == [keyword isEqualToString:@"#flagged"]) &&
             (YES == [self isFlagged:binary]) )
    {
        //happy
        fulfills = YES;
        
        //bail
        goto bail;
    }
    
    //handle '#encrypted'
    else if( (YES == [keyword isEqualToString:@"#encrypted"]) &&
             (YES == [self isEncrypted:binary]) )
    {
        //happy
        fulfills = YES;
        
        //bail
        goto bail;
    }
    
    //handle '#packed'
    else if( (YES == [keyword isEqualToString:@"#packed"]) &&
             (YES == [self isPacked:binary]) )
    {
        //happy
        fulfills = YES;
        
        //bail
        goto bail;
    }
    
    //handle '#notfound'
    else if( (YES == [keyword isEqualToString:@"#notfound"]) &&
             (YES == [self notFound:binary]) )
    {
        //happy
        fulfills = YES;
        
        //bail
        goto bail;
    }
    
//bail
bail:
    
    return fulfills;
}


//keyword filter '#apple' (and indirectly #nonapple)
// ->determine if binary is signed by apple
-(BOOL)isApple:(Binary*)item
{
    //flag
    BOOL isApple = NO;
    
    //make sure signing info has been generated
    // ->when no, generate it
    if(nil == item.signingInfo)
    {
        //generate
        [item generatedSigningInfo];
    }
    
    //check
    // ->just look at signing info
    if(YES == [item.signingInfo[KEY_SIGNING_IS_APPLE] boolValue])
    {
        //set flag
        isApple = YES;
    }
    
    return isApple;
}

//keyword filter '#signed' (and indirectly #unsigned)
// ->determine if binary is signed
-(BOOL)isSigned:(Binary*)item
{
    //flag
    BOOL isSigned = NO;
    
    //make sure signing info has been generated
    // ->when no, generate it
    if(nil == item.signingInfo)
    {
        //generate
        [item generatedSigningInfo];
    }
    
    //check
    // ->just look at signing info
    if(STATUS_SUCCESS == [item.signingInfo[KEY_SIGNATURE_STATUS] integerValue])
    {
        //set flag
        isSigned = YES;
    }
    
    return isSigned;
}

//keyword filter '#flagged'
// ->determine if binary is flagged by VT
-(BOOL)isFlagged:(Binary*)item
{
    //flag
    BOOL isFlagged = NO;
    
    //check
    // ->note: assumes that VT query has already completed...
    if( (nil != item.vtInfo) &&
        (0 != [item.vtInfo[VT_RESULTS_POSITIVES] unsignedIntegerValue]) )
    {
        //set flag
        isFlagged = YES;
    }
    
    return isFlagged;
}


//keyword filter '#encrypted'
// ->determine if binary is encrypted
-(BOOL)isEncrypted:(Binary *)item
{
    //make sure item was parsed
    if(nil == item.parser)
    {
        //parse
        [item parse];
        
        //save encrypted flag
        item.isEncrypted = [item.parser.binaryInfo[KEY_IS_ENCRYPTED] boolValue];
    }
    
    //set flag
    return item.isEncrypted;
}

//keyword filter '#packed'
// ->determine if binary is packed
-(BOOL)isPacked:(Binary *)item
{
    //make sure item was parsed
    if(nil == item.parser)
    {
        //parse
        [item parse];
        
        //save packed flag
        item.isPacked = [item.parser.binaryInfo[KEY_IS_PACKED] boolValue];
    }
    
    //set flag
    return item.isPacked;
}

//keyword filter '#notfound'
-(BOOL)notFound:(Binary *)item
{
    return item.notFound;
}

@end
