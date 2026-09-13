import AppKit
let w=660, h=400
let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:w,pixelsHigh:h,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
NSGradient(colors:[NSColor(calibratedRed:0.94,green:0.97,blue:0.97,alpha:1),NSColor.white])!.draw(in:NSRect(x:0,y:0,width:w,height:h),angle:90)
func centered(_ text:String,y:CGFloat,font:NSFont,color:NSColor) {
 let attrs:[NSAttributedString.Key:Any]=[.font:font,.foregroundColor:color]
 let size=(text as NSString).size(withAttributes:attrs)
 (text as NSString).draw(at:NSPoint(x:(660-size.width)/2,y:y),withAttributes:attrs)
}
centered("One more click for your Magic Mouse.",y:329,font:.systemFont(ofSize:23,weight:.semibold),color:NSColor(calibratedWhite:0.15,alpha:1))
centered("Drag MagicCenter to Applications",y:295,font:.systemFont(ofSize:14,weight:.regular),color:NSColor(calibratedWhite:0.45,alpha:1))
let arrow=NSBezierPath(); arrow.move(to:NSPoint(x:274,y:203)); arrow.line(to:NSPoint(x:383,y:203)); arrow.move(to:NSPoint(x:372,y:214)); arrow.line(to:NSPoint(x:383,y:203)); arrow.line(to:NSPoint(x:372,y:192)); arrow.lineWidth=3; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
NSColor(calibratedRed:0.23,green:0.55,blue:0.57,alpha:1).setStroke(); arrow.stroke()
centered("Open the app, then enable Accessibility when asked.",y:51,font:.systemFont(ofSize:12,weight:.regular),color:NSColor(calibratedWhite:0.45,alpha:1))
centered("MAGICCENTER",y:25,font:.systemFont(ofSize:10,weight:.medium),color:NSColor(calibratedRed:0.30,green:0.55,blue:0.57,alpha:1))
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
