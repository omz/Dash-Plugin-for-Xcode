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
#define kOMOpenInDashDisabled				@"OMOpenInDashDisabled"

@interface NSObject (OMSwizzledIDESourceCodeEditor)

- (void)om_textView:(id)arg1 didClickOnTemporaryLinkAtCharacterIndex:(unsigned long long)arg2 event:(id)arg3 isAltEvent:(BOOL)arg4;
- (void)om_showQuickHelp:(id)sender;
- (void)om_dashNotInstalledFallback;
- (BOOL)om_showQuickHelpForSearchString:(NSString *)searchString;

@end

@implementation NSObject (OMSwizzledIDESourceCodeEditor)

- (void)om_showQuickHelp:(id)sender
{
	@try {
		BOOL dashDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMOpenInDashDisabled];
		if (dashDisabled) {
			//No, this is not an infinite loop because the method is swizzled:
			[self om_showQuickHelp:sender];
			return;
		}
		NSString *symbolString = [self valueForKeyPath:@"selectedExpression.symbolString"];
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

- (void)om_textView:(NSTextView *)textView didClickOnTemporaryLinkAtCharacterIndex:(unsigned long long)charIndex event:(NSEvent *)event isAltEvent:(BOOL)isAltEvent
{
	BOOL dashDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMOpenInDashDisabled];
	if (isAltEvent && !dashDisabled) {
		@try {
			NSArray *linkRanges = [textView valueForKey:@"_temporaryLinkRanges"];
			NSMutableString *searchString = [NSMutableString string];
			for (NSValue *rangeValue in linkRanges) {
				NSRange range = [rangeValue rangeValue];
				NSString *stringFromRange = [textView.textStorage.string substringWithRange:range];
				[searchString appendString:stringFromRange];
			}
            if(searchString.length)
            {
                BOOL dashOpened = [self om_showQuickHelpForSearchString:searchString];
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
	} else {
		//Preserve the default behavior for cmd-clicks:
		[self om_textView:textView didClickOnTemporaryLinkAtCharacterIndex:charIndex event:event isAltEvent:isAltEvent];
	}
}

- (BOOL)om_showQuickHelpForSearchString:(NSString *)searchString
{
    searchString = [self om_appendActiveSchemeKeyword:searchString];
	NSPasteboard *pboard = [NSPasteboard pasteboardWithUniqueName];
	[pboard setString:searchString forType:NSStringPboardType];
	return NSPerformService(@"Look Up in Dash", pboard);
}

- (NSString *)om_appendActiveSchemeKeyword:(NSString *)searchString
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
			[NSClassFromString(@"IDESourceCodeEditor") jr_swizzleMethod:@selector(textView:didClickOnTemporaryLinkAtCharacterIndex:event:isAltEvent:) withMethod:@selector(om_textView:didClickOnTemporaryLinkAtCharacterIndex:event:isAltEvent:) error:NULL];
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
			NSMenuItem *toggleDashItem = [[[NSMenuItem alloc] initWithTitle:@"Open Quick Help in Dash" action:@selector(toggleOpenInDashEnabled:) keyEquivalent:@""] autorelease];
			[toggleDashItem setTarget:self];
			[[editMenuItem submenu] addItem:toggleDashItem];
		}
	}
	return self;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(toggleOpenInDashEnabled:)) {
		if ([[NSUserDefaults standardUserDefaults] boolForKey:kOMOpenInDashDisabled]) {
			[menuItem setState:NSOffState];
		} else {
			[menuItem setState:NSOnState];
		}
	}
	return YES;
}

- (void)toggleOpenInDashEnabled:(id)sender
{
	BOOL disabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMOpenInDashDisabled];
	[[NSUserDefaults standardUserDefaults] setBool:!disabled forKey:kOMOpenInDashDisabled];
}

@end
