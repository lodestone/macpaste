MacPaste - The Missing Mouse Paste Feature for Mac OSX

## Overview
This simulates the middle mouse button copy/paste found in Unix/Linux X11 window managers.

If you first highlight arbitrary text or visual elements, you can then middle click in the same or another window to paste the elements. Unlike X11, this program will alter your clipboard. Perhaps a future version could manage its own buffer like X11.

#### How?
This program assumes that the key combinations Cmd+C/Cmd+V are mapped as copy and paste in your applications. If they are not, then this will not work, because the program simply posts the following events: 

1. Cmd+C down & up (copies your selected text or objects)
2. Left Mouse Button down & up (gives focus to the window under your current mouse position)
3. Cmd+V down & up (pastes at current mouse position)

If your mouse is left-handed, or you remapped the keystrokes, then just edit the C program and recompile.

#### Limitations
If you left click a window, such as the target window, before middle clicking, then focus will be lost from the source and this feature will not work. An alternative mode is in development to circumvent this by monitoring mouse drags and double clicks, which will trigger a copy immediately instead of delaying copy.

## Usage
Run the executable in the background from your shell command-line interface, or run it as a "Login Item" at startup (System Preferences > Users & Groups > Login Items > + > Navigate to file).

## Building

	make macpaste

## License
Public Domain 2016

