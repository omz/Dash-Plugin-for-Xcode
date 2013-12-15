# Dash Plugin for Xcode

## Overview

This plugin allows you to use [Dash](http://kapeli.com/dash/) instead of Xcode's own documentation viewer when using **Option-Click** (or the equivalent keyboard shortcut) to view the documentation for the selected symbol. Dash will also open when you option-double-click on a symbol, or if you click a documentation link in Xcode's autocomplete popup. If you like the default Xcode quick help popover, you can still use it and make the links inside the popover open up in Dash instead.

While you could also use Dash's "Look up in Dash" Services menu item, this is better in several ways:

* It's smart about looking up symbols that are split across multiple ranges (e.g. **Option-Clicking** on `foo:` in something like `[self foo:x withBar:y andBaz:z]` searches for `foo:withBar:andBaz:` instead of just `foo:`).
* It's faster to use with the mouse, and the keyboard shortcut can be set directly in Xcode's preferences.
* You don't have to select the entire symbol that you want to look up.

If you want to use Xcode's built-in documentation popover again, you can temporarily disable the Dash integration by clicking "Dash Integration > Disabled or Replace Reference" in the "Edit" menu.

If you like reading Apple's documentation, you might also like my [iOS app DocSets](https://github.com/omz/DocSets-for-iOS) for reading on your iPad or iPhone, even if you have no internet connection.

I'm [@olemoritz](http://twitter.com/olemoritz) on Twitter.

## Usage & Installation

1. Download the source, build the Xcode project and restart Xcode. The plugin will automatically be installed in `~/Library/Application Support/Developer/Shared/Xcode/Plug-ins`. To uninstall, just remove the plugin from there (and restart Xcode).
2. To use - **Option-Click** any method/class/symbol in Xcode's text editor. 
3. If you prefer the keyboard, set up a shortcut in Xcode's Preferences > Key Bindings for **Quick Help for Selected Item**.
4. If you select "Dash Integration > Replace Reference" in the "Edit" menu, Dash won't replace the Quick Help popover entirely, but will only open when you click a link in the popover.

## Automatic Platform Detection
The plugin can use Xcode's current active scheme to determine which docset to search (iOS or OS X). Using this feature, ONLY the iOS or OS X docsets will be searched, so you might not want this if, for example, you also want to search the Cocos2D docset.

To enable automatic platform detection, go to Edit > Dash Integration > Advanced > Enable Dash Platform Detection in Xcode's menu (after you installed the plugin).

## License

    Copyright (c) 2012, Ole Zorn
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this
      list of conditions and the following disclaimer.

    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
    FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
    OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
