#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <IOKit/IOKitLib.h>
#import <ServiceManagement/ServiceManagement.h>
#include <dlfcn.h>
#include <pthread.h>
#include <assert.h>
#include "Gesture.h"
#include "MenuIcon.h"

typedef const void *MTDevice;
typedef struct { float x,y; } MCPoint;
typedef struct { MCPoint position, velocity; } Vector;
typedef struct { int32_t frame; double timestamp; int32_t path, state, finger, hand; Vector normalized; float size; int32_t unused; float angle,major,minor; Vector absolute; int32_t a,b; float density; } Touch;
typedef void (*FrameCallback)(MTDevice,Touch*,size_t,double,size_t);
static CFArrayRef (*CreateList)(void);
static void (*Register)(MTDevice,FrameCallback), (*Unregister)(MTDevice,FrameCallback);
static int (*Start)(MTDevice,int), (*Stop)(MTDevice), (*Family)(MTDevice,int*);
static io_service_t (*Service)(MTDevice);
static bool (*Running)(MTDevice);
static void *framework;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static MTDevice mouse;
static int fingerCount, otherFingers;
static double fingerX=.5, fingerY=.5, touchTime, otherTime;
static Gesture gesture = {.enabled=true,.width=.24};
static CFMachPortRef eventTap;
static CFRunLoopSourceRef eventSource;
static NSString *frameworkError;
static bool diagnostics;
static unsigned long mouseFrames;

static double now(void) { return NSProcessInfo.processInfo.systemUptime; }
static bool loadMT(void) {
    framework = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",RTLD_NOW);
    if (!framework) return false;
#define LOAD(variable,symbol) variable = dlsym(framework,symbol); if (!variable) return false;
    LOAD(CreateList,"MTDeviceCreateList"); LOAD(Register,"MTRegisterContactFrameCallback");
    LOAD(Unregister,"MTUnregisterContactFrameCallback"); LOAD(Start,"MTDeviceStart");
    LOAD(Stop,"MTDeviceStop"); LOAD(Service,"MTDeviceGetService");
    LOAD(Family,"MTDeviceGetFamilyID"); LOAD(Running,"MTDeviceIsRunning");
    return true;
}
static NSString *product(MTDevice device) {
    io_service_t service = Service(device);
    if (!service) return @"Unknown multitouch device";
    CFTypeRef value = IORegistryEntryCreateCFProperty(service,CFSTR("Product"),kCFAllocatorDefault,0);
    id obj = CFBridgingRelease(value);
    return [obj isKindOfClass:NSString.class] ? obj : @"Unknown multitouch device";
}
static void frame(MTDevice device, Touch *touches, size_t count, double timestamp, size_t number) {
    if (count > 32 || (count && !touches)) return;
    int active=0; double x=.5,y=.5;
    for (size_t i=0; i<count; i++) {
        if (touches[i].state==3 || touches[i].state==4) {
            active++; x=touches[i].normalized.position.x; y=touches[i].normalized.position.y;
        }
    }
    pthread_mutex_lock(&lock);
    if (device==mouse) {
        mouseFrames++;
        if (diagnostics && mouseFrames%60==1) { fprintf(stderr,"TOUCH raw=%zu active=%d state=%d x=%.3f y=%.3f\n",count,active,count?touches[0].state:-1,x,y); }
        fingerCount=active; fingerX=x; fingerY=y; touchTime=now(); }
    else { otherFingers=active; otherTime=now(); }
    pthread_mutex_unlock(&lock);
}
static CGEventRef eventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *context) {
    if (type==kCGEventTapDisabledByTimeout || type==kCGEventTapDisabledByUserInput) {
        if (eventTap) CGEventTapEnable(eventTap,true);
        return event;
    }
    int kind,button;
    switch(type) {
        case kCGEventLeftMouseDown: kind=0; button=0; break;
        case kCGEventRightMouseDown: kind=0; button=1; break;
        case kCGEventLeftMouseDragged: kind=1; button=0; break;
        case kCGEventRightMouseDragged: kind=1; button=1; break;
        case kCGEventLeftMouseUp: kind=2; button=0; break;
        case kCGEventRightMouseUp: kind=2; button=1; break;
        default: return event;
    }
    if (diagnostics && kind==0) {
        pthread_mutex_lock(&lock);
        fprintf(stderr,"CLICK pid=%lld fingers=%d x=%.3f y=%.3f age=%.3f trackpad=%d frames=%lu enabled=%d\n",(long long)CGEventGetIntegerValueField(event,kCGEventSourceUnixProcessID),fingerCount,fingerX,fingerY,now()-touchTime,otherFingers,mouseFrames,gesture.enabled);
        pthread_mutex_unlock(&lock);
    }
    // Ignore events synthesized by applications, including other gesture utilities.
    if (CGEventGetIntegerValueField(event,kCGEventSourceUnixProcessID)!=0) return event;
    pthread_mutex_lock(&lock);
    int fingers=fingerCount; double x=fingerX,age=now()-touchTime;
    bool trackpad=otherFingers>0 && now()-otherTime<.20;
    pthread_mutex_unlock(&lock);
    if (convert(&gesture,kind,button,fingers,x,age,trackpad)) {
        if (diagnostics && kind==0) fprintf(stderr,"CONVERTED center press to middle down\n");
        CGEventSetType(event,kind==0?kCGEventOtherMouseDown:kind==1?kCGEventOtherMouseDragged:kCGEventOtherMouseUp);
        CGEventSetIntegerValueField(event,kCGMouseEventButtonNumber,2);
    }
    return event;
}

