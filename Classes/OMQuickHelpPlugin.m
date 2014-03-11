//
//  OMColorHelper.m
//  OMColorHelper
//
//  Created by Ole Zorn on 09/07/12.
//
//

#import "OMQuickHelpPlugin.h"
#import "JRSwizzle.h"
#import "objc/runtime.h"
#import "NSString+DHUtils.h"

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
- (BOOL)om_openDashFromURL:(NSURL *)docsetURL;

@end

@implementation NSObject (OMSwizzledMethods)

- (void)om_showQuickHelp:(id)sender
{
    [OMQuickHelpPlugin clearLastQueryResult];
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
                BOOL success = NO;
                @try {
                    Class quickHelpCommandHandler = NSClassFromString(@"IDEQuickHelpCommandHandler");
                    if(quickHelpCommandHandler)
                    {
                        id commandHandler = [quickHelpCommandHandler handlerForAction:@selector(showDocumentationForSymbol:) withSelectionSource:self];
                        [commandHandler performSelector:@selector(showDocumentationForSymbol:) withObject:self];
                        success = YES;
                    }
                }
                @catch(NSException *exception) { }
                if(!success)
                {
                    BOOL dashOpened = [self om_showQuickHelpForSearchString:symbolString];
                    if (!dashOpened) {
                        [self om_dashNotInstalledFallback];
                    }
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

- (void)om_searchDocumentationForSelectedText:(id)sender
{
    [OMQuickHelpPlugin clearLastQueryResult];
    @try {
        OMQuickHelpPluginIntegrationStyle dashStyle = [[NSUserDefaults standardUserDefaults] integerForKey:kOMOpenInDashStyle];
        if (dashStyle == OMQuickHelpPluginIntegrationStyleDisabled || ![sender isKindOfClass:NSClassFromString(@"IDESourceCodeEditor")]) {
            [self om_searchDocumentationForSelectedText:sender];
            return;
        }
        NSString *symbolString = [sender valueForKeyPath:@"selectedExpression.symbolString"];
        if(symbolString.length)
        {
            BOOL dashOpened = [self om_showQuickHelpForSearchString:symbolString];
            if (!dashOpened) {
                [self om_dashNotInstalledFallback];
            }
        }
        else
        {
            NSBeep();
        }
    }
    @catch(NSException *exception) { }
}

// The quick help popup is actually a web view, and the links are actual links.
// We examine the URL of any link clicked to see whether Xcode is trying to open a docset page
// (as opposed to a source file).
- (void)om_handleLinkClickWithActionInformation:(id)info {
    [OMQuickHelpPlugin clearLastQueryResult];
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
            BOOL dashOpened = [self om_openDashFromURL:dashURL];
            if (!dashOpened) {
                [self om_dashNotInstalledFallback];
            }
        }
        else
        {
            [self om_revertToDefaultSymbolSearch];
        }
	}
    @catch (NSException *exception) {
        
    }
}

+ (void)om_loadDocURL:(NSURL *)url {
    @try {
        OMQuickHelpPluginIntegrationStyle dashStyle = [[NSUserDefaults standardUserDefaults] integerForKey:kOMOpenInDashStyle];
        if (dashStyle == OMQuickHelpPluginIntegrationStyleDisabled) {
            //No, this is not an infinite loop because the method is swizzled:
            [self om_loadDocURL:url];
            return;
        }

        @try {
            id result = objc_getAssociatedObject(NSApp, @"om_lastQueryResult");
            if(result)
            {
                if([result respondsToSelector:@selector(ancestorNames)] && [result respondsToSelector:@selector(symbolName)])
                {
                    id ancestorNames = [result performSelector:@selector(ancestorNames)];
                    id symbolName = [result performSelector:@selector(symbolName)];
                    if(ancestorNames && [ancestorNames isKindOfClass:[NSArray class]] && [ancestorNames count] && symbolName && [symbolName isKindOfClass:[NSString class]] && [ancestorNames[0] isKindOfClass:[NSString class]] && ![symbolName isEqualToString:ancestorNames[0]])
                    {
                        id editor = [OMQuickHelpPlugin currentEditor];
                        NSString *symbolString = [editor valueForKeyPath:@"selectedExpression.symbolString"];
                        if([symbolString isEqualToString:ancestorNames[0]])
                        {
                            BOOL dashOpened = [self om_showQuickHelpForSearchString:symbolString];
                            if (!dashOpened) {
                                [self om_dashNotInstalledFallback];
                            }
                            return;
                        }
                    }
                }
            }
        }
        @catch(NSException *exception) { }
        NSURL *dashURL = [self om_dashURLFromAppleDocURL:url];
        if (dashURL) {
            BOOL dashOpened = [self om_openDashFromURL:dashURL];
            if (!dashOpened) {
                [self om_dashNotInstalledFallback];
            }
        }
        else
        {
            [self om_revertToDefaultSymbolSearch];
        }
    }
    @catch (NSException *exception) {

    }
}

