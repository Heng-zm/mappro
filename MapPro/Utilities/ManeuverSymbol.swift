import Foundation

/// Maps MapKit step instructions to an SF Symbol maneuver icon.
enum ManeuverSymbol {
    static func symbol(for instructions: String) -> String {
        let text = instructions.lowercased()

        if text.contains("arrive") || text.contains("destination") {
            return "flag.checkered"
        }
        if text.contains("roundabout") || text.contains("rotary") {
            return "arrow.triangle.turn.up.right.circle.fill"
        }
        if text.contains("u-turn") || text.contains("uturn") {
            return "arrow.uturn.left"
        }
        if text.contains("sharp left") {
            return "arrow.turn.up.left"
        }
        if text.contains("sharp right") {
            return "arrow.turn.up.right"
        }
        if text.contains("slight left") || text.contains("keep left") || text.contains("bear left") {
            return "arrow.up.left"
        }
        if text.contains("slight right") || text.contains("keep right") || text.contains("bear right") {
            return "arrow.up.right"
        }
        if text.contains("merge") {
            return "arrow.merge"
        }
        if text.contains("ramp") || text.contains("exit") {
            return "arrow.up.right"
        }
        if text.contains("left") {
            return "arrow.turn.up.left"
        }
        if text.contains("right") {
            return "arrow.turn.up.right"
        }
        return "arrow.up"
    }
}
