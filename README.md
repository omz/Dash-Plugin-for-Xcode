# Dash Plugin for Xcode

## Overview

This plugin allows you to use [Dash](http://kapeli.com/dash/) instead of Xcode's own documentation viewer when using **Option-Click** (or the equivalent **keyboard shortcut**) to view the documentation for the selected symbol. 

I'm [@olemoritz](http://twitter.com/olemoritz) on Twitter.

## Usage & Installation

1. Download the source, build the Xcode project and restart Xcode. The plugin will automatically be installed in `~/Library/Application Support/Developer/Shared/Xcode/Plug-ins`. To uninstall, just remove the plugin from there (and restart Xcode).
2. To use - **Option-Click** any method/class/symbol in Xcode's text editor. 
3. If you prefer the **keyboard**, set up a shortcut in Xcode's Preferences > Key Bindings for **Quick Help for Selected Item** or **Search Documentation for Selected Text**.
4. The plugin can automatically enable/disable docsets (e.g. OS X or iOS) based on what you're working on. Check out the [Automatic Platform Detection](#automatic-platform-detection) section below.

## Alcatraz

This plugin can be installed using [Alcatraz](http://alcatraz.io/). Search for `OMQuickHelp` in Alcatraz.

## Automatic Platform Detection

The plugin can use Xcode's current active scheme to try to guess which docsets it should search, making it very easy to switch between iOS, OS X or even C/C++ projects. It's recommended that all users try out this feature and report back anything that might be wrong.

To enable automatic platform detection, go to **Xcode's Help > Dash Integration > Enable Dash Platform Detection** in Xcode's menu (after you installed the plugin).

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