- (void)om_revertToDefaultSymbolSearch
{
    id editor = [OMQuickHelpPlugin currentEditor];
    NSString *symbolString = [editor valueForKeyPath:@"selectedExpression.symbolString"];
    if(symbolString.length)
    {
        BOOL dashOpened = [self om_showQuickHelpForSearchString:symbolString];
        if (!dashOpened) {
            [self om_dashNotInstalledFallback];
        }
    }
    else
    {
        NSBeep();
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

    NSURL *linkURL = [[info objectForKey:@"WebActionElementKey"] objectForKey:@"WebElementLinkURL"];
    NSString *linkURLString = [linkURL absoluteString];
    BOOL linkOpensReference = [linkURLString rangeOfString:@".docset"].location != NSNotFound && ![[linkURL pathExtension] isCaseInsensitiveLike:@"h"];
    return linkOpensReference;
}

- (NSURL *)om_dashURLFromQuickHelpLinkActionInformation:(id)info {
    NSURL *linkURL = [[info objectForKey:@"WebActionElementKey"] objectForKey:@"WebElementLinkURL"];
    if(![linkURL fragment] || [[linkURL fragment] rangeOfString:@"apple_ref"].location == NSNotFound)
    {
        return nil;
    }

    NSString *dashResultName, *dashResultType = [self om_dashResultTypeFromAppleDocURL:linkURL];
    if ([dashResultType isEqualToString:@"uid"]) {
        // this document is release notes, or a technical note, etc., whose name is given by the link's label
        dashResultName = [[info objectForKey:@"WebActionElementKey"] objectForKey:@"WebElementLinkLabel"];
        // we must remove spaces from the name for how Dash searches (a space initiates "Find in Page" search)
        dashResultName = [dashResultName stringByReplacingOccurrencesOfString:@" " withString:@""];

        // change the result type to "doc" so that Dash uses the proper icon
        dashResultType = @"doc";
    } else {
        // this document is an API reference, for which the most accurate name is the last path component of the URL
        // --the symbol clicked on, or the name of the reference page to be opened
        dashResultName = [self om_dashResultNameFromAppleDocURL:linkURL];
    }

    NSString *dashResultPath = [self om_dashResultPathFromAppleDocURL:linkURL];

    return [self om_dashURLForResultWithName:dashResultName type:dashResultType path:dashResultPath];
}

- (NSURL *)om_dashURLFromAppleDocURL:(NSURL *)url {
    if(![url fragment] || [[url fragment] rangeOfString:@"apple_ref"].location == NSNotFound)
    {
        return nil;
    }
    return [self om_dashURLForResultWithName:[self om_dashResultNameFromAppleDocURL:url]
                                        type:[self om_dashResultTypeFromAppleDocURL:url]
                                        path:[self om_dashResultPathFromAppleDocURL:url]];
}

// Determine the type of the result, e.g. "Class" (cl)
- (NSString *)om_dashResultTypeFromAppleDocURL:(NSURL *)url {
    NSString *URLString = [url absoluteString];

    NSString *resultType = nil;
    static NSRegularExpression *typeExpression = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        typeExpression = [[NSRegularExpression alloc] initWithPattern:@"apple_ref\\/.+?\\/(.+?)\\/" options:0 error:NULL];
    });
    NSTextCheckingResult *match = [typeExpression firstMatchInString:URLString options:0 range:NSMakeRange(0, [URLString length])];
    if (match) {
        resultType = [URLString substringWithRange:[match rangeAtIndex:1]];
    }

    return resultType;
}

// Determine the name of the result/page to show, e.g. "NSAlert"
- (NSString *)om_dashResultNameFromAppleDocURL:(NSURL *)url {
    return [[url absoluteString] lastPathComponent];
}

// Determine the path to open
- (NSString *)om_dashResultPathFromAppleDocURL:(NSURL *)url {
    // take everything after "file://" so that we include the fragment (the in-page link)
    NSString *resultPath = [[url absoluteString] substringFromIndex:[@"file://" length]];
    // strip "localhost" if present though
    if ([resultPath hasPrefix:@"localhost"]) {
        resultPath = [resultPath substringFromIndex:[@"localhost" length]];
    }
    return resultPath;
}

