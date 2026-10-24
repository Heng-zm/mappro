import SwiftUI

struct ExploreCategory: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let query: String
    let color: Color

    static let all: [ExploreCategory] = [
        ExploreCategory(id: "restaurants", title: "Restaurants", symbol: "fork.knife", query: "restaurants", color: AppTheme.orange),
        ExploreCategory(id: "coffee", title: "Coffee", symbol: "cup.and.saucer.fill", query: "coffee shops", color: Color(red: 0.55, green: 0.35, blue: 0.22)),
        ExploreCategory(id: "gas", title: "Gas", symbol: "fuelpump.fill", query: "gas stations", color: AppTheme.blue),
        ExploreCategory(id: "hotels", title: "Hotels", symbol: "bed.double.fill", query: "hotels", color: AppTheme.purple),
        ExploreCategory(id: "groceries", title: "Groceries", symbol: "cart.fill", query: "supermarkets", color: AppTheme.green),
        ExploreCategory(id: "pharmacy", title: "Pharmacy", symbol: "cross.case.fill", query: "pharmacy", color: AppTheme.red),
        ExploreCategory(id: "parking", title: "Parking", symbol: "parkingsign.circle.fill", query: "parking", color: AppTheme.blue),
        ExploreCategory(id: "ev", title: "EV charging", symbol: "bolt.car.fill", query: "ev charging stations", color: AppTheme.green),
        ExploreCategory(id: "bars", title: "Bars", symbol: "wineglass.fill", query: "bars", color: AppTheme.purple),
        ExploreCategory(id: "attractions", title: "Attractions", symbol: "building.columns.fill", query: "attractions", color: AppTheme.teal),
        ExploreCategory(id: "parks", title: "Parks", symbol: "leaf.fill", query: "parks", color: AppTheme.green),
        ExploreCategory(id: "shopping", title: "Shopping", symbol: "bag.fill", query: "shopping", color: AppTheme.orange)
    ]
}
