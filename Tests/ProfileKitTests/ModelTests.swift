import Foundation
import Testing

@testable import ProfileKit

@Suite struct JSONValueTests {
    @Test func roundTripsEveryJSONType() throws {
        let value = JSONValue.object([
            "null": .null,
            "bool": .bool(true),
            "int": .int(42),
            "double": .double(1.5),
            "string": .string("hi"),
            "array": .array([.int(1), .string("two")]),
        ])
        let data = try JSONEncoder().encode(value)
        let back = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(back == value)
    }

    @Test func typedAccessors() {
        #expect(JSONValue.int(3).intValue == 3)
        #expect(JSONValue.double(3.0).intValue == 3)
        #expect(JSONValue.double(3.5).intValue == nil)
        #expect(JSONValue.int(3).doubleValue == 3.0)
        #expect(JSONValue.string("x").intValue == nil)
        #expect(JSONValue.bool(true).boolValue == true)
    }
}

@Suite struct PluginOptionsTests {
    @Test func defaultsAndTypedReads() {
        let options = PluginOptions([
            "top": .int(4),
            "ignore": .array([.string("HTML"), .string("CSS")]),
            "dense": .bool(true),
            "timezone": .string("America/Los_Angeles"),
        ])
        #expect(options.int("top", default: 6) == 4)
        #expect(options.int("missing", default: 6) == 6)
        #expect(options.strings("ignore") == ["HTML", "CSS"])
        #expect(options.strings("missing") == [])
        #expect(options.bool("dense", default: false))
        #expect(options.string("timezone") == "America/Los_Angeles")
    }

    @Test func decodesFromBareObject() throws {
        let data = Data(#"{"top": 6, "style": "isometric"}"#.utf8)
        let options = try JSONDecoder().decode(PluginOptions.self, from: data)
        #expect(options.int("top", default: 0) == 6)
        #expect(options.string("style") == "isometric")
    }
}

@Suite struct BlockCodableTests {
    @Test func cardRoundTrips() throws {
        let card = Card(
            id: "activity",
            title: "Activity",
            icon: .flame,
            subtitle: "cached · as of Aug 20",
            footer: "Updated daily by GitHub Actions",
            span: 2,
            blocks: [
                .stat(Stat(icon: .commit, label: "Commits", value: "13,100", dense: true)),
                .statGrid([BigStat(value: "23 days", label: "current streak", accent: true)]),
                .heatmap(Heatmap(weeks: [[0, 1, 2, 3, 4, 0, 1]], startMonth: 8)),
                .isometricHeatmap(Heatmap(weeks: [[4, 4, 4, 4, 4, 4, 4]], startMonth: 0, weekdayLabels: false)),
                .sparkline(Sparkline(values: [1, 2, 3], label: "26")),
                .barList([Bar(label: "Swift", value: "34%", raw: 34, color: "#F05138")]),
                .badgeRow([Badge(text: "swift")]),
                .text("hello"),
                .divider("popularity"),
                .divider(nil),
            ]
        )
        let data = try Snapshot.encoder().encode(card)
        let back = try Snapshot.decoder().decode(Card.self, from: data)
        #expect(back.id == card.id)
        #expect(back.span == 2)
        #expect(back.blocks.count == card.blocks.count)
        if case .stat(let stat) = back.blocks[0] {
            #expect(stat.icon == .commit)
            #expect(stat.dense)
        } else {
            Issue.record("first block should be a stat")
        }
        if case .barList(let bars) = back.blocks[5] {
            #expect(bars[0].color == "#F05138")
        } else {
            Issue.record("sixth block should be a barList")
        }
    }

    @Test func iconRawValuesMatchDesignFileNames() {
        #expect(Icon.allCases.count == 36)
        #expect(Icon.arrowUp.rawValue == "arrow-up")
        #expect(Icon.northStar.rawValue == "north-star")
    }
}
