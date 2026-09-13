// Original vector artwork, drawn at native menu-bar size and Retina resolution.
static NSImage *magicMouseMenuIcon(void) {
    NSImage *icon=[NSImage imageWithSize:NSMakeSize(18,20) flipped:NO drawingHandler:^BOOL(NSRect rect) {
        [NSColor.blackColor setStroke];
        NSBezierPath *outline=[NSBezierPath bezierPath];
        [outline moveToPoint:NSMakePoint(9,18.5)];
        [outline curveToPoint:NSMakePoint(3,10) controlPoint1:NSMakePoint(4.5,18.5) controlPoint2:NSMakePoint(3,15)];
        [outline curveToPoint:NSMakePoint(9,1.5) controlPoint1:NSMakePoint(3,4.5) controlPoint2:NSMakePoint(4.8,1.5)];
        [outline curveToPoint:NSMakePoint(15,10) controlPoint1:NSMakePoint(13.2,1.5) controlPoint2:NSMakePoint(15,4.5)];
        [outline curveToPoint:NSMakePoint(9,18.5) controlPoint1:NSMakePoint(15,15) controlPoint2:NSMakePoint(13.5,18.5)];
        [outline closePath]; outline.lineWidth=1.5; [outline stroke];
        [NSColor.blackColor setFill];
        [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(7.5,9,3,7) xRadius:1.5 yRadius:1.5] fill];
        return YES;
    }];
    icon.template=YES;
    icon.accessibilityDescription=@"MagicCenter — Magic Mouse center click";
    return icon;
}
