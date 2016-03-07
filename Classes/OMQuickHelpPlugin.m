//
//  OMQuickHelpPlugin.m
//  OMQuickHelpPlugin
//
//  Created by Ole Zorn on 09/07/12.
//
//

#import "OMQuickHelpPlugin.h"
#import "JRSwizzle.h"
#import "objc/runtime.h"
#import "NSString+DHUtils.h"

#define kOMSuppressDashNotInstalledWarning    @"OMSuppressDashNotInstalledWarning"
#define kOMQuickHelpOpenInDashStyle           @"OMOpenInDashStyle"
#define kOMDashPlatformDetectionEnabled       @"OMDashPlatformDetectionEnabled"
#define kOMSearchDocumentationOpenInDashStyle @"OMSearchDocumentationOpenInDashStyle"
#define kOMDebugMode NO

typedef NS_ENUM(NSInteger, OMQuickHelpPluginIntegrationStyle) {
    OMQuickHelpPluginIntegrationStyleDisabled = 0,  // Disable this plugin altogether
    OMQuickHelpPluginIntegrationStyleQuickHelp,     // Search Dash instead of showing the "Quick Help" popup
    OMQuickHelpPluginIntegrationStyleReference,     // Show the "Quick Help" popup, but search Dash instead
                                                    // of showing Xcode's documentation viewer (when the "Reference" link
                                                    // in the popup is clicked)
                                                    // DISABLED: There's no way to get the search term from the new style
                                                    // of links Apple's using, especially for Swift terms like
                                                    // IntegerLiteralConvertible
};

