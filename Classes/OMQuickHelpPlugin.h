//
//  OMQuickHelpPlugin.h
//  OMQuickHelpPlugin
//
//  Created by Ole Zorn on 09/07/12.
//
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface OMQuickHelpPlugin : NSObject {
	NSSet *_quickHelpIntegrationStyleMenuItems;
	NSSet *_searchDocumentationIntegrationStyleMenuItems;
}

+ (id)handlerForAction:(SEL)arg1 withSelectionSource:(id)arg2;
+ (id)currentEditor;
+ (void)clearLastQueryResult;

@end
