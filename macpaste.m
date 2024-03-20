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

#include <AppKit/NSCursor.h>
#include <AppKit/NSPasteboard.h>
#include <AppKit/NSPasteboardItem.h>
#include <ApplicationServices/ApplicationServices.h>
#include <Carbon/Carbon.h> // kVK_ANSI_*
#include <sys/time.h>      // gettimeofday

char isDragging = 0;
long long prevPrevClickTime = 0;
long long prevClickTime = 0;
long long curClickTime = 0;
NSPoint initialLocation;
NSMutableArray *lastClipItems = NULL;
long lastClipCount = 0;
long lastTouchedCount = 0;
NSMutableArray *pasteItems = NULL;

CGEventTapLocation tapA = kCGAnnotatedSessionEventTap;
CGEventTapLocation tapH = kCGHIDEventTap;

#define TRIPLE_CLICK_MILLIS 500
#define DOUBLE_CLICK_MILLIS 200

long long now() {
  struct timeval te;
  gettimeofday(&te, NULL);
  long long milliseconds =
      te.tv_sec * 1000LL + te.tv_usec / 1000; // caculate milliseconds
  return milliseconds;
}

static NSMutableArray *copy_paste_items(NSArray *items) {
  NSMutableArray *newPasteItems = [[NSMutableArray array] retain];
  for (NSPasteboardItem *item in items) {
    NSPasteboardItem *dataHolder = [[NSPasteboardItem alloc] init];
    for (NSString *type in [item types]) {
      NSData *data = [[item dataForType:type] mutableCopy];
      if (data) {
        [dataHolder setData:data forType:type];
      }
    }
    [newPasteItems addObject:dataHolder];
  }
  return newPasteItems;
}

static void logInfo(NSString *location) {
  // NSString *pinfo = NULL;
  // NSString *linfo = NULL;
  // NSString *cinfo = NULL;
  // if (pasteItems != NULL && [pasteItems count]) {
  //   pinfo = [pasteItems[0] stringForType:NSPasteboardTypeString];
  // }
  // if (lastClipItems != NULL && [lastClipItems count]) {
  //   linfo = [lastClipItems[0] stringForType:NSPasteboardTypeString];
  // }
  // if ([[[NSPasteboard generalPasteboard] pasteboardItems] count]) {
  //   cinfo = [[[NSPasteboard generalPasteboard] pasteboardItems][0]
  //       stringForType:NSPasteboardTypeString];
  // }
  // NSLog(@"%@: %ld\npaste: %@\nlastclip %@\nactual clip: %@ (%ld)", location,
  //       lastTouchedCount, pinfo, linfo, cinfo, [[NSPasteboard
  //       generalPasteboard] changeCount]);
}

static void paste(CGEventRef event) {
  NSPasteboard *pb = [NSPasteboard generalPasteboard];
  if (pasteItems != NULL) {
    // prior to posting a middle click paste, put the selection buffer in the
    // clipboard
    // NSLog(@"WRITING %@ to clip from middle button",
    //       [pasteItems[0] stringForType:NSPasteboardTypeString]);
    logInfo(@"before paste");
    [pb clearContents];
    [pb writeObjects:pasteItems];
    lastTouchedCount = [pb changeCount];
    NSMutableArray *newPasteItems = copy_paste_items(pasteItems);
    [pasteItems release];
    pasteItems = newPasteItems;
    logInfo(@"after paste");
  }

  // Mouse click to focus and position insertion cursor.
  CGPoint mouseLocation = CGEventGetLocation(event);
  CGEventRef mouseClickDown = CGEventCreateMouseEvent(
      NULL, kCGEventLeftMouseDown, mouseLocation, kCGMouseButtonLeft);
  CGEventRef mouseClickUp = CGEventCreateMouseEvent(
      NULL, kCGEventLeftMouseUp, mouseLocation, kCGMouseButtonLeft);
  CGEventPost(tapH, mouseClickDown);
  CGEventPost(tapH, mouseClickUp);
  CFRelease(mouseClickDown);
  CFRelease(mouseClickUp);

  // Allow click events time to position cursor before pasting.
  usleep(1000);

  // Paste.
  CGEventSourceRef source =
      CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
  CGEventRef kbdEventPasteDown =
      CGEventCreateKeyboardEvent(source, kVK_ANSI_V, 1);
  CGEventRef kbdEventPasteUp =
      CGEventCreateKeyboardEvent(source, kVK_ANSI_V, 0);
  CGEventSetFlags(kbdEventPasteDown, kCGEventFlagMaskCommand);
  CGEventSetFlags(kbdEventPasteUp, kCGEventFlagMaskCommand);
  CGEventPost(tapA, kbdEventPasteDown);
  CGEventPost(tapA, kbdEventPasteUp);
  CFRelease(kbdEventPasteDown);
  CFRelease(kbdEventPasteUp);

  CFRelease(source);
}

