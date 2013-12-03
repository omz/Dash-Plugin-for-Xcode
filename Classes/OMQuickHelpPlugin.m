//
//  OMColorHelper.m
//  OMColorHelper
//
//  Created by Ole Zorn on 09/07/12.
//
//

#import "OMQuickHelpPlugin.h"
#import "JRSwizzle.h"

#define kOMSuppressDashNotInstalledWarning	@"OMSuppressDashNotInstalledWarning"
#define kOMOpenInDashStyle                  @"OMOpenInDashStyle"
#define kOMDashPlatformDetectionEnabled    @"OMDashPlatformDetectionEnabled"

typedef NS_ENUM(NSInteger, OMQuickHelpPluginIntegrationStyle) {
    OMQuickHelpPluginIntegrationStyleDisabled = 0,  // Disable this plugin altogether
    OMQuickHelpPluginIntegrationStyleQuickHelp,     // Search Dash instead of showing the "Quick Help" popup
    OMQuickHelpPluginIntegrationStyleReference      // Show the "Quick Help" popup, but search Dash instead
                                                    // of showing Xcode's documentation viewer (when the "Reference" link
                                                    // in the popup is clicked)
};

@interface NSObject (OMSwizzledMethods)

- (void)om_showQuickHelp:(id)sender;
- (void)om_handleLinkClickWithActionInformation:(id)info;
- (void)om_dashNotInstalledFallback;
- (BOOL)om_showQuickHelpForSearchString:(NSString *)searchString;
- (BOOL)om_shouldHandleLinkClickWithActionInformation:(id)info;
- (NSURL *)om_dashURLFromQuickHelpLinkActionInformation:(id)info;
- (BOOL)om_showQuickHelpForDashURL:(NSURL *)docsetURL;

@end

@implementation NSObject (OMSwizzledMethods)

- (void)om_showQuickHelp:(id)sender
{
	@try {
        OMQuickHelpPluginIntegrationStyle dashStyle = [[NSUserDefaults standardUserDefaults] integerForKey:kOMOpenInDashStyle];
        if (dashStyle == OMQuickHelpPluginIntegrationStyleDisabled) {
            //No, this is not an infinite loop because the method is swizzled:
            [self om_showQuickHelp:sender];
            return;
		}
		NSString *symbolString = [self valueForKeyPath:@"selectedExpression.symbolString"];
        if(symbolString.length)
        {
            if (dashStyle == OMQuickHelpPluginIntegrationStyleQuickHelp) {
                BOOL dashOpened = [self om_showQuickHelpForSearchString:symbolString];
                if (!dashOpened) {
                    [self om_dashNotInstalledFallback];
                }
            } else {
                // Show regular quick help--wait to search Dash until the user clicks on a link
                // this is not an infinite loop because the method is swizzled:
                [self om_showQuickHelp:sender];
                return;
            }
        }
        else
        {
            NSBeep();
        }
	}
	@catch (NSException *exception) {
		
	}
}

// The quick help popup is actually a web view, and the links are actual links.
// We examine the URL of any link clicked to see whether Xcode is trying to open a docset page
// (as opposed to a source file).
- (void)om_handleLinkClickWithActionInformation:(id)info {
    @try {
        if (![self om_shouldHandleLinkClickWithActionInformation:info]) {
            //No, this is not an infinite loop because the method is swizzled:
            [self om_handleLinkClickWithActionInformation:info];
            return;
        }

        // Dismiss the quick help popup
        [[self valueForKey:@"quickHelpController"] performSelector:@selector(closeQuickHelp)];

        NSURL *dashURL = [self om_dashURLFromQuickHelpLinkActionInformation:info];
        if (dashURL) {
            BOOL dashOpened = [self om_showQuickHelpForDashURL:dashURL];
            if (!dashOpened) {
                [self om_dashNotInstalledFallback];
            }
        }
        else
        {
            NSBeep();
        }
	}
    @catch (NSException *exception) {
        
    }
}

