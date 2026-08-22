/// The icon set. Cases are exactly the file names in `design/icons/` —
/// Octicons re-exported by the design system; the renderer inlines each used
/// icon once as a `<symbol>`.
public enum Icon: String, Codable, Sendable, CaseIterable {
    case arrowDown = "arrow-down"
    case arrowUp = "arrow-up"
    case calendar
    case chart
    case check
    case clock
    case comment
    case commit
    case database
    case eye
    case flame
    case fork
    case globe
    case heart
    case history
    case issue
    case language
    case link
    case lock
    case merge
    case music
    case northStar = "north-star"
    case organization
    case package
    case people
    case pr
    case repo
    case rocket
    case sparkle
    case star
    case tag
    case terminal
    case trophy
    case verified
    case x
    case zap
}