static void copy() {
  NSPasteboard *pb = [NSPasteboard generalPasteboard];
  lastClipCount = [pb changeCount];
  lastClipItems = copy_paste_items([pb pasteboardItems]);
  // NSLog(@"SET LCI %@", [lastClipItems[0]
  // stringForType:NSPasteboardTypeString]);
  CGEventSourceRef source =
      CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
  CGEventRef kbdEventDown = CGEventCreateKeyboardEvent(source, kVK_ANSI_C, 1);
  CGEventRef kbdEventUp = CGEventCreateKeyboardEvent(source, kVK_ANSI_C, 0);
  CGEventSetFlags(kbdEventDown, kCGEventFlagMaskCommand);
  CGEventPost(tapA, kbdEventDown);
  CGEventPost(tapA, kbdEventUp);
  CFRelease(kbdEventDown);
  CFRelease(kbdEventUp);
  CFRelease(source);
}

static void recordClickTime() {
  prevPrevClickTime = prevClickTime;
  prevClickTime = curClickTime;
  curClickTime = now();
}

static char isTripleClick() {
  return (curClickTime - prevPrevClickTime) < TRIPLE_CLICK_MILLIS;
}

static char isDoubleClick() {
  return (curClickTime - prevClickTime) < DOUBLE_CLICK_MILLIS;
}

