import SwiftUI

private func hslToRGB(h: Double, s: Double, l: Double) -> (Double, Double, Double) {
    let C = (1 - abs(2*l - 1)) * s
    let X = C * (1 - abs(((h/60).truncatingRemainder(dividingBy: 2)) - 1))
    let m = l - C/2
    let (r1,g1,b1):(Double,Double,Double)
    switch h {
    case 0..<60:   (r1,g1,b1) = (C,X,0)
    case 60..<120: (r1,g1,b1) = (X,C,0)
    case 120..<180:(r1,g1,b1) = (0,C,X)
    case 180..<240:(r1,g1,b1) = (0,X,C)
    case 240..<300:(r1,g1,b1) = (X,0,C)
    default:       (r1,g1,b1) = (C,0,X)
    }
    return (r1+m, g1+m, b1+m)
}

public extension Color {
    init(h: Double, s: Double, l: Double, a: Double = 1) {
        let (r,g,b) = hslToRGB(h: h, s: s/100.0, l: l/100.0)
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

public enum Theme {
    public static let background = Color(h: 0,   s: 0,  l: 0)
    public static let foreground = Color(h: 0,   s: 0,  l: 73)
    public static let muted      = Color(h: 0,   s: 12, l: 15)
    public static let mutedFg    = Color(h: 0,   s: 12, l: 65)
    public static let card       = Color(h: 0,   s: 0,  l: 0)
    public static let cardFg     = Color(h: 0,   s: 0,  l: 78)
    public static let border     = Color(h: 0,   s: 0,  l: 5)
    public static let input      = Color(h: 0,   s: 0,  l: 8)
    public static let primary    = Color(h: 220, s: 13, l: 86)
    public static let primaryFg  = Color(h: 220, s: 13, l: 26)
    public static let secondary  = Color(h: 220, s: 3,  l: 25)
    public static let secondaryFg= Color(h: 220, s: 3,  l: 85)
    public static let accent     = Color(h: 0,   s: 0,  l: 15)
    public static let accentFg   = Color(h: 0,   s: 0,  l: 75)
    public static let destructive= Color(h: 8,   s: 89, l: 47)
    public static let destructiveFg = Color(h: 0, s: 0, l: 100)
    public static let ring       = Color(h: 220, s: 13, l: 86)
}
