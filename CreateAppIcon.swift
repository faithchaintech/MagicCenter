import AppKit

func drawIcon() {
    let tile = NSBezierPath(roundedRect:NSRect(x:64,y:64,width:896,height:896), xRadius:202,yRadius:202)
    NSGraphicsContext.saveGraphicsState()
    let tileShadow=NSShadow(); tileShadow.shadowColor=NSColor.black.withAlphaComponent(0.2)
    tileShadow.shadowBlurRadius=22; tileShadow.shadowOffset=NSSize(width:0,height:-10); tileShadow.set()
    NSColor(calibratedRed:0.03,green:0.18,blue:0.21,alpha:1).setFill(); tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors:[NSColor(calibratedRed:0.03,green:0.15,blue:0.20,alpha:1), NSColor(calibratedRed:0.05,green:0.38,blue:0.41,alpha:1)])!.draw(in:tile,angle:60)
    NSColor.white.withAlphaComponent(0.16).setStroke(); tile.lineWidth=2; tile.stroke()

    let mouse=NSBezierPath()
    mouse.move(to:NSPoint(x:512,y:838))
    mouse.curve(to:NSPoint(x:326,y:516),controlPoint1:NSPoint(x:365,y:838),controlPoint2:NSPoint(x:326,y:680))
    mouse.curve(to:NSPoint(x:512,y:184),controlPoint1:NSPoint(x:326,y:302),controlPoint2:NSPoint(x:376,y:184))
    mouse.curve(to:NSPoint(x:698,y:516),controlPoint1:NSPoint(x:648,y:184),controlPoint2:NSPoint(x:698,y:302))
    mouse.curve(to:NSPoint(x:512,y:838),controlPoint1:NSPoint(x:698,y:680),controlPoint2:NSPoint(x:659,y:838))
    mouse.close()
    NSGraphicsContext.saveGraphicsState()
    let mouseShadow=NSShadow(); mouseShadow.shadowColor=NSColor.black.withAlphaComponent(0.35)
    mouseShadow.shadowBlurRadius=38; mouseShadow.shadowOffset=NSSize(width:0,height:-22); mouseShadow.set()
    NSColor.white.setFill(); mouse.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors:[NSColor(calibratedWhite:0.80,alpha:1),NSColor(calibratedWhite:0.98,alpha:1),NSColor.white])!.draw(in:mouse,angle:90)
    NSColor.white.withAlphaComponent(0.8).setStroke(); mouse.lineWidth=3; mouse.stroke()

    // The illuminated center strip connects the app icon to its menu bar symbol.
    let strip=NSBezierPath(roundedRect:NSRect(x:483,y:578,width:58,height:172),xRadius:29,yRadius:29)
    NSGraphicsContext.saveGraphicsState()
    let glow=NSShadow(); glow.shadowColor=NSColor.systemTeal.withAlphaComponent(0.35)
    glow.shadowBlurRadius=22; glow.shadowOffset = .zero; glow.set()
    NSColor.systemTeal.setFill(); strip.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors:[NSColor(calibratedRed:0.02,green:0.48,blue:0.56,alpha:1),NSColor(calibratedRed:0.10,green:0.83,blue:0.83,alpha:1)])!.draw(in:strip,angle:90)
    let highlight=NSBezierPath(roundedRect:NSRect(x:495,y:683,width:8,height:47),xRadius:4,yRadius:4)
    NSColor.white.withAlphaComponent(0.4).setFill(); highlight.fill()
}
func png(_ size:Int)->Data {
    let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep)
    let scale=NSAffineTransform(); scale.scale(by:CGFloat(size)/1024); scale.concat()
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using:.png,properties:[:])!
}
let output=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
let iconset=URL(fileURLWithPath:CommandLine.arguments[2],isDirectory:true)
try FileManager.default.createDirectory(at:iconset,withIntermediateDirectories:true)
for size in [16,32,128,256,512] {
    try png(size).write(to:iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try png(size*2).write(to:iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try png(1024).write(to:output.appendingPathComponent("MagicCenter-AppIcon.png"))
print("Created icon PNG and iconset")