static CGEventRef mouseCallback(CGEventTapProxy proxy, CGEventType type,
                                CGEventRef event, void *refcon) {
  int *dontpaste = refcon;
  int button;
  bool clipFound = FALSE;
  NSPasteboard *pb = [NSPasteboard generalPasteboard];
  // if we've copied, once we detect the copy happening store that selection
  // in pasteItems and restore the old clipboard
  if (lastClipCount != 0) {
    if (lastClipCount != [pb changeCount]) {
      if (pasteItems != NULL) {
        [pasteItems release];
      }
      pasteItems = copy_paste_items([pb pasteboardItems]);

      // NSLog(@"WRITING %@ to clip in first step, set %@ to selection",
      //       [lastClipItems[0] stringForType:NSPasteboardTypeString],
      //       [pasteItems[0] stringForType:NSPasteboardTypeString]);
      logInfo(@"before restore");
      [pb clearContents];
      [pb writeObjects:lastClipItems];
      lastTouchedCount = [pb changeCount];
      NSMutableArray *newLastClipItems = copy_paste_items(lastClipItems);
      [lastClipItems release];
      lastClipItems = newLastClipItems;
      lastClipCount = 0;
      logInfo(@"after restore");
    }
  } else if (lastTouchedCount != [pb changeCount]) {
    // NSLog(@"@NEW clipboard?");
    lastTouchedCount = [pb changeCount];
    if (lastClipItems != NULL) {
      [lastClipItems release];
    }
    lastClipItems = copy_paste_items([pb pasteboardItems]);
  }

  switch (type) {
  case kCGEventOtherMouseDown:
    button = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber);
    NSCursor *cursor = [NSCursor currentSystemCursor];
    NSCursor *ibeam = [NSCursor IBeamCursor];
    if (*dontpaste == 0 && button == 2 &&
        NSEqualPoints([cursor hotSpot], [ibeam hotSpot])) {
      // NSLog(@"paste %@", NSStringFromPoint( [NSEvent mouseLocation]));
      paste(event);
    }
    break;

  case kCGEventKeyDown:
    if (CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode) ==
            kVK_ANSI_V &&
        (CGEventGetFlags(event) & kCGEventFlagMaskCommand)) {
      if (lastClipItems != NULL) {
        // prior to a keyboard initiated paste, restore the clipboard
        // NSLog(@"WRITING %@ to clip in paste catcher",
        //       [lastClipItems[0] stringForType:NSPasteboardTypeString]);
        logInfo(@"before pasteCatcher");
        [pb clearContents];
        [pb writeObjects:lastClipItems];
        lastTouchedCount = [pb changeCount];
        NSMutableArray *newLastClipItems = copy_paste_items(lastClipItems);
        [lastClipItems release];
        lastClipItems = newLastClipItems;
        logInfo(@"after pasteCatcher");
      }
    }
    break;

  case kCGEventLeftMouseDown:
    // NSLog(@"down %@", NSStringFromPoint( [NSEvent mouseLocation]));
    recordClickTime();
    break;

  case kCGEventLeftMouseUp:
    // NSLog(@"up %@", NSStringFromPoint( [NSEvent mouseLocation]));
    if (isDoubleClick()) {
      // NSLog(@"copytrlc %@", NSStringFromPoint([NSEvent mouseLocation]));
      copy();
      logInfo(@"copy double click");
    } else if (isDragging) {
      NSPoint clickLocation = [NSEvent mouseLocation];
      int xdiff = fabs(initialLocation.x - clickLocation.x);
      int ydiff = fabs(initialLocation.y - clickLocation.y);
      if (xdiff > 5 || ydiff > 5) {
        // NSLog(@"copydrag %@ %@", NSStringFromPoint(initialLocation),
        // NSStringFromPoint([NSEvent mouseLocation]));
        copy();
        logInfo(@"copy drag");
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

int main(int argc, char **argv) {
  CGEventMask emask;
  CFMachPortRef myEventTap;
  CFRunLoopSourceRef eventTapRLSrc;

  // parse args for -n flag
  int c;
  int dontpaste = 0;
  while ((c = getopt(argc, argv, "n")) != -1)
    switch (c) {
    case 'n':
      dontpaste = 1;
      break;
    default:
      break;
    }

  // We want "other" mouse button click-release, such as middle or exotic.
  emask = CGEventMaskBit(kCGEventOtherMouseDown) |
          CGEventMaskBit(kCGEventOtherMouseUp) |
          CGEventMaskBit(kCGEventLeftMouseDown) |
          CGEventMaskBit(kCGEventLeftMouseUp) |
          CGEventMaskBit(kCGEventMouseMoved) | CGEventMaskBit(kCGEventKeyUp) |
          CGEventMaskBit(kCGEventKeyDown) |
          CGEventMaskBit(kCGEventLeftMouseDragged);
  NSApplicationLoad();
  // Create the Tap
  myEventTap = CGEventTapCreate(
      kCGSessionEventTap,          // Catch all events for current user session
      kCGTailAppendEventTap,       // Append to end of EventTap list
      kCGEventTapOptionListenOnly, // We only listen, we don't modify
      emask, &mouseCallback,
      &dontpaste // dontpaste -> callback
  );

  // Create a RunLoop Source for it
  eventTapRLSrc =
      CFMachPortCreateRunLoopSource(kCFAllocatorDefault, myEventTap, 0);

  lastClipItems =
      copy_paste_items([[NSPasteboard generalPasteboard] pasteboardItems]);
  lastTouchedCount = [[NSPasteboard generalPasteboard] changeCount];
  logInfo(@"startup");
  // Add the source to the current RunLoop
  CFRunLoopAddSource(CFRunLoopGetCurrent(), eventTapRLSrc,
                     kCFRunLoopDefaultMode);

  // Keep the RunLoop running forever
  CFRunLoopRun();

  // Not reached (RunLoop above never stops running)
  return 0;
}
