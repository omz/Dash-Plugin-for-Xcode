# Dash Plugin for Xcode

## Overview

This plugin allows you to use [Dash](http://kapeli.com/dash/) instead of Xcode's own documentation viewer when using **Option-Click** (or the equivalent **keyboard shortcut**) to view the documentation for the selected symbol. 

If you like reading Apple's documentation, you might also like my [iOS app DocSets](https://github.com/omz/DocSets-for-iOS) for reading on your iPad or iPhone, even if you have no internet connection.

I'm [@olemoritz](http://twitter.com/olemoritz) on Twitter.

## Usage & Installation

1. Download the source, build the Xcode project and restart Xcode. The plugin will automatically be installed in `~/Library/Application Support/Developer/Shared/Xcode/Plug-ins`. To uninstall, just remove the plugin from there (and restart Xcode).
2. To use - **Option-Click** any method/class/symbol in Xcode's text editor. 
3. If you prefer the **keyboard**, set up a shortcut in Xcode's Preferences > Key Bindings for **Quick Help for Selected Item**.
4. If you like the default Xcode **quick help popover**, check out the [Quick Help Popover Usage](#quick-help-popover) section below.
5. The plugin can automatically enable/disable docsets (e.g. OS X or iOS) based on what you're working on. Check out the [Automatic Platform Detection](#automatic-platform-detection) section below.

## Quick Help Popover

If you like the quick help popover that Xcode shows by default when you Option-Click something, you can re-enable it by going to **Edit > Dash Integration > Replace Reference**. 

With this option enabled, Dash will only open when you Option-Double Click something or when you click a link in the quick help popover.

## Automatic Platform Detection

The plugin can use Xcode's current active scheme to try to guess which docsets it should search, making it very easy to switch between iOS, OS X or even C/C++ projects. It's recommended that all users try out this feature and report back anything that might be wrong.

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
