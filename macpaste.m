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
#include <AppKit/NSCursor.h>

char isDragging = 0;
long long prevPrevClickTime = 0;
long long prevClickTime = 0;
long long curClickTime = 0;
NSPoint initialLocation;

CGEventTapLocation tapA = kCGAnnotatedSessionEventTap;
CGEventTapLocation tapH = kCGHIDEventTap;

#define TRIPLE_CLICK_MILLIS 500

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
      prevPrevClickTime = prevClickTime;
      prevClickTime = curClickTime;
      curClickTime = now();
    }

    static char isTripleClick() {
      return ( curClickTime - prevPrevClickTime ) < TRIPLE_CLICK_MILLIS;
    }

    static CGEventRef mouseCallback (
      CGEventTapProxy proxy,
      CGEventType type,
      CGEventRef event,
      void * refcon
    ) {
      int* dontpaste = refcon;
      int button;
      switch ( type )
      {
        case kCGEventOtherMouseDown:
        button = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber);
        NSCursor* cursor = [NSCursor currentSystemCursor];
        NSCursor* ibeam = [NSCursor IBeamCursor];
        if (*dontpaste == 0 && button == 2 && NSEqualPoints([cursor hotSpot] , [ibeam hotSpot] )) {
        // NSLog(@"paste %@", NSStringFromPoint( [NSEvent mouseLocation]));
          paste( event );
        }
        break;

        case kCGEventLeftMouseDown:
        //NSLog(@"down %@", NSStringFromPoint( [NSEvent mouseLocation]));
        recordClickTime();
        break;

        case kCGEventLeftMouseUp:
        //NSLog(@"up %@", NSStringFromPoint( [NSEvent mouseLocation]));
        if (isTripleClick()) {
        NSLog(@"copytrlc %@", NSStringFromPoint( [NSEvent mouseLocation]));
          copy();
        }
        if (isDragging) {
            NSPoint clickLocation = [NSEvent mouseLocation];
            int xdiff = fabs(initialLocation.x-clickLocation.x);
            int ydiff = fabs(initialLocation.y-clickLocation.y);
            if (xdiff > 5 || ydiff > 5) {
        //NSLog(@"copydrag %@ %@", NSStringFromPoint(initialLocation), NSStringFromPoint( [NSEvent mouseLocation]));
               copy();
            }
        }
        isDragging = 0;
        break;

        case kCGEventLeftMouseDragged:
        if (!isDragging)
            initialLocation = [NSEvent mouseLocation];
        isDragging = 1;
        break;

        default:
        break;
      }

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
      NSApplicationLoad();

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
