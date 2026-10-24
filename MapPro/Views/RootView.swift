import SwiftUI
import UIKit

struct RootView: View {
    @StateObject private var engine = MapEngine()
    @StateObject private var favorites = FavoritesStore()
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool
    @State private var showResults = false
    @State private var showDirections = false
    @State private var showSavedPlaces = false
    @State private var lookAroundPlace: Place?

    var body: some View {
        ZStack(alignment: .bottom) {
            MapContainerView(engine: engine)
                .ignoresSafeArea()

            if engine.isNavigating {
                NavigationHUD(engine: engine, onEnd: endNavigation)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                topOverlay
                mapControls
                bottomCards
            }
        }
        .background(Color.mapCanvas)
        .sheet(isPresented: $showDirections, onDismiss: {
            if !engine.isNavigating {
                engine.endDirections()
            }
        }) {
            DirectionsSheet(engine: engine, onClose: {
                showDirections = false
            })
        }
        .sheet(isPresented: $showSavedPlaces) {
            SavedPlacesPanel(
                store: favorites,
                userCoordinate: engine.userCoordinate,
                onSelect: selectSaved,
                onClose: {
                    showSavedPlaces = false
                }
            )
        }
        .fullScreenCover(item: $lookAroundPlace) { place in
            LookAroundSheet(place: place)
        }
        .onAppear {
            engine.start()
            engine.updateOfflineFavorites(favorites.places.map { $0.place })
        }
        .onChange(of: query) { _, newValue in
            engine.updateSearchQuery(newValue)
        }
        .onChange(of: favorites.places) { _, places in
            engine.updateOfflineFavorites(places.map { $0.place })
        }
        .onChange(of: engine.isNavigating) { _, navigating in
            if navigating {
                isSearchFocused = false
                showResults = false
                showSavedPlaces = false
                showDirections = false
            }
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
            HStack(alignment: .top, spacing: 10) {
                SearchBarView(
                    text: $query,
                    focus: $isSearchFocused,
                    isLoading: engine.isSearching,
                    onSubmit: submitSearch,
                    onClear: clearSearch,
                    onCancel: cancelSearch
                )

                if !isSearchFocused {
                    HeaderCompassView(engine: engine)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))

                    savedButton
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }

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

            if engine.isOffline {
                offlineBanner
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
        .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: engine.suggestions.count)
        .animation(.easeInOut(duration: 0.2), value: engine.showSearchArea)
        .animation(.easeInOut(duration: 0.2), value: engine.toast)
        .animation(.easeInOut(duration: 0.2), value: engine.isOffline)
    }

    private var offlineBanner: some View {
        HStack(spacing: 9) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.orange)

            VStack(alignment: .leading, spacing: 1) {
                Text(engine.offlineMode ? "Offline mode" : "No internet connection")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Saved and cached places still work.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(engine.offlineMode ? "Go online" : "Saved") {
                if engine.offlineMode {
                    engine.toggleOfflineMode()
                } else {
                    showSavedPlaces = true
                }
            }
            .font(.footnote.weight(.bold))
            .foregroundStyle(AppTheme.blue)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 8, y: 3)
    }

    private var savedButton: some View {
        Button {
            isSearchFocused = false
            showSavedPlaces = true
            Haptics.tap()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: favorites.isEmpty ? "bookmark" : "bookmark.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(favorites.isEmpty ? Color.primary : AppTheme.blue)
                    .frame(width: 52, height: 52)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 0.6)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 16, y: 6)

                if !favorites.isEmpty {
                    Text("\(favorites.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 17, minHeight: 17)
                        .padding(.horizontal, 2)
                        .background(AppTheme.blue, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.65), lineWidth: 1))
                        .offset(x: 5, y: -5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Saved places, \(favorites.count) saved")
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
                    isSaved: favorites.isSaved(place),
                    onClose: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            engine.clearSelection()
                        }
                    },
                    onDirections: {
                        startDirections(to: place)
                    },
                    onToggleSave: {
                        toggleSave(place)
                    },
                    onCopyCoordinates: {
                        copyCoordinates(place)
                    },
                    onLookAround: {
                        openLookAround(place)
                    },
                    onRemovePin: removePinAction(for: place)
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
        engine.clearSuggestions()

        if let coordinate = CoordinateParser.parse(trimmed) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                showResults = false
            }
            query = CoordinateParser.format(coordinate)
            engine.searchCoordinate(coordinate)
            return
        }

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

    private func selectSaved(_ saved: SavedPlace) {
        let place = saved.place
        showSavedPlaces = false
        isSearchFocused = false
        query = place.name
        engine.clearSuggestions()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showResults = false
        }

        engine.select(place: place)
    }

    private func startDirections(to place: Place) {
        Haptics.tap()
        isSearchFocused = false
        showResults = false
        engine.prepareDirections(to: place)
        showDirections = true
    }

    private func toggleSave(_ place: Place) {
        let isSaved = favorites.toggle(place)
        Haptics.tap()
        engine.showToast(isSaved ? "Saved to your places" : "Removed from saved places")
    }

    private func copyCoordinates(_ place: Place) {
        UIPasteboard.general.string = place.coordinateText
        Haptics.success()
        engine.showToast("Coordinates copied")
    }

    private func removeDroppedPin() {
        Haptics.tap()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            engine.clearDroppedPin()
        }
    }

    private func removePinAction(for place: Place) -> (() -> Void)? {
        guard place.isDroppedPin else { return nil }
        return removeDroppedPin
    }

    private func openLookAround(_ place: Place) {
        guard !engine.isOffline else {
            Haptics.warning()
            engine.showToast("Look Around needs an internet connection.")
            return
        }
        Haptics.tap()
        lookAroundPlace = place
    }

    private func endNavigation() {
        engine.stopNavigation()
        engine.endDirections()
        isSearchFocused = false
        showResults = false
        showDirections = false
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
