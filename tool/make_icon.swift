// Renders the Spinfolk app icon (docs/design/project/Logo.dc.html, "App icon")
// as an opaque 1024 px PNG. Usage: swift tool/make_icon.swift <out.png>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let px = 1024
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
  CGColor(
    srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
    blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
let ctx = CGContext(
  data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
  space: CGColorSpace(name: CGColorSpace.sRGB)!,
  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!  // no alpha: App Store rule

// SVG space: 100 x 100 units, y down.
ctx.translateBy(x: 0, y: CGFloat(px))
ctx.scaleBy(x: CGFloat(px) / 100, y: -CGFloat(px) / 100)
ctx.setFillColor(rgb(0x0B1424))
ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))  // full bleed; iOS masks the corners

// Ring: 8 seats on r 36 from twelve o'clock, clockwise. Seat 1 taker, seat 5 giver.
for i in 0..<8 {
  let a = CGFloat(i) * .pi / 4
  let r: CGFloat = (i == 1 || i == 5) ? 6.2 : 4.6
  ctx.setFillColor(rgb(i == 1 ? 0x2DD4BF : (i == 5 ? 0xFF7A59 : 0x3A4D74)))
  ctx.fillEllipse(in: CGRect(x: 50 + 36 * sin(a) - r, y: 50 - 36 * cos(a) - r, width: 2 * r, height: 2 * r))
}

// Bottle: same path as bottleBodyPath() in dial_painter.dart, neck at 45 degrees.
ctx.translateBy(x: 50, y: 50)
ctx.rotate(by: .pi / 4)
ctx.scaleBy(x: 0.27, y: 0.27)
let body = CGMutablePath()
body.move(to: CGPoint(x: -8, y: -88))
body.addLine(to: CGPoint(x: 8, y: -88))
body.addLine(to: CGPoint(x: 8, y: -40))
body.addCurve(to: CGPoint(x: 22, y: 0), control1: CGPoint(x: 8, y: -24), control2: CGPoint(x: 22, y: -18))
body.addLine(to: CGPoint(x: 22, y: 72))
body.addQuadCurve(to: CGPoint(x: 10, y: 84), control: CGPoint(x: 22, y: 84))
body.addLine(to: CGPoint(x: -10, y: 84))
body.addQuadCurve(to: CGPoint(x: -22, y: 72), control: CGPoint(x: -22, y: 84))
body.addLine(to: CGPoint(x: -22, y: 0))
body.addCurve(to: CGPoint(x: -8, y: -40), control1: CGPoint(x: -22, y: -18), control2: CGPoint(x: -8, y: -24))
body.closeSubpath()
ctx.addPath(body)
ctx.setFillColor(rgb(0xE8EEF7, 0.95))
ctx.fillPath()
func pill(_ r: CGRect, _ radius: CGFloat, _ hex: UInt32) {
  ctx.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
  ctx.setFillColor(rgb(hex))
  ctx.fillPath()
}
pill(CGRect(x: -10, y: -100, width: 20, height: 12), 4, 0x2DD4BF)  // lip: taker
pill(CGRect(x: -22, y: 70, width: 44, height: 14), 6, 0xFF7A59)  // base: giver

guard CommandLine.arguments.count == 2 else { fatalError("usage: make_icon.swift <out.png>") }
let out = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
let dest = CGImageDestinationCreateWithURL(out, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("could not write PNG") }