@interface MouseView : NSView
@end
@implementation MouseView
- (void)drawRect:(NSRect)dirty {
    NSRect body=NSMakeRect(25,15,150,240);
    [NSColor.quaternaryLabelColor setFill]; [[NSBezierPath bezierPathWithRoundedRect:body xRadius:70 yRadius:70] fill];
    [NSGraphicsContext saveGraphicsState]; [[NSBezierPath bezierPathWithRoundedRect:body xRadius:70 yRadius:70] addClip];
    [[NSColor.systemTealColor colorWithAlphaComponent:.25] setFill];
    NSRectFill(NSMakeRect(100-75*gesture.width,15,150*gesture.width,240));
    [NSGraphicsContext restoreGraphicsState];
    pthread_mutex_lock(&lock); int n=fingerCount; double x=fingerX,y=fingerY,age=now()-touchTime; pthread_mutex_unlock(&lock);
    if (n>0 && age<.3) {
        [(fabs(x-.5)<=gesture.width/2 ? NSColor.systemTealColor:NSColor.secondaryLabelColor) setFill];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(25+150*x-7,15+240*y-7,14,14)] fill];
    }
    [@"CENTER" drawAtPoint:NSMakePoint(76,125) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:11 weight:NSFontWeightSemibold],NSForegroundColorAttributeName:NSColor.labelColor}];
}
@end
@interface TestView : NSView
@property NSString *message;
@end
@implementation TestView
- (void)drawRect:(NSRect)dirty {
    [[NSColor.systemTealColor colorWithAlphaComponent:.10] setFill]; [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:12 yRadius:12] fill];
    NSString *text=self.message?:@"Click here to test";
    NSDictionary *attrs=@{NSFontAttributeName:[NSFont systemFontOfSize:15 weight:NSFontWeightMedium],NSForegroundColorAttributeName:NSColor.labelColor};
    NSSize size=[text sizeWithAttributes:attrs];
    [text drawAtPoint:NSMakePoint((self.bounds.size.width-size.width)/2,(self.bounds.size.height-size.height)/2) withAttributes:attrs];
}
- (void)mouseDown:(NSEvent*)e { if (diagnostics) fprintf(stderr,"TEST received LEFT\n"); self.message=@"Left click"; self.needsDisplay=YES; }
- (void)rightMouseDown:(NSEvent*)e { self.message=@"Right click"; self.needsDisplay=YES; }
- (void)otherMouseDown:(NSEvent*)e { if (diagnostics) fprintf(stderr,"TEST received OTHER button=%ld\n",(long)e.buttonNumber); self.message=e.buttonNumber==2?@"Middle click received ✓":@"Other click"; self.needsDisplay=YES; }
- (void)otherMouseDragged:(NSEvent*)e { self.message=@"Middle drag received ✓"; self.needsDisplay=YES; }
@end

