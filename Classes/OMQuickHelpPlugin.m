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
#define kOMDashSearchPlatform               @"OMDashSearchPlatform"
#define kOMCopySelectorDisabled             @"OMCopySelectorOnCommandShiftDisabled"


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
		BOOL dashOpened = [self om_showQuickHelpForSearchString:symbolString];
		if (!dashOpened) {
			[self om_dashNotInstalledFallback];
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
	BOOL copySelectorDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMCopySelectorDisabled];

	if (isAltEvent && !dashDisabled) {
		@try {
			NSArray *linkRanges = [textView valueForKey:@"_temporaryLinkRanges"];
			NSMutableString *searchString = [NSMutableString string];

            // search options
            NSString *searchPlatform = [[NSUserDefaults standardUserDefaults] stringForKey:kOMDashSearchPlatform];

            if ([searchPlatform length] > 0) {
                [searchString appendString:searchPlatform];
                [searchString appendString:@":"];
            }

            // link
            for (NSValue *rangeValue in linkRanges) {
				NSRange range = [rangeValue rangeValue];
				NSString *stringFromRange = [textView.textStorage.string substringWithRange:range];
				[searchString appendString:stringFromRange];
			}
			BOOL dashOpened = [self om_showQuickHelpForSearchString:searchString];
			if (!dashOpened) {
				[self om_dashNotInstalledFallback];
			}
		}
		@catch (NSException *exception) {

		}
	} else if (!copySelectorDisabled && !isAltEvent && ([event modifierFlags] & NSShiftKeyMask)) {
        NSArray *linkRanges = [textView valueForKey:@"_temporaryLinkRanges"];
        NSMutableString *selectorString = [NSMutableString string];

        // link
        for (NSValue *rangeValue in linkRanges) {
            NSRange range = [rangeValue rangeValue];
            NSString *stringFromRange = [textView.textStorage.string substringWithRange:range];
            [selectorString appendString:stringFromRange];
        }
        
        if ([selectorString length] > 0) {
            NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
            NSString *wrappedString = [NSString stringWithFormat:@"@selector(%@)", selectorString];
            
            [pasteboard clearContents];
            [pasteboard writeObjects:[NSArray arrayWithObject:wrappedString]];
        }
        else {
            //Preserve the default behavior for cmd-clicks:
            [self om_textView:textView didClickOnTemporaryLinkAtCharacterIndex:charIndex event:event isAltEvent:isAltEvent];
        }
	} else {
		//Preserve the default behavior for cmd-clicks:
		[self om_textView:textView didClickOnTemporaryLinkAtCharacterIndex:charIndex event:event isAltEvent:isAltEvent];
	}
}

- (BOOL)om_showQuickHelpForSearchString:(NSString *)searchString
{
	if (searchString.length == 0) {
		NSBeep();
    } else {
        NSPasteboard *pboard = [NSPasteboard pasteboardWithUniqueName];

        [pboard setString:searchString forType:NSStringPboardType];

        if (NSPerformService(@"Look Up in Dash", pboard)) {
            return YES;
        }

		if ([[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"dash://%@", searchString]]]) {
            return YES;
        }
	}
    return NO;
}

@end



@implementation OMQuickHelpPlugin

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static OMQuickHelpPlugin *quickHelpPlugin = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		if (NSClassFromString(@"IDESourceCodeEditor") != NULL) {
			[NSClassFromString(@"IDESourceCodeEditor") jr_swizzleMethod:@selector(showQuickHelp:) withMethod:@selector(om_showQuickHelp:) error:NULL];
			[NSClassFromString(@"IDESourceCodeEditor") jr_swizzleMethod:@selector(textView:didClickOnTemporaryLinkAtCharacterIndex:event:isAltEvent:) withMethod:@selector(om_textView:didClickOnTemporaryLinkAtCharacterIndex:event:isAltEvent:) error:NULL];
		}
		quickHelpPlugin = [[self alloc] init];
	});
}