- (void)om_dashNotInstalledFallback
{
	//Fall back to default behavior:
	[self om_showQuickHelp:self];
	//Show a warning that Dash is not installed:
	BOOL showNotInstalledWarning = ![[NSUserDefaults standardUserDefaults] boolForKey:kOMSuppressDashNotInstalledWarning];
	if (showNotInstalledWarning) {
		NSAlert *alert = [NSAlert alertWithMessageText:@"Dash not installed" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"It looks like the Dash app is not installed on your system. Please visit http://kapeli.com/dash/ to get it."];
		[alert setShowsSuppressionButton:YES];
		[alert runModal];
		if ([[alert suppressionButton] state] == NSOnState) {
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:kOMSuppressDashNotInstalledWarning];
		}
	}
}

- (BOOL)om_showQuickHelpForSearchString:(NSString *)searchString
{
    searchString = [self om_appendActiveSchemeKeyword:searchString];
	NSPasteboard *pboard = [NSPasteboard pasteboardWithUniqueName];
	[pboard setString:searchString forType:NSStringPboardType];
	return NSPerformService(@"Look Up in Dash", pboard);
}

- (BOOL)om_shouldHandleLinkClickWithActionInformation:(id)info {
    OMQuickHelpPluginIntegrationStyle dashStyle = [[NSUserDefaults standardUserDefaults] integerForKey:kOMOpenInDashStyle];
    if (dashStyle != OMQuickHelpPluginIntegrationStyleReference) return NO;

    NSString *linkURLString = [[[info objectForKey:@"WebActionElementKey"] objectForKey:@"WebElementLinkURL"] absoluteString];
    BOOL linkOpensReference = [linkURLString rangeOfString:@".docset"].location != NSNotFound;
    return linkOpensReference;
}

- (NSURL *)om_dashURLFromQuickHelpLinkActionInformation:(id)info {
    NSURL *linkURL = [[info objectForKey:@"WebActionElementKey"] objectForKey:@"WebElementLinkURL"];
    NSString *linkURLString = [linkURL absoluteString];

    // Determine the type of the result, e.g. "Class" (cl)
    NSString *resultType = nil;
    static NSRegularExpression *typeExpression = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        typeExpression = [[NSRegularExpression alloc] initWithPattern:@"apple_ref\\/.+?\\/(.+?)\\/" options:0 error:NULL];
    });
    NSTextCheckingResult *match = [typeExpression firstMatchInString:linkURLString options:0 range:NSMakeRange(0, [linkURLString length])];
    if (match) {
        resultType = [linkURLString substringWithRange:[match rangeAtIndex:1]];
    } else {
        return nil;
    }

    // Determine the name of the result/page to show, e.g. "NSAlert"
    NSString *resultName = nil;
    if ([resultType isEqualToString:@"uid"]) {
        // this document is release notes, or a technical note, etc., whose name is given by the link's label
        resultName = [[info objectForKey:@"WebActionElementKey"] objectForKey:@"WebElementLinkLabel"];
        // we must remove spaces from the name for how Dash searches (a space initiates "Find in Page" search)
        resultName = [resultName stringByReplacingOccurrencesOfString:@" " withString:@""];

        // change the result type to "doc" so that Dash uses the proper icon
        resultType = @"doc";
    } else {
        // this document is an API reference, for which the most accurate name is the last path component of the URL
        // --the symbol clicked on, or the name of the reference page to be opened
        resultName = [linkURLString lastPathComponent];
    }

    // Determine the path to open
    // take everything after "file://" so that we include the fragment (the in-page link)
    NSString *resultPath = [linkURLString substringFromIndex:[@"file://" length]];

    // Build the Dash URL
    // Given this URL, what Dash will do (per @kapeli) is:
    //
    //     1. Perform a regular search for the result using the currently enabled docsets
    //     2. Search for a result that matches the path
    //     3. If a result is found, that result is prioritised and it appears as the top result
    //     4. If a result with that path is not found, a fake result will be added to the top
    //
    return [NSURL URLWithString:[NSString stringWithFormat:@"dash-advanced://%@/%@/%@", resultName, resultType, resultPath]];
}

- (BOOL)om_showQuickHelpForDashURL:(NSURL *)dashURL {
    return [[NSWorkspace sharedWorkspace] openURL:dashURL];
}