@interface App : NSObject <NSApplicationDelegate>
@property NSStatusItem *status;
@property NSWindow *window;
@property NSTextField *stateLabel,*widthLabel,*countLabel;
@property NSButton *enableButton,*loginButton;
@property MouseView *mouseView;
@property NSMenuItem *toggleItem;
@property NSMutableArray *devices;
@end
@implementation App
- (NSTextField*)label:(NSString*)text rect:(NSRect)rect size:(CGFloat)size {
    NSTextField *label=[NSTextField wrappingLabelWithString:text]; label.frame=rect; label.font=[NSFont systemFontOfSize:size];
    [self.window.contentView addSubview:label]; return label;
}
- (NSButton*)button:(NSString*)title action:(SEL)action rect:(NSRect)rect {
    NSButton *b=[NSButton buttonWithTitle:title target:self action:action]; b.frame=rect; [self.window.contentView addSubview:b]; return b;
}
- (void)applicationDidFinishLaunching:(NSNotification*)note {
    diagnostics=[NSProcessInfo.processInfo.arguments containsObject:@"--diagnostics"];
    self.devices=[NSMutableArray array];
    NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
    [d registerDefaults:@{@"width":@.24,@"enabled":@YES}]; gesture.width=MIN(.6,MAX(.1,[d doubleForKey:@"width"])); gesture.enabled=[d boolForKey:@"enabled"];
    if (!loadMT()) frameworkError=@"This macOS version’s touch framework is unavailable.";
    self.status=[NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.status.button.title=@"";
    self.status.button.image=magicMouseMenuIcon();
    self.status.button.imagePosition=NSImageOnly;
    self.status.button.toolTip=@"MagicCenter — center click for Magic Mouse";
    NSMenu *menu=[NSMenu new];
    [menu addItemWithTitle:@"MagicCenter Settings…" action:@selector(show) keyEquivalent:@""];
    self.toggleItem=[menu addItemWithTitle:@"Enable Center Click" action:@selector(toggle) keyEquivalent:@""];
    NSMenuItem *dockItem=[menu addItemWithTitle:@"Show in Dock" action:@selector(toggleDock:) keyEquivalent:@""];
    dockItem.state=[NSUserDefaults.standardUserDefaults boolForKey:@"showInDock"]?NSControlStateValueOn:NSControlStateValueOff;
    [menu addItem:NSMenuItem.separatorItem];
    [menu addItemWithTitle:@"Quit MagicCenter" action:@selector(quit) keyEquivalent:@"q"];
    for (NSMenuItem *item in menu.itemArray) item.target=self; self.status.menu=menu;
    [self buildWindow]; [self scan]; [self tick];
    [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(scan) userInfo:nil repeats:YES];
    [NSTimer scheduledTimerWithTimeInterval:.1 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(wake:) name:NSWorkspaceDidWakeNotification object:nil];
    if (![d boolForKey:@"openedBefore"] || !AXIsProcessTrusted() || [NSProcessInfo.processInfo.arguments containsObject:@"--show-settings"]) [self show];
    [d setBool:YES forKey:@"openedBefore"];
    if (!AXIsProcessTrusted()) {
        NSDictionary *options=@{(__bridge NSString*)kAXTrustedCheckOptionPrompt:@YES};
        AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    }
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--smoke-test"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(), ^{
            [self show]; [self tick]; [self.window.contentView display];
            NSView *v=self.window.contentView;
            NSBitmapImageRep *bitmap=[v bitmapImageRepForCachingDisplayInRect:v.bounds];
            [v cacheDisplayInRect:v.bounds toBitmapImageRep:bitmap];
            NSString *path=NSProcessInfo.processInfo.environment[@"MAGICCENTER_PREVIEW"];
            if (path) [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
            printf("App status: %s\nEvent tap: %s\n",self.stateLabel.stringValue.UTF8String,eventTap?"active":"unavailable");
            [NSApp terminate:nil];
        });
    }
}
- (void)buildWindow {
    self.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,640,460) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];
    self.window.contentView.wantsLayer=YES;
    self.window.contentView.layer.backgroundColor=NSColor.windowBackgroundColor.CGColor;
    self.window.title=@"MagicCenter"; self.window.releasedWhenClosed=NO; [self.window center];
    NSTextField *title=[self label:@"Your mouse. One more button." rect:NSMakeRect(28,392,580,36) size:25]; title.font=[NSFont systemFontOfSize:25 weight:NSFontWeightBold];
    [self label:@"Press with one finger in the highlighted center strip." rect:NSMakeRect(28,358,580,26) size:14];
    self.mouseView=[[MouseView alloc] initWithFrame:NSMakeRect(25,78,200,270)]; [self.window.contentView addSubview:self.mouseView];
    self.enableButton=[NSButton checkboxWithTitle:@"Enable center click" target:self action:@selector(toggle)]; self.enableButton.frame=NSMakeRect(255,307,320,28); [self.window.contentView addSubview:self.enableButton];
    self.widthLabel=[self label:@"" rect:NSMakeRect(255,267,320,24) size:14];
    NSSlider *slider=[NSSlider sliderWithValue:gesture.width minValue:.10 maxValue:.60 target:self action:@selector(widthChanged:)]; slider.frame=NSMakeRect(255,236,330,24); [self.window.contentView addSubview:slider];
    [self label:@"Lift your other finger before pressing. Hold and move to middle-drag." rect:NSMakeRect(255,180,330,46) size:13];
    TestView *test=[[TestView alloc] initWithFrame:NSMakeRect(255,117,330,52)]; [self.window.contentView addSubview:test];
    self.countLabel=[self label:@"" rect:NSMakeRect(255,85,330,24) size:12];
    self.stateLabel=[self label:@"" rect:NSMakeRect(28,43,590,30) size:12];
    [self button:@"Enable Accessibility…" action:@selector(permission) rect:NSMakeRect(25,7,185,30)];
    self.loginButton=[NSButton checkboxWithTitle:@"Launch at login" target:self action:@selector(login:)]; self.loginButton.frame=NSMakeRect(245,9,190,26); [self.window.contentView addSubview:self.loginButton];
}
- (BOOL)applicationShouldHandleReopen:(NSApplication*)app hasVisibleWindows:(BOOL)visible { [self show]; return YES; }
- (void)toggleDock:(NSMenuItem*)item {
    BOOL show=![NSUserDefaults.standardUserDefaults boolForKey:@"showInDock"];
    [NSUserDefaults.standardUserDefaults setBool:show forKey:@"showInDock"];
    [NSApp setActivationPolicy:show?NSApplicationActivationPolicyRegular:NSApplicationActivationPolicyAccessory];
    item.state=show?NSControlStateValueOn:NSControlStateValueOff;
}
- (void)show { [NSApp activateIgnoringOtherApps:YES]; [self.window makeKeyAndOrderFront:nil]; }
- (void)toggle { gesture.enabled=!gesture.enabled; [NSUserDefaults.standardUserDefaults setBool:gesture.enabled forKey:@"enabled"]; [self tick]; }
- (void)widthChanged:(NSSlider*)slider { gesture.width=slider.doubleValue; [NSUserDefaults.standardUserDefaults setDouble:gesture.width forKey:@"width"]; [self tick]; }
- (void)permission {
    NSDictionary *options=@{(__bridge NSString*)kAXTrustedCheckOptionPrompt:@YES}; AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
}
- (void)login:(NSButton*)sender {
    NSError *error=nil;
    if (sender.state==NSControlStateValueOn) [SMAppService.mainAppService registerAndReturnError:&error];
    else [SMAppService.mainAppService unregisterAndReturnError:&error];
    if (error) { NSAlert *a=[NSAlert new]; a.messageText=@"Could not change launch at login"; a.informativeText=error.localizedDescription; [a runModal]; }
    [self tick];
}
- (void)installTap {
    if (eventTap || !AXIsProcessTrusted()) return;
    CGEventMask mask=CGEventMaskBit(kCGEventLeftMouseDown)|CGEventMaskBit(kCGEventLeftMouseUp)|CGEventMaskBit(kCGEventLeftMouseDragged)|CGEventMaskBit(kCGEventRightMouseDown)|CGEventMaskBit(kCGEventRightMouseUp)|CGEventMaskBit(kCGEventRightMouseDragged);
    eventTap=CGEventTapCreate(kCGSessionEventTap,kCGHeadInsertEventTap,kCGEventTapOptionDefault,mask,eventCallback,NULL);
    if (eventTap) { eventSource=CFMachPortCreateRunLoopSource(NULL,eventTap,0); CFRunLoopAddSource(CFRunLoopGetMain(),eventSource,kCFRunLoopCommonModes); CGEventTapEnable(eventTap,true); }
}
- (void)scan {
    if (frameworkError) return;
    CFArrayRef list=CreateList(); if (!list) return;
    NSMutableArray *current=[NSMutableArray array];
    MTDevice chosen=NULL;
    for (CFIndex i=0;i<CFArrayGetCount(list);i++) {
        MTDevice dev=CFArrayGetValueAtIndex(list,i); NSString *name=product(dev);
        if ([name localizedCaseInsensitiveContainsString:@"Magic Mouse"]) { if (!chosen) chosen=dev; }
        if ([name localizedCaseInsensitiveContainsString:@"Trackpad"] || dev==chosen) [current addObject:(__bridge id)dev];
    }
    for (id obj in self.devices) if (![current containsObject:obj]) { Unregister((__bridge MTDevice)obj,frame); Stop((__bridge MTDevice)obj); }
    if (mouse && mouse!=chosen) [self releaseMiddle];
    pthread_mutex_lock(&lock);
    if (mouse!=chosen) { mouse=chosen; fingerCount=0; touchTime=0; }
    otherFingers=0;
    pthread_mutex_unlock(&lock);
    for (id obj in current) {
        MTDevice dev=(__bridge MTDevice)obj;
        if (![self.devices containsObject:obj]) { Register(dev,frame); Start(dev,0); }
        else if (!Running(dev)) Start(dev,0);
    }
    self.devices=current; CFRelease(list);
}
- (void)wake:(NSNotification*)note {
    [self releaseMiddle];
    for (id obj in self.devices) { Unregister((__bridge MTDevice)obj,frame); Stop((__bridge MTDevice)obj); }
    self.devices=[NSMutableArray array];
    pthread_mutex_lock(&lock); mouse=NULL; fingerCount=0; otherFingers=0; pthread_mutex_unlock(&lock);
    [self scan];
}
- (void)tick {
    [self installTap];
    self.toggleItem.state=self.enableButton.state=gesture.enabled?NSControlStateValueOn:NSControlStateValueOff;
    if (!self.window.visible) return;
    self.widthLabel.stringValue=[NSString stringWithFormat:@"Center width · %.0f%%",gesture.width*100];
    self.loginButton.state=SMAppService.mainAppService.status==SMAppServiceStatusEnabled?NSControlStateValueOn:NSControlStateValueOff;
    NSString *state;
    if (frameworkError) state=frameworkError;
    else if (!AXIsProcessTrusted()) state=@"Setup needed: enable MagicCenter in Privacy & Security → Accessibility.";
    else if (!eventTap) state=@"Accessibility granted. Quit and reopen MagicCenter to start the click listener.";
    else if (!mouse) state=@"Waiting for a Magic Mouse. Connect it using Bluetooth.";
    else if (!gesture.enabled) state=@"Paused — normal mouse clicks are passing through.";
    else state=@"Ready · Magic Mouse connected · center click enabled";
    if (diagnostics && ![self.stateLabel.stringValue isEqualToString:state]) fprintf(stderr,"STATUS %s\n",state.UTF8String);
    self.stateLabel.stringValue=state;
    self.countLabel.stringValue=[NSString stringWithFormat:@"%lu middle clicks this session",gesture.clicks];
    self.mouseView.needsDisplay=YES;
}
- (void)quit { [NSApp terminate:nil]; }
- (void)releaseMiddle {
    if (gesture.dragging) {
        CGEventRef e=CGEventCreate(NULL); CGPoint p=CGEventGetLocation(e); CFRelease(e);
        CGEventRef up=CGEventCreateMouseEvent(NULL,kCGEventOtherMouseUp,p,kCGMouseButtonCenter); CGEventPost(kCGSessionEventTap,up); CFRelease(up);
        gesture.dragging=false;
    }
}
- (void)applicationWillTerminate:(NSNotification*)note {
    [self releaseMiddle];
    if (eventTap) { CGEventTapEnable(eventTap,false); CFRunLoopRemoveSource(CFRunLoopGetMain(),eventSource,kCFRunLoopCommonModes); CFRelease(eventSource); CFRelease(eventTap); }
    for (id obj in self.devices) { Unregister((__bridge MTDevice)obj,frame); Stop((__bridge MTDevice)obj); }
}
@end

