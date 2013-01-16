//
//  OMColorHelper.h
//  OMColorHelper
//
//  Created by Ole Zorn on 09/07/12.
//
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface OMQuickHelpPlugin : NSObject
{
    NSMenuItem *toggleDashItem;
    
    NSMenuItem *searchOptionsItem;
    NSMenuItem *search_all_item;
    NSMenuItem *search_ios_item;
    NSMenuItem *search_osx_item;
}

- (void)toggleOpenInDashEnabled:(id)sender;

@end