- (id)init
{
	self  = [super init];
	if (self) {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

        if ([userDefaults stringForKey:kOMDashSearchPlatform] == nil) {
            [userDefaults setObject:@"" forKey:kOMDashSearchPlatform];
        }

		//TODO: It would be better to add this to the Help menu, but that seems to be populated from somewhere else...
		NSMenuItem *editMenuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
		if (editMenuItem) {
			[[editMenuItem submenu] addItem:[NSMenuItem separatorItem]];

            // toggle Dash
            NSMenuItem *toggleDashItem = [[NSMenuItem alloc] initWithTitle:@"Open Quick Help in Dash"
                                                                    action:@selector(toggleOpenInDashEnabled:)
                                                             keyEquivalent:@""];
            [toggleDashItem setTarget:self];

            [[editMenuItem submenu] addItem:toggleDashItem];
            [toggleDashItem release];

            // search options menu items
            NSMenuItem *searchPlatformsItem = [[NSMenuItem alloc] initWithTitle:@"Dash Search Platform"
                                                                         action:NULL
                                                                  keyEquivalent:@""];

            [[editMenuItem submenu] addItem:searchPlatformsItem];
            [searchPlatformsItem release];

            NSMenu *searchOptionsMenu = [[NSMenu alloc] initWithTitle:@"Dash Search Options"];

            [searchPlatformsItem setSubmenu:searchOptionsMenu];
            [searchOptionsMenu release];

            NSMenuItem *searchAllItem = [[NSMenuItem alloc] initWithTitle:@"All Platforms"
                                                                   action:@selector(toggleSearchPlatform:)
                                                            keyEquivalent:@""];

            [searchAllItem setTarget:self];
            [searchAllItem setRepresentedObject:@""];

            [searchOptionsMenu addItem:searchAllItem];
            [searchAllItem release];

            NSArray *docsets = (NSArray *)CFPreferencesCopyAppValue((CFStringRef)@"docsets",
                                                                    (CFStringRef)@"com.kapeli.dash");
            NSMutableSet *platforms = [NSMutableSet set];

            for (NSDictionary *docset in docsets) {
                if (![docset isKindOfClass:[NSDictionary class]]) {
                    continue;
                }

                NSString *platform = [docset objectForKey:@"platform"];

                if ([platforms containsObject:platform]) {
                    continue;
                }

                [platforms addObject:platform];

                if (![platform isKindOfClass:[NSString class]]) {
                    continue;
                }

                NSMenuItem *searchPlatformItem = [[NSMenuItem alloc] initWithTitle:platform
                                                                            action:@selector(toggleSearchPlatform:)
                                                                     keyEquivalent:@""];

                [searchPlatformItem setTarget:self];
                [searchPlatformItem setRepresentedObject:platform];

                [searchOptionsMenu addItem:searchPlatformItem];
                [searchPlatformItem release];
            }

            if (docsets != NULL) {
                CFRelease(docsets);
            }

            if ([platforms count] == 0) {
                NSMenuItem *searchiOSItem = [[NSMenuItem alloc] initWithTitle:@"iphoneos"
                                                                       action:@selector(toggleSearchPlatform:)
                                                                keyEquivalent:@""];

                [searchiOSItem setTarget:self];
                [searchiOSItem setRepresentedObject:@"iphoneos"];

                [searchOptionsMenu addItem:searchiOSItem];
                [searchiOSItem release];

                NSMenuItem *searchOSXItem = [[NSMenuItem alloc] initWithTitle:@"macosx"
                                                                       action:@selector(toggleSearchPlatform:)
                                                                keyEquivalent:@""];

                [searchOSXItem setTarget:self];
                [searchOSXItem setRepresentedObject:@"macosx"];

                [searchOptionsMenu addItem:searchOSXItem];
                [searchOSXItem release];
            }

            // toggle Copy selector on command-shift-click
            NSMenuItem *toggleCopySelectorItem = [[NSMenuItem alloc] initWithTitle:@"Copy Selector"
                                                                            action:@selector(toggleCopySelectorEnabled:)
                                                                     keyEquivalent:@""];
            [toggleCopySelectorItem setTarget:self];

            [[editMenuItem submenu] addItem:toggleCopySelectorItem];
            [toggleCopySelectorItem release];
        }
	}
	return self;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    SEL action = [menuItem action];

	if (action == @selector(toggleOpenInDashEnabled:)) {
		if ([[NSUserDefaults standardUserDefaults] boolForKey:kOMOpenInDashDisabled]) {
			[menuItem setState:NSOffState];
		} else {
			[menuItem setState:NSOnState];
		}
	}
	else if (action == @selector(toggleCopySelectorEnabled:)) {
		if ([[NSUserDefaults standardUserDefaults] boolForKey:kOMCopySelectorDisabled]) {
			[menuItem setState:NSOffState];
		} else {
			[menuItem setState:NSOnState];
		}
	}
	else if (action == @selector(toggleSearchPlatform:)) {
        NSString *searchPlatform = [[NSUserDefaults standardUserDefaults] stringForKey:kOMDashSearchPlatform];
        id representedObject = [menuItem representedObject];

        if ([searchPlatform isEqual:representedObject]) {
			[menuItem setState:NSOnState];
		} else {
			[menuItem setState:NSOffState];
		}
	}

	return YES;
}

- (void)toggleOpenInDashEnabled:(id)sender
{
	BOOL disabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMOpenInDashDisabled];
	[[NSUserDefaults standardUserDefaults] setBool:!disabled forKey:kOMOpenInDashDisabled];
}

- (void)toggleCopySelectorEnabled:(id)sender
{
	BOOL disabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMCopySelectorDisabled];
	[[NSUserDefaults standardUserDefaults] setBool:!disabled forKey:kOMCopySelectorDisabled];
}

- (void)toggleSearchPlatform:(id)sender
{
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    id representedObject = [menuItem representedObject];
    
	[[NSUserDefaults standardUserDefaults] setObject:representedObject forKey:kOMDashSearchPlatform];
}

@end
