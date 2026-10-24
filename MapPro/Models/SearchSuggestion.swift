import MapKit

struct SearchSuggestion: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let completion: MKLocalSearchCompletion?

    init(completion: MKLocalSearchCompletion) {
        self.title = completion.title
        self.subtitle = completion.subtitle
        self.completion = completion
        self.id = "\(completion.title)|\(completion.subtitle)"
    }

    init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
        self.completion = nil
        self.id = "\(title)|\(subtitle)"
    }
}