- (NSURL *)om_dashURLForResultWithName:(NSString *)name type:(NSString *)type path:(NSString *)path {
    // Build the Dash URL
    // Given this URL, what Dash will do (per @kapeli) is:
    //
    //     1. Perform a regular search for the result using the currently enabled docsets
    //     2. Search for a result that matches the path
    //     3. If a result is found, that result is prioritised and it appears as the top result
    //     4. If a result with that path is not found, a fake result will be added to the top
    //
    
    NSString *pathWithoutFragment = [path dh_substringToString:@"#"];
    if(![[NSFileManager defaultManager] fileExistsAtPath:pathWithoutFragment])
    {
        path = nil;
    }
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:kOMDashPlatformDetectionEnabled])
    {
        BOOL dashHasAdvancedWithKeys = [[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:[NSURL URLWithString:@"dash-advanced-with-keys://blabla"]] != nil;
        if(dashHasAdvancedWithKeys)
        {
            NSString *query = [NSString stringWithFormat:@"/%@/%@", name, type];
            if(path)
            {
                query = [query stringByAppendingFormat:@"/%@", path];
            }
            NSString *urlString = [self om_appendActiveSchemeKeyword:query];
            if([urlString hasPrefix:@"dash-plugin://keys="])
            {
                return [NSURL URLWithString:[[urlString stringByReplacingOccurrencesOfString:@"dash-plugin://keys=" withString:@"dash-advanced-with-keys://"] stringByReplacingOccurrencesOfString:@"&query=/" withString:@"/"]];
            }
        }
    }
    return [NSURL URLWithString:[NSString stringWithFormat:@"dash-advanced://%@/%@%@", name, type, (path) ? [@"/" stringByAppendingString:path] : @""]];
}