- (NSString *)om_appendActiveSchemeKeyword:(NSString *)searchString
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kOMDashPlatformDetectionEnabled])
    {
        @try { // I don't trust myself with this swizzling business
            id windowController = [[NSApp keyWindow] windowController];
            id workspace = [windowController valueForKey:@"_workspace"];
            id runContextManager = [workspace valueForKey:@"runContextManager"];
            id activeDestination = [runContextManager valueForKey:@"_activeRunDestination"];
            NSString *destination = [activeDestination valueForKey:@"targetIdentifier"];
            
            if(destination && [destination isKindOfClass:[NSString class]] && destination.length)
            {
                destination = [destination lowercaseString];
                BOOL iOS = [destination hasPrefix:@"iphone"] || [destination hasPrefix:@"ipad"] || [destination hasPrefix:@"ios"];
                BOOL mac = [destination hasPrefix:@"mac"] || [destination hasPrefix:@"osx"];
                if(iOS || mac)
                {
                    NSUserDefaults *defaults = [[[NSUserDefaults alloc] init] autorelease];
                    [defaults addSuiteNamed:@"com.kapeli.dash"];
                    [defaults synchronize];
                    NSArray *docsets = [defaults objectForKey:@"docsets"];
                    docsets = [docsets sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                        BOOL obj1Enabled = [[obj1 objectForKey:@"isProfileEnabled"] boolValue];
                        BOOL obj2Enabled = [[obj2 objectForKey:@"isProfileEnabled"] boolValue];
                        if(obj1Enabled && !obj2Enabled)
                        {
                            return NSOrderedAscending;
                        }
                        else if(!obj1Enabled && obj2Enabled)
                        {
                            return NSOrderedDescending;
                        }
                        else
                        {
                            return NSOrderedSame;
                        }
                    }];
                    
                    NSString *foundKeyword = nil;
                    for(NSDictionary *docset in docsets)
                    {
                        NSString *platform = [[docset objectForKey:@"platform"] lowercaseString];
                        BOOL found = NO;
                        if(iOS && ([platform hasPrefix:@"iphone"] || [platform hasPrefix:@"ios"]))
                        {
                            found = YES;
                        }
                        else if(mac && ([platform hasPrefix:@"macosx"] || [platform hasPrefix:@"osx"]))
                        {
                            found = YES;
                        }
                        if(found)
                        {
                            NSString *keyword = [docset objectForKey:@"keyword"];
                            foundKeyword = (keyword && keyword.length) ? keyword : platform;
                            break;
                        }
                    }
                    if(foundKeyword)
                    {
                        searchString = [[[foundKeyword stringByReplacingOccurrencesOfString:@":" withString:@""] stringByAppendingString:@":"] stringByAppendingString:searchString];
                    }
                    [defaults removeSuiteNamed:@"com.kapeli.dash"];
                }
            }
        }
        @catch (NSException *exception) { }
    }
    return searchString;
}

@end



@implementation OMQuickHelpPlugin

+ (void)pluginDidLoad:(NSBundle *)plugin
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		if (NSClassFromString(@"IDESourceCodeEditor") != NULL) {
			[NSClassFromString(@"IDESourceCodeEditor") jr_swizzleMethod:@selector(showQuickHelp:) withMethod:@selector(om_showQuickHelp:) error:NULL];
		}

		Class quickHelpControllerClass = NSClassFromString(@"IDEQuickHelpOneShotWindowContentViewController");
		if (quickHelpControllerClass) {
		    [quickHelpControllerClass jr_swizzleMethod:@selector(handleLinkClickWithActionInformation:)
		                                    withMethod:@selector(om_handleLinkClickWithActionInformation:) error:NULL];
		}

		[[self alloc] init];
	});
}

