// Public Domain License 2016
//
// Simulate right-handed unix/linux X11 middle-mouse-click copy and paste.
//
// References:
// http://stackoverflow.com/questions/3134901/mouse-tracking-daemon
// http://stackoverflow.com/questions/2379867/simulating-key-press-events-in-mac-os-x#2380280
//
// Compile with:
// gcc -framework ApplicationServices -o macpaste macpaste.c
//
// Start with:
// ./macpaste
//
// Terminate with Ctrl+C

#include <ApplicationServices/ApplicationServices.h>
#include <Carbon/Carbon.h> // kVK_ANSI_*

// We know this is only gets called for 3rd and higher mouse button click release.
static CGEventRef mouseMiddleClickUpCallback (
    CGEventTapProxy proxy,
    CGEventType type,
    CGEventRef event,
    void * refcon
) {
    CGEventSourceRef source = CGEventSourceCreate( kCGEventSourceStateCombinedSessionState );  
    CGEventTapLocation tapA = kCGAnnotatedSessionEventTap;
    CGEventTapLocation tapH = kCGHIDEventTap;
    
		// Copy selected items.
    CGEventRef kbdEventCopyDown = CGEventCreateKeyboardEvent( source, kVK_ANSI_C, 1 );                 
    CGEventRef kbdEventCopyUp   = CGEventCreateKeyboardEvent( source, kVK_ANSI_C, 0 );                 
    CGEventSetFlags( kbdEventCopyDown, kCGEventFlagMaskCommand );
		CGEventPost( tapA, kbdEventCopyDown );
		CGEventPost( tapA, kbdEventCopyUp );
		CFRelease( kbdEventCopyDown );
		CFRelease( kbdEventCopyUp );

		// Mouse click to focus and position insertion cursor.
		CGPoint mouseLocation = CGEventGetLocation( event );
    CGEventRef mouseClickDown = CGEventCreateMouseEvent( NULL, kCGEventLeftMouseDown, mouseLocation, kCGMouseButtonLeft );
    CGEventRef mouseClickUp   = CGEventCreateMouseEvent( NULL, kCGEventLeftMouseUp,   mouseLocation, kCGMouseButtonLeft );
  	CGEventPost( tapH, mouseClickDown );
  	CGEventPost( tapH, mouseClickUp );
  	CFRelease( mouseClickDown );
  	CFRelease( mouseClickUp );
  	
  	// Paste.
    CGEventRef kbdEventPasteDown = CGEventCreateKeyboardEvent( source, kVK_ANSI_V, 1 );                 
    CGEventRef kbdEventPasteUp   = CGEventCreateKeyboardEvent( source, kVK_ANSI_V, 0 );                 
    CGEventSetFlags( kbdEventPasteDown, kCGEventFlagMaskCommand );
		CGEventPost( tapA, kbdEventPasteDown );
		CGEventPost( tapA, kbdEventPasteUp );
		CFRelease( kbdEventPasteDown );
		CFRelease( kbdEventPasteUp );

		CFRelease( source );

    // Pass on the event, we must not modify it anyway, we are a listener
    return event;
}

int main (
    int argc,
    char ** argv
) {
    CGEventMask emask;
    CFMachPortRef myEventTap;
    CFRunLoopSourceRef eventTapRLSrc;

		printf("Quit with Ctrl+C\n");

    // We only want "other" mouse button click-release, such as middle or exotic.
    // Ignores left and right mouse buttons.
    emask = CGEventMaskBit( kCGEventOtherMouseUp );

    // Create the Tap
    myEventTap = CGEventTapCreate (
        kCGSessionEventTap,          // Catch all events for current user session
        kCGTailAppendEventTap,       // Append to end of EventTap list
        kCGEventTapOptionListenOnly, // We only listen, we don't modify
        emask,
        & mouseMiddleClickUpCallback,
        NULL                         // We need no extra data in the callback
    );

    // Create a RunLoop Source for it
    eventTapRLSrc = CFMachPortCreateRunLoopSource(
        kCFAllocatorDefault,
        myEventTap,
        0
    );

    // Add the source to the current RunLoop
    CFRunLoopAddSource(
        CFRunLoopGetCurrent(),
        eventTapRLSrc,
        kCFRunLoopDefaultMode
    );
    
    // Keep the RunLoop running forever
    CFRunLoopRun();

    // Not reached (RunLoop above never stops running)
    return 0;
}