- (BOOL)om_openDashFromURL:(NSURL *)dashURL {
    BOOL dashHasAdvancedWithKeys = [[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:[NSURL URLWithString:@"dash-advanced-with-keys://blabla"]] != nil;
    if(dashHasAdvancedWithKeys)
    {
        NSString *urlString = [dashURL absoluteString];
        NSPasteboard *pboard = [NSPasteboard pasteboardWithUniqueName];
        [pboard setString:urlString forType:NSStringPboardType];
        return NSPerformService(@"Look Up in Dash", pboard);
    }
    return [[NSWorkspace sharedWorkspace] openURL:dashURL];
}

- (NSString *)om_appendActiveSchemeKeyword:(NSString *)searchString
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kOMDashPlatformDetectionEnabled])
    {
        BOOL dashHasPluginURL = [[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:[NSURL URLWithString:@"dash-plugin://blabla"]] != nil;
        BOOL isObjectiveCPP = NO;
        BOOL isCppOrC = NO;
        @try {
            if(dashHasPluginURL)
            {
                NSString *fileType = nil;
                @try {
                    NSURL *currentURL = [[[self valueForKey:@"selectedExpression"] valueForKey:@"textSelectionLocation"] valueForKey:@"documentURL"];
                    if(currentURL)
                    {
                        fileType = [currentURL pathExtension];
                    }
                }
                @catch(NSException *exception) {
                }
                if(fileType && fileType.length)
                {
                    if([fileType isEqualToString:@"c"])
                    {
                        isCppOrC = YES;
                        searchString = [@"dash-plugin://keys=c,glib,gl2,gl3,gl4,manpages&query=" stringByAppendingString:[searchString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                    }
                    else if([@[@"cpp", @"cc", @"cp", @"cxx", @"c++", @"c", @"hpp", @"hxx", @"h++", @"hh"] containsObject:[fileType lowercaseString]])
                    {
                        isCppOrC = YES;
                        searchString = [@"dash-plugin://keys=cpp,boost,qt,cvcpp,cocos2dx,net,c,manpages&query=" stringByAppendingString:[searchString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                    }
                    else if([[fileType lowercaseString] isEqualToString:@"mm"] || [fileType isEqualToString:@"M"])
                    {
                        isObjectiveCPP = YES; // add later, depending on active platform
                    }
                }
            }
        }
        @catch(NSException *exception) { }
        
        BOOL didAddPlatform = NO;
        if(!isCppOrC)
        {
            @try {
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
                        if(dashHasPluginURL)
                        {
                            didAddPlatform = YES;
                            if(isObjectiveCPP)
                            {
                                if(iOS)
                                {
                                    searchString = [@"dash-plugin://keys=cpp,iphoneos,appledoc,cocos2dx,cocos2d,cocos3d,kobold2d,sparrow,c,manpages&query=" stringByAppendingString:[searchString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                                }
                                else
                                {
                                    searchString = [@"dash-plugin://keys=cpp,macosx,appledoc,cocos2dx,cocos2d,cocos3d,kobold2d,c,manpages&query=" stringByAppendingString:[searchString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                                }
                            }
                            else
                            {
                                if(iOS)
                                {
                                    searchString = [@"dash-plugin://keys=iphoneos,appledoc,cocos2d,cocos3d,kobold2d,sparrow,c,manpages&query=" stringByAppendingString:[searchString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                                }
                                else if(mac)
                                {
                                    searchString = [@"dash-plugin://keys=macosx,appledoc,cocos2d,cocos3d,kobold2d,c,manpages&query=" stringByAppendingString:[searchString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                                }
                            }
                        }
                        else
                        {
                            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
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
                if(!didAddPlatform)
                {
                    if(isObjectiveCPP)
                    {
                        searchString = [@"dash-plugin://keys=cpp,iphoneos,macosx,appledoc,cocos2dx,cocos2d,cocos3d,kobold2d,sparrow,c,manpages&query=" stringByAppendingString:[searchString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                    }
                }
            }
            @catch (NSException *exception) { }
        }
    }
    return searchString;
}

- (void)logAllKeysAndValuesFor:(id)object
{
    NSLog(@"Logging keys for %@:", object);
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList([object class], &outCount);
    for(i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        const char *propName = property_getName(property);
        if(propName) {
            NSString *propertyName = [NSString stringWithUTF8String:propName];
            NSLog(@"%@ -> %@", propertyName, [object valueForKey:propertyName]);
        }
    }
    free(properties);
}

+ (id)om_queryResultForToken:(id)arg1 ancestorHierarchy:(id)arg2
{
    id result = [self om_queryResultForToken:arg1 ancestorHierarchy:arg2];
    if(result)
    {
        @try {
            objc_setAssociatedObject(NSApp, @"om_lastQueryResult", result, OBJC_ASSOCIATION_RETAIN);
        }
        @catch(NSException *exception) { }
    }
    return result;
}

@end



@implementation OMQuickHelpPlugin

+ (void)pluginDidLoad:(NSBundle *)plugin
{
	static dispatch_once_t onceToken;
    static id quickHelpPlugin = nil;
	dispatch_once(&onceToken, ^{
		if (NSClassFromString(@"IDESourceCodeEditor") != NULL) {
			[NSClassFromString(@"IDESourceCodeEditor") jr_swizzleMethod:@selector(showQuickHelp:) withMethod:@selector(om_showQuickHelp:) error:NULL];
		}

		Class quickHelpControllerClass = NSClassFromString(@"IDEQuickHelpOneShotWindowContentViewController");
		if (quickHelpControllerClass) {
		    [quickHelpControllerClass jr_swizzleMethod:@selector(handleLinkClickWithActionInformation:)
		                                    withMethod:@selector(om_handleLinkClickWithActionInformation:) error:NULL];
		}
        
		Class quickHelpQueryResult = NSClassFromString(@"IDEQuickHelpQueryResult");
		if (quickHelpQueryResult) {
		    [quickHelpQueryResult jr_swizzleClassMethod:@selector(queryResultForToken:ancestorHierarchy:)
                     withClassMethod:@selector(om_queryResultForToken:ancestorHierarchy:) error:NULL];
		}

        Class docCommandHandlerClass = NSClassFromString(@"IDEDocCommandHandler");
        if (docCommandHandlerClass) {
            [docCommandHandlerClass jr_swizzleClassMethod:@selector(loadURL:)
                                          withClassMethod:@selector(om_loadDocURL:) error:NULL];
            [docCommandHandlerClass jr_swizzleMethod:@selector(searchDocumentationForSelectedText:)
                                          withMethod:@selector(om_searchDocumentationForSelectedText:) error:NULL];
        }

        quickHelpPlugin = [[self alloc] init];
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

            NSMenu *dashMenu = [[NSMenu alloc] init];
			NSMenuItem *dashMenuItem = [[editMenuItem submenu] addItemWithTitle:@"Dash Integration" action:nil keyEquivalent:@""];
            [dashMenuItem setSubmenu:dashMenu];

            /*
             Create a menu looking like:
             
             Disabled
             Replace Quick Help
             Replace Reference
             ————————————— (separator item)
             — Enable Dash Platform Detection
             */

            NSMutableSet *integrationStyleMenuItems = [NSMutableSet set];

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

            NSMenuItem *togglePlatformDetection = [dashMenu addItemWithTitle:@"Enable Dash Platform Detection" action:@selector(toggleDashPlatformDetection:) keyEquivalent:@""];
            [togglePlatformDetection setTarget:self];
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

+ (id)handlerForAction:(SEL)arg1 withSelectionSource:(id)arg2
{
    return nil;
}

+ (id)currentEditor
{
    NSWindowController *controller = [[NSApp keyWindow] windowController];
    if([controller isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")])
    {
        id editorArea = [controller valueForKeyPath:@"editorArea"];
        id editorContext = [editorArea valueForKeyPath:@"lastActiveEditorContext"];
        return [editorContext valueForKeyPath:@"editor"];
    }
    return nil;
}

+ (void)clearLastQueryResult
{
    @try {
        objc_setAssociatedObject(NSApp, @"om_lastQueryResult", nil, OBJC_ASSOCIATION_RETAIN);
    }
    @catch(NSException *exception) { }
}

@end