int main(int argc,const char **argv) {
    @autoreleasepool {
        if (argc>2 && strcmp(argv[1],"--export-icon")==0) {
            NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:180 pixelsHigh:200 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
            [NSGraphicsContext saveGraphicsState];
            [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
            [NSColor.whiteColor setFill]; NSRectFill(NSMakeRect(0,0,180,200));
            NSImage *icon=magicMouseMenuIcon(); icon.template=NO;
            [icon drawInRect:NSMakeRect(0,0,180,200)];
            [NSGraphicsContext restoreGraphicsState];
            BOOL saved=[[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES];
            return saved?0:1;
        }
        if (argc>1 && strcmp(argv[1],"--integration-test")==0) {
            fingerCount=1; fingerX=.5; touchTime=now();
            CGEventRef e=CGEventCreateMouseEvent(NULL,kCGEventLeftMouseDown,CGPointMake(123,456),kCGMouseButtonLeft);
            CGEventSetIntegerValueField(e,kCGEventSourceUnixProcessID,0);
            CGEventSetIntegerValueField(e,kCGMouseEventClickState,2);
            CGEventSetFlags(e,kCGEventFlagMaskShift);
            eventCallback(NULL,kCGEventLeftMouseDown,e,NULL);
            assert(CGEventGetType(e)==kCGEventOtherMouseDown);
            printf("AppKit converted event type: %lu (expected %lu)\n",(unsigned long)[NSEvent eventWithCGEvent:e].type,(unsigned long)NSEventTypeOtherMouseDown);
            assert(CGEventGetIntegerValueField(e,kCGMouseEventButtonNumber)==2);
            assert(CGEventGetIntegerValueField(e,kCGMouseEventClickState)==2);
            assert(CGEventGetFlags(e)&kCGEventFlagMaskShift);
            assert(CGEventGetLocation(e).x==123);
            fingerCount=0;
            eventCallback(NULL,kCGEventLeftMouseDragged,e,NULL);
            assert(CGEventGetType(e)==kCGEventOtherMouseDragged);
            eventCallback(NULL,kCGEventLeftMouseUp,e,NULL);
            assert(CGEventGetType(e)==kCGEventOtherMouseUp);
            assert(!gesture.dragging);
            CFRelease(e);
            puts("Passed CoreGraphics event conversion; modifiers, position, click count, and drag/release pairing preserved. No events posted.");
            return 0;
        }
        if (argc>1 && strcmp(argv[1],"--diagnose")==0) {
            printf("Touch ABI size: %zu\n",sizeof(Touch));
            if (!loadMT()) { fprintf(stderr,"Multitouch framework unavailable\n"); return 1; }
            CFArrayRef list=CreateList();
            if (list) { for (CFIndex i=0;i<CFArrayGetCount(list);i++) { MTDevice dev=CFArrayGetValueAtIndex(list,i); int family=0; Family(dev,&family); printf("Device: %s; family=%d\n",product(dev).UTF8String,family); } CFRelease(list); }
            printf("Accessibility: %s\n",AXIsProcessTrusted()?"enabled":"not enabled"); return 0;
        }
        NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;
        if (bundleIdentifier.length && [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdentifier].count>1) return 0;
        NSApplication *application=NSApplication.sharedApplication; [application setActivationPolicy:[NSUserDefaults.standardUserDefaults boolForKey:@"showInDock"]?NSApplicationActivationPolicyRegular:NSApplicationActivationPolicyAccessory];
        App *delegate=[App new]; application.delegate=delegate; [application run];
    }
    return 0;
}