typedef NS_ENUM(NSInteger, OMSearchDocumentationPluginIntegrationStyle) {
    OMSearchDocumentationPluginIntegrationStyleDisabled = 0,  // Disable this plugin altogether
    OMSearchDocumentationPluginIntegrationStyleEnabled,
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
        OMQuickHelpPluginIntegrationStyle dashStyle = [[NSUserDefaults standardUserDefaults] integerForKey:kOMQuickHelpOpenInDashStyle];
        if (dashStyle == OMQuickHelpPluginIntegrationStyleDisabled) {
            //No, this is not an infinite loop because the method is swizzled
            //meaning that om_showQuickHelp: now refers to the original implementation and not this method.
            [self om_showQuickHelp:sender];
            return;
		}
		NSString *symbolString = [self valueForKeyPath:@"selectedExpression.symbolString"];
        if(kOMDebugMode)
        {
            NSLog(@"om_showQuickHelp with symbolString: %@", symbolString);
        }
        if(dashStyle == OMQuickHelpPluginIntegrationStyleQuickHelp)
        {
            // handle three-finger tap
            @try {
                id mouseOverExpression = [self valueForKeyPath:@"mouseOverExpression"];
                id mouseOverExpressionString = [mouseOverExpression valueForKeyPath:@"symbolString"];
                if([mouseOverExpressionString length] && (!symbolString || ![mouseOverExpressionString isEqualToString:symbolString]))
                {
                    BOOL dashOpened = [self om_showQuickHelpForSearchString:mouseOverExpressionString];
                    if (!dashOpened) {
                        [self om_dashNotInstalledFallback];
                    }
                    return;
                }
            }
            @catch(NSException *exception) {}
        }
        if(symbolString.length)
        {
            if (dashStyle == OMQuickHelpPluginIntegrationStyleQuickHelp) {
//                BOOL success = NO;
//                @try {
//                    Class quickHelpCommandHandler = NSClassFromString(@"IDEQuickHelpCommandHandler");
//                    if(quickHelpCommandHandler)
//                    {
//                        id commandHandler = [quickHelpCommandHandler handlerForAction:@selector(showDocumentationForSymbol:) withSelectionSource:self];
//                        [commandHandler performSelector:@selector(showDocumentationForSymbol:) withObject:self];
//                        success = YES;
//                    }
//                }
//                @catch(NSException *exception) { }
//                if(!success)
//                {
                    BOOL dashOpened = [self om_showQuickHelpForSearchString:symbolString];
                    if (!dashOpened) {
                        [self om_dashNotInstalledFallback];
                    }
//                }
            } else {
                // Show regular quick help--wait to search Dash until the user clicks on a link
                //No, this is not an infinite loop because the method is swizzled
                //meaning that om_showQuickHelp: now refers to the original implementation and not this method.
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
        OMSearchDocumentationPluginIntegrationStyle dashStyle = [[NSUserDefaults standardUserDefaults] integerForKey:kOMSearchDocumentationOpenInDashStyle];
        if (dashStyle == OMSearchDocumentationPluginIntegrationStyleDisabled) {
            //No, this is not an infinite loop because the method is swizzled
            //meaning that om_searchDocumentationForSelectedText: now refers to the original implementation and not this method.
            [self om_searchDocumentationForSelectedText:sender];
            return;
        }

        NSString *symbolString = [[OMQuickHelpPlugin currentEditor] valueForKeyPath:@"selectedExpression.symbolString"];
        if(kOMDebugMode)
        {
            NSLog(@"om_searchDocumentationForSelectedText with symbolString: %@", symbolString);
        }
        if (symbolString.length)
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

        if(kOMDebugMode)
        {
            NSLog(@"om_handleLinkClickWithActionInformation with info: %@", info);
        }
        // Dismiss the quick help popup
        [[self valueForKey:@"quickHelpController"] performSelector:@selector(closeQuickHelp)];

        NSURL *dashURL = [self om_dashURLFromQuickHelpLinkActionInformation:info];
        if(kOMDebugMode)
        {
            NSLog(@"om_handleLinkClickWithActionInformation with dashURL: %@", dashURL);
        }
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
        OMQuickHelpPluginIntegrationStyle dashStyle = [[NSUserDefaults standardUserDefaults] integerForKey:kOMQuickHelpOpenInDashStyle];
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
                        if(kOMDebugMode)
                        {
                            NSLog(@"om_loadDocURL with symbolString: %@, call stack: %@", symbolString, [NSThread callStackSymbols]);
                        }
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
        if(kOMDebugMode)
        {
            NSLog(@"om_loadDocURL with dashURL: %@, call stack: %@", dashURL, [NSThread callStackSymbols]);
        }
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
    if(kOMDebugMode)
    {
        NSLog(@"om_revertToDefaultSymbolSearch with symbolString: %@", symbolString);
    }
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
	return NSPerformService(@"Look Up in Dash Beta", pboard) || NSPerformService(@"Look Up in Dash", pboard);
}

- (BOOL)om_shouldHandleLinkClickWithActionInformation:(id)info {
    OMQuickHelpPluginIntegrationStyle dashStyle = [[NSUserDefaults standardUserDefaults] integerForKey:kOMQuickHelpOpenInDashStyle];
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
    return nil;
    if(![url fragment] || [[url fragment] rangeOfString:@"apple_ref"].location == NSNotFound)
    {
        return nil;
    }
    NSURL *dashURL = [self om_dashURLForResultWithName:[self om_dashResultNameFromAppleDocURL:url]
                                                  type:[self om_dashResultTypeFromAppleDocURL:url]
                                                  path:[self om_dashResultPathFromAppleDocURL:url]];
    if(kOMDebugMode)
    {
        NSLog(@"om_dashURLFromAppleDocURL appleDocURL: %@, dashURL: %@", url, dashURL);
    }
    return dashURL;
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
    NSString *urlString = [url absoluteString];
    NSString *lastPathComponent = [urlString lastPathComponent];
    if([lastPathComponent hasPrefix:@"c:"] && [urlString dh_contains:@"/swift/"])
    {
        return [[lastPathComponent dh_substringFromLastOccurrenceOfStringExceptSuffix:@"@"] dh_substringFromLastOccurrenceOfStringExceptSuffix:@")"];
    }
    return lastPathComponent;
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
        return NSPerformService(@"Look Up in Dash Beta", pboard) || NSPerformService(@"Look Up in Dash", pboard);
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
        BOOL isSwift = NO;
        @try {
            if(dashHasPluginURL)
            {
                NSString *fileType = nil;
                @try {
                    NSURL *currentURL = [[[[OMQuickHelpPlugin currentEditor] valueForKey:@"selectedExpression"] valueForKey:@"textSelectionLocation"] valueForKey:@"documentURL"];
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
                    else if([@[@"swift", @"playground"] containsObject:[fileType lowercaseString]])
                    {
                        isSwift = YES; // add later, depending on active platform
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
                    if(kOMDebugMode)
                    {
                        NSLog(@"Platform detection found %@ as the targetIdentifier", destination);
                    }
                    BOOL iOS = [destination hasPrefix:@"iphone"] || [destination hasPrefix:@"ipad"] || [destination hasPrefix:@"ios"];
                    BOOL mac = [destination hasPrefix:@"mac"] || [destination hasPrefix:@"osx"];
                    BOOL tvos = [destination hasPrefix:@"appletvos"];
                    if(iOS || mac || tvos)
                    {
                        if(dashHasPluginURL)
                        {
                            didAddPlatform = YES;
                            if(isObjectiveCPP)
                            {
                                if(iOS)
                                {
                                    searchString = [@"dash-plugin://keys=cpp,iphoneos,watchos,appledoc,cocoapods,cocos2dx,cocos2d,cocos3d,kobold2d,sparrow,c,manpages&query=" stringByAppendingString:[searchString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                                }
                                else if(mac)
                                {
                                    searchString = [@"dash-plugin://keys=cpp,macosx,appledoc,cocoapods,cocos2dx,cocos2d,cocos3d,kobold2d,c,manpages&query=" stringByAppendingString:[searchString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                                }
                                else if(tvos)
                                {
                                    searchString = [@"dash-plugin://keys=cpp,tvos,appledoc,cocoapods,c,manpages&query=" stringByAppendingString:[searchString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                                }
                            }
                            else if(isSwift)
                            {
                                if(iOS)
                                {
                                    searchString = [@"dash-plugin://keys=iphoneos,watchos,swift,appledoc,cocoapods,cocos2d,cocos3d,kobold2d,sparrow&query=" stringByAppendingString:[searchString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                                }
                                else if(mac)
                                {
                                    searchString = [@"dash-plugin://keys=macosx,swift,appledoc,cocoapods,cocos2d,cocos3d,kobold2d&query=" stringByAppendingString:[searchString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                                }
                                else if(tvos)
                                {
                                    searchString = [@"dash-plugin://keys=tvos,swift,appledoc,cocoapods&query=" stringByAppendingString:[searchString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                                }
                            }
                            else
                            {
                                if(iOS)
                                {
                                    searchString = [@"dash-plugin://keys=iphoneos,watchos,appledoc,cocoapods,cocos2d,cocos3d,kobold2d,sparrow&query=" stringByAppendingString:[searchString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                                }
                                else if(mac)
                                {
                                    searchString = [@"dash-plugin://keys=macosx,appledoc,cocoapods,cocos2d,cocos3d,kobold2d&query=" stringByAppendingString:[searchString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                                }
                                else if(tvos)
                                {
                                    searchString = [@"dash-plugin://keys=tvos,appledoc,cocoapods&query=" stringByAppendingString:[searchString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
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
                                else if(tvos && ([platform hasPrefix:@"tvos"]))
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
                        searchString = [@"dash-plugin://keys=cpp,iphoneos,macosx,watchos,tvos,appledoc,cocos2dx,cocos2d,cocos3d,kobold2d,sparrow,c,manpages&query=" stringByAppendingString:[searchString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                    }
                }
            }
            @catch (NSException *exception) { }
        }
    }
    return searchString;
}

+ (void)logAllKeysAndValuesFor:(id)object
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

-(void)om_buildMenu:(id)sender
{
    //This isn't recursive. The method has been swizzled so this will actually call the original implementation.
    [self om_buildMenu:sender];

    NSMenuItem *helpMenuItem = [[NSApp mainMenu] itemWithTitle:@"Help"];
    if (helpMenuItem == nil) return;

    [[helpMenuItem submenu] addItem:[NSMenuItem separatorItem]];
    NSMenuItem *dashMenuItem = [[helpMenuItem submenu] addItemWithTitle:@"Dash Integration" action:nil keyEquivalent:@""];
    [dashMenuItem setSubmenu:[OMQuickHelpPlugin sharedInstance]->_dashMenu];
}

@end



@implementation OMQuickHelpPlugin

+(instancetype)sharedInstance
{
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if([currentApplicationName hasPrefix:@"Xcode"])
    {
        if([[NSRunningApplication currentApplication] isFinishedLaunching])
        {
            [[OMQuickHelpPlugin sharedInstance] swizzle];
        }
        // This is needed because Xcode 6.4+ loads the plugin before loading its own stuff (i.e. IDESourceCodeEditor),
        // which causes swizzle to fail
        [[NSNotificationCenter defaultCenter] addObserver:[OMQuickHelpPlugin sharedInstance] selector:@selector(swizzle) name:NSApplicationDidFinishLaunchingNotification object:nil];
    }
}

- (void)swizzle
{
    @synchronized([OMQuickHelpPlugin class]) {
        if(!self.didSwizzle)
        {
            if (NSClassFromString(@"IDESourceCodeEditor") != NULL) {
                self.didSwizzle = YES;
                if(![NSClassFromString(@"IDESourceCodeEditor") jr_swizzleMethod:@selector(showQuickHelp:) withMethod:@selector(om_showQuickHelp:) error:NULL])
                {
                    NSLog(@"OMQuickHelp: Couldn't swizzle showQuickHelp:");
                }
                if(![NSClassFromString(@"IDESourceCodeEditor") jr_swizzleMethod:@selector(_searchDocumentationForSelectedText:) withMethod:@selector(om_searchDocumentationForSelectedText:) error:NULL])
                {
                    NSLog(@"OMQuickHelp: Couldn't swizzle _searchDocumentationForSelectedText:");
                }
            }
            else
            {
                NSLog(@"OMQuickHelp: Couldn't find class IDESourceCodeEditor");
                ++self.swizzleRetryCount;
                if(self.swizzleRetryCount < 10)
                {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self swizzle];
                    });
                }
                return;
            }
            
            Class quickHelpControllerClass = NSClassFromString(@"IDEQuickHelpOneShotWindowContentViewController");
            if (quickHelpControllerClass) {
                if(![quickHelpControllerClass jr_swizzleMethod:@selector(handleLinkClickWithActionInformation:)
                                                    withMethod:@selector(om_handleLinkClickWithActionInformation:) error:NULL])
                {
                    NSLog(@"OMQuickHelp: Couldn't swizzle handleLinkClickWithActionInformation:");
                }
            }
            else
            {
                NSLog(@"OMQuickHelp: Couldn't find class IDEQuickHelpOneShotWindowContentViewController");
            }
            
            Class quickHelpQueryResult = NSClassFromString(@"IDEQuickHelpQueryResult");
            if (quickHelpQueryResult) {
                if(![quickHelpQueryResult jr_swizzleClassMethod:@selector(queryResultForToken:ancestorHierarchy:)
                                                withClassMethod:@selector(om_queryResultForToken:ancestorHierarchy:) error:NULL])
                {
                    NSLog(@"OMQuickHelp: Couldn't swizzle queryResultForToken:ancestorHierarchy:");
                }
            }
            else
            {
                NSLog(@"OMQuickHelp: Couldn't find class IDEQuickHelpQueryResult");
            }
            
            Class docCommandHandlerClass = NSClassFromString(@"IDEDocCommandHandler");
            if (docCommandHandlerClass) {
//                if(![docCommandHandlerClass jr_swizzleClassMethod:@selector(loadURL:)
//                                                  withClassMethod:@selector(om_loadDocURL:) error:NULL])
//                {
//                    NSLog(@"OMQuickHelp: Couldn't swizzle loadURL:");
//                }
                if(![docCommandHandlerClass jr_swizzleMethod:@selector(searchDocumentationForSelectedText:)
                                                  withMethod:@selector(om_searchDocumentationForSelectedText:) error:NULL])
                {
                    NSLog(@"OMQuickHelp: Couldn't swizzle searchDocumentationForSelectedText:");
                }
            }
            else
            {
                NSLog(@"OMQuickHelp: Couldn't find class IDEDocCommandHandler");
            }
            
            Class helpMenuDelegateClass = NSClassFromString(@"IDEHelpMenuDelegate");
            if (helpMenuDelegateClass) {
                if(![helpMenuDelegateClass jr_swizzleMethod:@selector(buildMenu:) withMethod:@selector(om_buildMenu:) error:NULL])
                {
                    NSLog(@"OMQuickHelp: Couldn't swizzle buildMenu:");
                }
            }
            else
            {
                NSLog(@"OMQuickHelp: Couldn't find class IDEHelpMenuDelegate");
            }
        }
    }
}

-(id)init
{
    self = [super init];
    if (self) {

        /*
         Create a menu looking like:

         Disable Quick Help Integration
         Replace Quick Help
         Replace Quick Help Reference Link
         ————————————— (separator item)
         Disable Search Documentation Integration
         Replace Search Documentation
         ————————————— (separator item)
         — Enable Dash Platform Detection
         */
        NSMenu *dashMenu = [[NSMenu alloc] init];
        NSMutableSet *quickHelpIntegrationStyleMenuItems = [NSMutableSet set];

        NSMenuItem *disabledStyleItem = [dashMenu addItemWithTitle:@"Disable Quick Help Integration" action:@selector(toggleIntegrationStyle:) keyEquivalent:@""];
        disabledStyleItem.tag = OMQuickHelpPluginIntegrationStyleDisabled;
        [disabledStyleItem setTarget:self];
        [quickHelpIntegrationStyleMenuItems addObject:disabledStyleItem];

        NSMenuItem *quickHelpStyleItem = [dashMenu addItemWithTitle:@"Replace Quick Help" action:@selector(toggleIntegrationStyle:) keyEquivalent:@""];
        quickHelpStyleItem.tag = OMQuickHelpPluginIntegrationStyleQuickHelp;
        [quickHelpStyleItem setTarget:self];
        [quickHelpIntegrationStyleMenuItems addObject:quickHelpStyleItem];

//        NSMenuItem *quickHelpReferenceLinkStyleItem = [dashMenu addItemWithTitle:@"Replace Quick Help Reference Link" action:@selector(toggleIntegrationStyle:) keyEquivalent:@""];
//        quickHelpReferenceLinkStyleItem.tag = OMQuickHelpPluginIntegrationStyleReference;
//        [quickHelpReferenceLinkStyleItem setTarget:self];
//        [quickHelpIntegrationStyleMenuItems addObject:quickHelpReferenceLinkStyleItem];

        _quickHelpIntegrationStyleMenuItems = [quickHelpIntegrationStyleMenuItems copy];

        // the default menu option should be to replace the quick help popup
        if (![[NSUserDefaults standardUserDefaults] objectForKey:kOMQuickHelpOpenInDashStyle]) {
            [[NSUserDefaults standardUserDefaults] setInteger:OMQuickHelpPluginIntegrationStyleQuickHelp forKey:kOMQuickHelpOpenInDashStyle];
        }
        
        if ([[NSUserDefaults standardUserDefaults] integerForKey:kOMQuickHelpOpenInDashStyle] == OMQuickHelpPluginIntegrationStyleReference) {
            [[NSUserDefaults standardUserDefaults] setInteger:OMQuickHelpPluginIntegrationStyleQuickHelp forKey:kOMQuickHelpOpenInDashStyle];
        }
        
        // the default menu option should be to replace search documentation
        if (![[NSUserDefaults standardUserDefaults] objectForKey:kOMSearchDocumentationOpenInDashStyle]) {
            [[NSUserDefaults standardUserDefaults] setInteger:OMSearchDocumentationPluginIntegrationStyleEnabled forKey:kOMSearchDocumentationOpenInDashStyle];
        }
        
        [dashMenu addItem:[NSMenuItem separatorItem]];

        NSMutableSet *searchDocumentationStyleMenuItems = [NSMutableSet new];

        NSMenuItem *searchDocumentationDisabledStyleItem = [dashMenu addItemWithTitle:@"Disable Search Documentation Integration" action:@selector(toggleSearchDocumentationIntegrationStyle:) keyEquivalent:@""];
        searchDocumentationDisabledStyleItem.tag = OMSearchDocumentationPluginIntegrationStyleDisabled;
        [searchDocumentationDisabledStyleItem setTarget:self];
        [searchDocumentationStyleMenuItems addObject:searchDocumentationDisabledStyleItem];

        NSMenuItem *searchDocumentationEnabledStyleItem = [dashMenu addItemWithTitle:@"Replace Search Documentation" action:@selector(toggleSearchDocumentationIntegrationStyle:) keyEquivalent:@""];
        searchDocumentationEnabledStyleItem.tag = OMSearchDocumentationPluginIntegrationStyleEnabled;
        [searchDocumentationEnabledStyleItem setTarget:self];
        [searchDocumentationStyleMenuItems addObject:searchDocumentationEnabledStyleItem];

        _searchDocumentationIntegrationStyleMenuItems = searchDocumentationStyleMenuItems;

        [dashMenu addItem:[NSMenuItem separatorItem]];

        NSMenuItem *togglePlatformDetection = [dashMenu addItemWithTitle:@"Enable Dash Platform Detection" action:@selector(toggleDashPlatformDetection:) keyEquivalent:@""];
        [togglePlatformDetection setTarget:self];

        _dashMenu = dashMenu;
    }
    return self;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([_quickHelpIntegrationStyleMenuItems containsObject:menuItem]) {
        OMQuickHelpPluginIntegrationStyle selectedStyle = [[NSUserDefaults standardUserDefaults] integerForKey:kOMQuickHelpOpenInDashStyle];
        [menuItem setState:(menuItem.tag == selectedStyle) ? NSOnState : NSOffState];
	}
    else if ([_searchDocumentationIntegrationStyleMenuItems containsObject:menuItem]) {
        OMSearchDocumentationPluginIntegrationStyle selectedStyle = [[NSUserDefaults standardUserDefaults] integerForKey:kOMSearchDocumentationOpenInDashStyle];
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
	[[NSUserDefaults standardUserDefaults] setInteger:style forKey:kOMQuickHelpOpenInDashStyle];
}

- (void)toggleSearchDocumentationIntegrationStyle:(id)sender
{
    OMSearchDocumentationPluginIntegrationStyle style = [(NSMenuItem *)sender tag];
    [[NSUserDefaults standardUserDefaults] setInteger:style forKey:kOMSearchDocumentationOpenInDashStyle];
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
