# MacPaste - The Missing Mouse Paste Feature for MacOS

This program simulates the middle mouse button copy/paste found in Unix/Linux X11 window managers: Once you highlight arbitrary text or visual elements, you can then middle click in the same or another window to paste the elements.

**Note:** Unlike X11, this program will alter your clipboard. Perhaps a future version could manage its own buffer like X11.

## Installation

The script `setup.sh` takes care of most of the integration into MacOS.

* If you have a three-button mouse, run `./setup.sh`. You will have copy and paste right away.
* If not (e.g. Trackpad, MagicMouse etc), run `./setup.sh -n`. This will create the copy, but not the paste action. See below for ways to mimic the middle-click paste.

In detail, the script

* compiles the C binary and puts it into `$HOME/bin`
* creates a LaunchAgent `plist` file and puts it into `$HOME/Library/LaunchAgents/`

Then **you have to** open `System Preferences -> Security & Privacy -> Privacy` and add `$HOME/bin/macpaste` to allow the program to listen to system events.  

If you want to test the installation, make sure your terminal is also listed in the `Privacy` list, and then run `launchctl load $HOME/Library/LaunchAgents/local.macpaste.plist` for the terminal.

Alternatively, log out and log in again.

## The elusive middle button

One solution to work with stock Apple Trackpad and MagicMouse, which lack an explicit middle button, uses [BetterTouchTool](https://folivora.ai/) (BTT). If you don't have it yet, it has a trial version but it'll require a (rather cheap) license if you want to keep it for longer.

BTT has a much wider range of events and actions than the default MacOS, specifically it has a `1-Finger Middle Click` for the MagicMouse, but not for the Trackpad. To have both behave in the same way, I chose `1-Finger Tap Middle` (MagicMouse) and `1-Finger Tap Bottom Middle` (Trackpad) as the triggers. You do you.

You can then add an action. The simplest is to use `Send Keyboard Shortcut` and set it to `Apple-V`, which uses the system clipboard to paste the item at the place of your cursor. Even nicer is the BTT custom clipboard. I've added two actions: `Show Clipboard / Pasteboard History`, followed by `Paste specific items`  (configured with position 1 and `Paste as Plain Text`). This solves another long-standing issue I've had with MacOS, namely that it pastes *with formatting* by default, while I normally want only the text. This way, I can copy-paste plain text with the mouse and have the keyboard shortcut `Apple-V` for formatted text. Neat, right?

## How?

This program assumes that the key combinations Cmd+C/Cmd+V are mapped as copy and paste in your applications. If they are not, then this will not work, because the program simply posts the following events: 

1. Cmd+C down & up (copies your selected text or objects) whenever your left mouse button releases.
   This allows copying text that is drag highlighted, or double-clicked to highlight words or lines.
2. Left Mouse Button down & up (position mouse cursor for paste insertion) on middle click.
3. Cmd+V down & up after tiny delay following middle click.

If your mouse is left-handed, or you remapped the keystrokes, then just edit the C program and recompile.

