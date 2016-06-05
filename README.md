MacPaste - The Missing Mouse Paste Feature for Mac OSX

## Overview
This simulates the middle mouse button copy/paste found in Unix/Linux X11 window managers.

If you first highlight arbitrary text or visual elements, you can then middle click in the same or another window to paste the elements. Unlike X11, this program will alter your clipboard. Perhaps a future version could manage its own buffer like X11.

#### How?
This program assumes that the key combinations Cmd+C/Cmd+V are mapped as copy and paste in your applications. If they are not, then this will not work, because the program simply posts the following events: 

1. Cmd+C down & up (copies your selected text or objects) whenever your left mouse button releases.
   This allows copying text that is drag highlighted, or double-clicked to highlight words or lines.
2. Left Mouse Button down & up (position mouse cursor for paste insertion) on middle click.
3. Cmd+V down & up after tiny delay following middle click.

If your mouse is left-handed, or you remapped the keystrokes, then just edit the C program and recompile.

## Usage
Run the executable in the background from your shell command-line interface, or run it as a "Login Item" at startup (System Preferences > Users & Groups > Login Items > + > Navigate to file).

## Building

	make macpaste

## Running

    ./macpaste &

## License
Public Domain 2016

