import MapKit
import SwiftUI

struct MapView: View {
    @ObservedObject private var spotStore = SpotStore.shared
    @State private var viewModel = MapViewModel()
    @State private var router = AppRouter.shared
    @State private var showSavedToast = false

    var body: some View {
        @Bindable var viewModel = viewModel

        ZStack(alignment: .top) {
            MapReader { proxy in
                Map(position: $viewModel.cameraPosition) {
                    UserAnnotation()

                    ForEach(visibleSpots) { spot in
                        Annotation(spot.name, coordinate: spot.coordinate, anchor: .bottom) {
                            SpotMarker {
                                viewModel.selectedSpot = spot
                            }
                        }
                    }

                    if let draft = viewModel.draftCoordinate {
                        Annotation("New Spot", coordinate: draft.coordinate, anchor: .bottom) {
                            DraftMarker()
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .simultaneousGesture(longPressGesture(proxy: proxy))
                .ignoresSafeArea(.container, edges: .bottom)
            }

            searchOverlay(query: $viewModel.searchQuery)

            if spotStore.spots.isEmpty {
                emptyHintCard
                    .padding(.horizontal, Layout.screenEdge)
                    .padding(.bottom, Spacing.xl)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.opacity)
            }
        }
        .animation(.appEaseOut, value: spotStore.spots.isEmpty)
        .sheet(item: $viewModel.selectedSpot) { spot in
            SpotDetailSheet(
                spot: spot,
                viewModel: viewModel,
                onSaved: {
                    showSavedToast = true
                },
                onDeleted: {
                    viewModel.selectedSpot = nil
                }
            )
        }
        .sheet(item: $viewModel.draftCoordinate) { draft in
            NewSpotSheet(coordinate: draft.coordinate) { name, notes in
                let spot = FishingSpot(
                    name: name,
                    coordinate: draft.coordinate,
                    notes: notes
                )
                spotStore.addSpot(spot)
                viewModel.draftCoordinate = nil
                viewModel.focus(on: spot)
            }
        }
        .task {
            _ = await LocationService.shared.requestWhenInUseAuthorization()
        }
        .onAppear { handlePendingFocus() }
        .onChange(of: router.spotToFocus) { _, _ in handlePendingFocus() }
        .onChange(of: spotStore.spots) { _, _ in handlePendingFocus() }
        .toast("Changes saved", isPresented: $showSavedToast)
    }

    /// If `AppRouter` has queued a spot to focus (e.g. from the catch detail
    /// view in another tab), zoom to it and open its detail sheet, then
    /// clear the request so it doesn't fire again.
    private func handlePendingFocus() {
        guard let id = router.spotToFocus,
              let spot = spotStore.spots.first(where: { $0.id == id })
        else { return }
        viewModel.focus(on: spot)
        viewModel.selectedSpot = spot
        router.spotToFocus = nil
    }

    // MARK: - Gestures

    /// Long-press (0.6s) followed by a zero-distance drag — the drag's
    /// `location` is a `CGPoint` that `MapReader` converts into a coordinate.
    /// `.simultaneousGesture` keeps Map's native pan/zoom intact.
    private func longPressGesture(proxy: MapProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.6)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onEnded { value in
                guard case .second(true, let drag?) = value,
                      let coordinate = proxy.convert(drag.location, from: .local)
                else { return }
                viewModel.startDraft(at: coordinate)
            }
    }

    // MARK: - Search overlay

    @ViewBuilder
    private func searchOverlay(query: Binding<String>) -> some View {
        VStack(spacing: Spacing.xs) {
            MapSearchBar(text: query)
                .padding(.horizontal, Layout.screenEdge)

            if !viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                SearchResultsList(spots: visibleSpots) { spot in
                    viewModel.focus(on: spot)
                }
                .padding(.horizontal, Layout.screenEdge)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, Spacing.xs)
        .animation(.appEaseOut, value: viewModel.searchQuery)
    }

    private var visibleSpots: [FishingSpot] {
        viewModel.filteredSpots(from: spotStore.spots)
    }

    /// Shown the first time a user opens the Map tab — coaches the
    /// long-press-to-drop-pin gesture without blocking the map.
    private var emptyHintCard: some View {
        FishCastCard {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.accentGold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Long-press to drop a pin")
                        .font(.appHeadline)
                        .foregroundStyle(Color.textPrimary)
                    Text("Save your honey holes — we'll pull live conditions for each one.")
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

#Preview {
    MapView()
}
