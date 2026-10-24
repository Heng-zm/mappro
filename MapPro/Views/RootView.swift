import SwiftUI
import UIKit

struct RootView: View {
    @StateObject private var engine = MapEngine()
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool
    @State private var showResults = false
    @State private var showDirections = false

    var body: some View {
        ZStack(alignment: .bottom) {
            MapContainerView(engine: engine)
                .ignoresSafeArea()

            topOverlay
            mapControls
            bottomCards
        }
        .background(Color.mapCanvas)
        .sheet(isPresented: $showDirections, onDismiss: {
            engine.endDirections()
        }) {
            DirectionsSheet(engine: engine, onClose: {
                showDirections = false
            })
        }
        .onAppear {
            engine.start()
        }
        .onChange(of: query) { _, newValue in
            engine.updateSearchQuery(newValue)
        }
        .onChange(of: isSearchFocused) { _, focused in
            if focused && showResults {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    showResults = false
                }
            }
        }
        .onChange(of: engine.selectedPlace?.id) { _, newValue in
            isSearchFocused = false
            if newValue != nil {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
                    showResults = false
                }
            }
        }
    }

    private var topOverlay: some View {
        VStack(spacing: 10) {
            SearchBarView(
                text: $query,
                focus: $isSearchFocused,
                isLoading: engine.isSearching,
                onSubmit: submitSearch,
                onClear: clearSearch,
                onCancel: cancelSearch
            )

            if isSearchFocused && !query.isEmpty && !engine.suggestions.isEmpty {
                SuggestionsView(suggestions: engine.suggestions, onSelect: selectSuggestion)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                CategoryChipsView(onSelect: startCategorySearch)

                if engine.showSearchArea {
                    searchAreaButton
                }
            }

            if let toast = engine.toast {
                ToastView(message: toast, onDismiss: engine.dismissToast)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if engine.isLocationDenied {
                locationBanner
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: engine.suggestions.count)
        .animation(.easeInOut(duration: 0.2), value: engine.showSearchArea)
        .animation(.easeInOut(duration: 0.2), value: engine.toast)
    }

    private var searchAreaButton: some View {
        Button {
            engine.searchHere()
        } label: {
            Label("Search this area", systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 0.5))
                .shadow(color: Color.black.opacity(0.14), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    private var locationBanner: some View {
        HStack(spacing: 9) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 13, weight: .semibold))
            Text("Location is off")
                .font(.footnote.weight(.semibold))
            Spacer(minLength: 8)
            Button("Settings") {
                openSettings()
            }
            .font(.footnote.weight(.bold))
            .foregroundStyle(AppTheme.blue)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.14), radius: 8, y: 3)
    }

    private var mapControls: some View {
        HStack {
            Spacer()
            MapControlsView(engine: engine)
                .padding(.trailing, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: showResults ? -110 : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: showResults)
    }

    private var bottomCards: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            if let place = engine.selectedPlace, !showDirections {
                PlaceCardView(
                    place: place,
                    distance: place.distanceText(from: engine.userCoordinate),
                    onClose: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            engine.clearSelection()
                        }
                    },
                    onDirections: {
                        startDirections(to: place)
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if showResults {
                ResultsPanel(
                    engine: engine,
                    onSelect: selectResult,
                    onClose: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            showResults = false
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: engine.selectedPlace?.id)
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: showResults)
    }

    // MARK: - Actions

    private func submitSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearchFocused = false
        showResults = true
        engine.search(text: trimmed)
    }

    private func selectSuggestion(_ suggestion: SearchSuggestion) {
        query = suggestion.title
        isSearchFocused = false
        engine.clearSuggestions()
        showResults = true
        engine.search(suggestion: suggestion)
    }

    private func startCategorySearch(_ category: ExploreCategory) {
        isSearchFocused = false
        query = category.title
        showResults = true
        engine.searchNearby(category)
        Haptics.tap()
    }

    private func clearSearch() {
        query = ""
        engine.cancelSearch()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showResults = false
        }
    }

    private func cancelSearch() {
        query = ""
        isSearchFocused = false
        engine.cancelSearch()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showResults = false
        }
    }

    private func selectResult(_ place: Place) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showResults = false
        }
        isSearchFocused = false
        engine.select(place: place)
    }

    private func startDirections(to place: Place) {
        Haptics.tap()
        isSearchFocused = false
        showResults = false
        engine.prepareDirections(to: place)
        showDirections = true
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
