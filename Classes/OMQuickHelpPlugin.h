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
@public
	NSSet *_quickHelpIntegrationStyleMenuItems;
	NSSet *_searchDocumentationIntegrationStyleMenuItems;
    NSMenu *_dashMenu;
}

@property (assign) BOOL didSwizzle;
@property (assign) NSInteger swizzleRetryCount;

+ (instancetype)sharedInstance;
+ (id)handlerForAction:(SEL)arg1 withSelectionSource:(id)arg2;
+ (id)currentEditor;
+ (void)clearLastQueryResult;

@end
