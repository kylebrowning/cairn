import Foundation

public struct Point: Sendable, Equatable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Point(0, 0)
}

/// One node of the SVG tree. A single generic element case keeps the
/// serializer trivial; typed constructors below keep call sites honest.
public enum SVGNode: Sendable {
    case element(name: String, attributes: [(String, String)], children: [SVGNode])
    /// Text content of a `<text>` element (escaped at serialization).
    case textContent(String)
    /// Pre-built inner XML — used only for icon path data lifted verbatim
    /// from `design/icons/`.
    case raw(String)
}

/// A fragment of SVG — what block renderers return.
public struct SVG: Sendable {
    public var nodes: [SVGNode]

    public init(nodes: [SVGNode] = []) {
        self.nodes = nodes
    }

    public init(@SVGBuilder _ content: () -> [SVGNode]) {
        self.nodes = content()
    }

    public static let empty = SVG()

    /// Serializes with two-space indentation.
    public func serialize() -> String {
        var out = ""
        for node in nodes {
            Self.write(node, indent: 0, into: &out)
        }
        return out
    }

    static func write(_ node: SVGNode, indent: Int, into out: inout String) {
        let pad = String(repeating: "  ", count: indent)
        switch node {
        case .raw(let xml):
            out += pad + xml + "\n"
        case .textContent(let text):
            out += pad + escapeText(text) + "\n"
        case .element(let name, let attributes, let children):
            let attrs = attributes.map { " \($0.0)=\"\(escapeAttribute($0.1))\"" }.joined()
            if children.isEmpty {
                out += "\(pad)<\(name)\(attrs)/>\n"
            } else if children.count == 1, case .textContent(let text) = children[0] {
                // Keep text elements on one line — whitespace inside <text> is visible.
                out += "\(pad)<\(name)\(attrs)>\(escapeText(text))</\(name)>\n"
            } else {
                out += "\(pad)<\(name)\(attrs)>\n"
                for child in children {
                    write(child, indent: indent + 1, into: &out)
                }
                out += "\(pad)</\(name)>\n"
            }
        }
    }

    static func escapeText(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    static func escapeAttribute(_ s: String) -> String {
        escapeText(s).replacingOccurrences(of: "\"", with: "&quot;")
    }
}

@resultBuilder
public enum SVGBuilder {
    public static func buildBlock(_ parts: [SVGNode]...) -> [SVGNode] {
        parts.flatMap { $0 }
    }

    public static func buildExpression(_ node: SVGNode) -> [SVGNode] {
        [node]
    }

    public static func buildExpression(_ fragment: SVG) -> [SVGNode] {
        fragment.nodes
    }

    public static func buildExpression(_ nodes: [SVGNode]) -> [SVGNode] {
        nodes
    }

    public static func buildOptional(_ part: [SVGNode]?) -> [SVGNode] {
        part ?? []
    }

    public static func buildEither(first: [SVGNode]) -> [SVGNode] {
        first
    }

    public static func buildEither(second: [SVGNode]) -> [SVGNode] {
        second
    }

