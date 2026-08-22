public struct Card: Codable, Sendable {
    public var id: String
    public var title: String
    public var icon: Icon?
    /// Renders right-aligned in the header; also the degraded-state slot
    /// ("cached · as of Aug 20").
    public var subtitle: String?
    public var footer: String?
    /// 1 or 2 columns.
    public var span: Int
    public var blocks: [Block]

    public init(
        id: String,
        title: String,
        icon: Icon? = nil,
        subtitle: String? = nil,
        footer: String? = nil,
        span: Int = 1,
        blocks: [Block]
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
        self.footer = footer
        self.span = span
        self.blocks = blocks
    }
}
