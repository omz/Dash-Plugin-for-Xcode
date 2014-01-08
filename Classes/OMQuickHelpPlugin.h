//
//  OMColorHelper.h
//  OMColorHelper
//
//  Created by Ole Zorn on 09/07/12.
//
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface OMQuickHelpPlugin : NSObject {
	NSSet *_integrationStyleMenuItems;
}

+ (id)handlerForAction:(SEL)arg1 withSelectionSource:(id)arg2;
+ (id)currentEditor;
+ (void)clearLastQueryResult;

@end