    public static func buildArray(_ parts: [[SVGNode]]) -> [SVGNode] {
        parts.flatMap { $0 }
    }
}

/// Formats a coordinate: integers stay integers, fractions keep up to 2 places.
func num(_ v: Double) -> String {
    if v == v.rounded() && abs(v) < 1e15 {
        return String(Int(v))
    }
    return String(format: "%.2f", v)
        .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
}

private func attrs(_ pairs: [(String, String?)]) -> [(String, String)] {
    pairs.compactMap { key, value in value.map { (key, $0) } }
}

// MARK: - Element constructors

public func Svg(
    x: Double? = nil, y: Double? = nil,
    width: Double, height: Double,
    viewBox: String? = nil,
    @SVGBuilder _ content: () -> [SVGNode]
) -> SVGNode {
    .element(name: "svg", attributes: attrs([
        ("xmlns", x == nil && y == nil ? "http://www.w3.org/2000/svg" : nil),
        ("x", x.map(num)), ("y", y.map(num)),
        ("width", num(width)), ("height", num(height)),
        ("viewBox", viewBox),
    ]), children: content())
}

public func Group(
    transform: String? = nil,
    fill: String? = nil,
    opacity: Double? = nil,
    class className: String? = nil,
    @SVGBuilder _ content: () -> [SVGNode]
) -> SVGNode {
    .element(name: "g", attributes: attrs([
        ("transform", transform), ("fill", fill),
        ("opacity", opacity.map(num)), ("class", className),
    ]), children: content())
}

public func Rect(
    x: Double, y: Double, width: Double, height: Double,
    rx: Double? = nil,
    fill: String? = nil,
    stroke: String? = nil, strokeWidth: Double? = nil,
    opacity: Double? = nil
) -> SVGNode {
    .element(name: "rect", attributes: attrs([
        ("x", num(x)), ("y", num(y)),
        ("width", num(width)), ("height", num(height)),
        ("rx", rx.map(num)), ("fill", fill),
        ("stroke", stroke), ("stroke-width", strokeWidth.map(num)),
        ("opacity", opacity.map(num)),
    ]), children: [])
}

public func Circle(cx: Double, cy: Double, r: Double, fill: String? = nil) -> SVGNode {
    .element(name: "circle", attributes: attrs([
        ("cx", num(cx)), ("cy", num(cy)), ("r", num(r)), ("fill", fill),
    ]), children: [])
}

public func Path(
    d: String,
    fill: String? = nil, fillOpacity: Double? = nil,
    stroke: String? = nil, strokeWidth: Double? = nil,
    strokeLinejoin: String? = nil, strokeLinecap: String? = nil
) -> SVGNode {
    .element(name: "path", attributes: attrs([
        ("d", d), ("fill", fill), ("fill-opacity", fillOpacity.map(num)),
        ("stroke", stroke), ("stroke-width", strokeWidth.map(num)),
        ("stroke-linejoin", strokeLinejoin), ("stroke-linecap", strokeLinecap),
    ]), children: [])
}

public func Line(
    x1: Double, y1: Double, x2: Double, y2: Double,
    stroke: String, strokeWidth: Double? = nil
) -> SVGNode {
    .element(name: "line", attributes: attrs([
        ("x1", num(x1)), ("y1", num(y1)), ("x2", num(x2)), ("y2", num(y2)),
        ("stroke", stroke), ("stroke-width", strokeWidth.map(num)),
    ]), children: [])
}

public enum TextAnchor: String, Sendable {
    case start, middle, end
}

public func Text(
    _ content: String,
    x: Double, y: Double,
    fontSize: Double,
    fontFamily: String,
    fontWeight: Int? = nil,
    fill: String? = nil,
    anchor: TextAnchor = .start
) -> SVGNode {
    .element(name: "text", attributes: attrs([
        ("x", num(x)), ("y", num(y)),
        ("font-size", num(fontSize)),
        ("font-family", fontFamily),
        ("font-weight", fontWeight.map(String.init)),
        ("fill", fill),
        ("text-anchor", anchor == .start ? nil : anchor.rawValue),
    ]), children: [.textContent(content)])
}

public func Use(
    href: String,
    x: Double, y: Double,
    width: Double? = nil, height: Double? = nil,
    fill: String? = nil
) -> SVGNode {
    .element(name: "use", attributes: attrs([
        ("href", href), ("x", num(x)), ("y", num(y)),
        ("width", width.map(num)), ("height", height.map(num)),
        ("fill", fill),
    ]), children: [])
}

public func Defs(@SVGBuilder _ content: () -> [SVGNode]) -> SVGNode {
    .element(name: "defs", attributes: [], children: content())
}

public func Symbol(id: String, viewBox: String, rawContent: String) -> SVGNode {
    .element(name: "symbol", attributes: [("id", id), ("viewBox", viewBox)], children: [.raw(rawContent)])
}
