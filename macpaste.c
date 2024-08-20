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
#include <sys/time.h> // gettimeofday

char isDragging = 0;
long long prevClickTime = 0;
long long curClickTime = 0;

CGEventTapLocation tapA = kCGAnnotatedSessionEventTap;
CGEventTapLocation tapH = kCGHIDEventTap;

#define DOUBLE_CLICK_MILLIS 500

long long now() {
  struct timeval te;
  gettimeofday( & te, NULL );
  long long milliseconds = te.tv_sec*1000LL + te.tv_usec/1000; // caculate milliseconds
  return milliseconds;
}

static void paste(CGEventRef event) {
  // Mouse click to focus and position insertion cursor.
  CGPoint mouseLocation = CGEventGetLocation( event );
  CGEventRef mouseClickDown = CGEventCreateMouseEvent(
    NULL, kCGEventLeftMouseDown, mouseLocation, kCGMouseButtonLeft );
    CGEventRef mouseClickUp   = CGEventCreateMouseEvent(
      NULL, kCGEventLeftMouseUp,   mouseLocation, kCGMouseButtonLeft );
      CGEventPost( tapH, mouseClickDown );
      CGEventPost( tapH, mouseClickUp );
      CFRelease( mouseClickDown );
      CFRelease( mouseClickUp );

      // Allow click events time to position cursor before pasting.
      usleep( 1000 );

      // Paste.
      CGEventSourceRef source = CGEventSourceCreate( kCGEventSourceStateCombinedSessionState );
      CGEventRef kbdEventPasteDown = CGEventCreateKeyboardEvent( source, kVK_ANSI_V, 1 );
      CGEventRef kbdEventPasteUp   = CGEventCreateKeyboardEvent( source, kVK_ANSI_V, 0 );
      CGEventSetFlags( kbdEventPasteDown, kCGEventFlagMaskCommand );
      CGEventPost( tapA, kbdEventPasteDown );
      CGEventPost( tapA, kbdEventPasteUp );
      CFRelease( kbdEventPasteDown );
      CFRelease( kbdEventPasteUp );

      CFRelease( source );
    }

    static void copy() {
      CGEventSourceRef source = CGEventSourceCreate( kCGEventSourceStateCombinedSessionState );
      CGEventRef kbdEventDown = CGEventCreateKeyboardEvent( source, kVK_ANSI_C, 1 );
      CGEventRef kbdEventUp   = CGEventCreateKeyboardEvent( source, kVK_ANSI_C, 0 );
      CGEventSetFlags( kbdEventDown, kCGEventFlagMaskCommand );
      CGEventPost( tapA, kbdEventDown );
      CGEventPost( tapA, kbdEventUp );
      CFRelease( kbdEventDown );
      CFRelease( kbdEventUp );
      CFRelease( source );
    }

    static void recordClickTime() {
      prevClickTime = curClickTime;
      curClickTime = now();
    }

    static char isDoubleClickSpeed() {
      return ( curClickTime - prevClickTime ) < DOUBLE_CLICK_MILLIS;
    }

    static char isDoubleClick() {
      return isDoubleClickSpeed();
    }

static CGEventRef mouseCallback (
  CGEventTapProxy proxy,
  CGEventType type,
  CGEventRef event,
  void * refcon
) {
  int* dontpaste = refcon;
  switch (type) {
    case kCGEventLeftMouseDown:
      recordClickTime();
      // Paste on a single left-click (if it's not a double-click or dragging).
      if (*dontpaste == 0 && !isDoubleClick() && !isDragging) {
        paste(event);
      }
      break;

    case kCGEventLeftMouseUp:
      // Trigger copy only if it's a double-click or dragging event.
      if (isDoubleClick() || isDragging) {
        copy();
      }
      isDragging = 0;
      break;

    case kCGEventLeftMouseDragged:
      isDragging = 1;
      break;

    default:
      break;
  }

  // Pass on the event, we must not modify it anyway, we are a listener.
  return event;
}

    int main (
      int argc,
      char ** argv
    ) {
      CGEventMask emask;
      CFMachPortRef myEventTap;
      CFRunLoopSourceRef eventTapRLSrc;

      // parse args for -n flag
      int c;
      int dontpaste = 0;
      while ((c = getopt (argc, argv, "n")) != -1)
      switch (c)
      {
        case 'n':
        dontpaste = 1;
        break;
        default:
        break;
      }

      // We want "other" mouse button click-release, such as middle or exotic.
      emask = CGEventMaskBit( kCGEventOtherMouseDown )  |
      CGEventMaskBit( kCGEventLeftMouseDown ) |
      CGEventMaskBit( kCGEventLeftMouseUp )   |
      CGEventMaskBit( kCGEventLeftMouseDragged );

      // Create the Tap
      myEventTap = CGEventTapCreate (
        kCGSessionEventTap,          // Catch all events for current user session
        kCGTailAppendEventTap,       // Append to end of EventTap list
        kCGEventTapOptionListenOnly, // We only listen, we don't modify
        emask,
        & mouseCallback,
        & dontpaste                   // dontpaste -> callback
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