- (id)init
{
	self  = [super init];
	if (self) {
		//TODO: It would be better to add this to the Help menu, but that seems to be populated from somewhere else...
		NSMenuItem *editMenuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
		if (editMenuItem) {
			[[editMenuItem submenu] addItem:[NSMenuItem separatorItem]];

			NSMenuItem *dashMenuItem = [[[NSMenuItem alloc] initWithTitle:@"Dash Integration" action:nil keyEquivalent:@""] autorelease];
            NSMenu *dashMenu = [[[NSMenu alloc] init] autorelease];
            [dashMenuItem setSubmenu:dashMenu];

            /*
             Create a menu looking like:
             
             Disabled
             Replace Quick Help
             Replace Reference
             ————————————— (separator item)
             Advanced
             — Enable Dash Platform Detection (in a submenu of Advanced)
             */

            NSMutableSet *integrationStyleMenuItems = [[[NSMutableSet alloc] init] autorelease];

            NSMenuItem *disabledStyleItem = [dashMenu addItemWithTitle:@"Disabled" action:@selector(toggleIntegrationStyle:) keyEquivalent:@""];
            disabledStyleItem.tag = OMQuickHelpPluginIntegrationStyleDisabled;
            [disabledStyleItem setTarget:self];
            [integrationStyleMenuItems addObject:disabledStyleItem];

			NSMenuItem *quickHelpStyleItem = [dashMenu addItemWithTitle:@"Replace Quick Help" action:@selector(toggleIntegrationStyle:) keyEquivalent:@""];
            quickHelpStyleItem.tag = OMQuickHelpPluginIntegrationStyleQuickHelp;
            [quickHelpStyleItem setTarget:self];
            [integrationStyleMenuItems addObject:quickHelpStyleItem];

            NSMenuItem *referenceStyleItem = [dashMenu addItemWithTitle:@"Replace Reference" action:@selector(toggleIntegrationStyle:) keyEquivalent:@""];
            referenceStyleItem.tag = OMQuickHelpPluginIntegrationStyleReference;
            [referenceStyleItem setTarget:self];
            [integrationStyleMenuItems addObject:referenceStyleItem];

            // the default menu option should be to replace the quick help popup
            if (![[NSUserDefaults standardUserDefaults] objectForKey:kOMOpenInDashStyle]) {
                [[NSUserDefaults standardUserDefaults] setInteger:OMQuickHelpPluginIntegrationStyleQuickHelp forKey:kOMOpenInDashStyle];
            }

            _integrationStyleMenuItems = [integrationStyleMenuItems copy];

            [dashMenu addItem:[NSMenuItem separatorItem]];

            NSMenuItem *advancedMenuItem = [dashMenu addItemWithTitle:@"Advanced" action:nil keyEquivalent:@""];
            NSMenu *advancedMenu = [[[NSMenu alloc] init] autorelease];
            [advancedMenuItem setSubmenu:advancedMenu];

            NSMenuItem *togglePlatformDetection = [advancedMenu addItemWithTitle:@"Enable Dash Platform Detection" action:@selector(toggleDashPlatformDetection:) keyEquivalent:@""];
            [togglePlatformDetection setTarget:self];

			[[editMenuItem submenu] addItem:dashMenuItem];
		}
	}
	return self;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([_integrationStyleMenuItems containsObject:menuItem]) {
        OMQuickHelpPluginIntegrationStyle selectedStyle = [[NSUserDefaults standardUserDefaults] integerForKey:kOMOpenInDashStyle];
        [menuItem setState:(menuItem.tag == selectedStyle) ? NSOnState : NSOffState];
	}
    else if([menuItem action] == @selector(toggleDashPlatformDetection:)) {
		if ([[NSUserDefaults standardUserDefaults] boolForKey:kOMDashPlatformDetectionEnabled]) {
			[menuItem setState:NSOnState];
		} else {
			[menuItem setState:NSOffState];
		}
	}
	return YES;
}

- (void)toggleIntegrationStyle:(id)sender
{
    OMQuickHelpPluginIntegrationStyle style = [(NSMenuItem *)sender tag];
	[[NSUserDefaults standardUserDefaults] setInteger:style forKey:kOMOpenInDashStyle];
}

- (void)toggleDashPlatformDetection:(id)sender
{
    BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMDashPlatformDetectionEnabled];
	[[NSUserDefaults standardUserDefaults] setBool:!enabled forKey:kOMDashPlatformDetectionEnabled];
}

@end
