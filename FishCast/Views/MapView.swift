import MapKit
import SwiftUI

struct MapView: View {
    @ObservedObject private var spotStore = SpotStore.shared
    @State private var viewModel = MapViewModel()

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
        }
        .sheet(item: $viewModel.selectedSpot) { spot in
            SpotDetailSheet(spot: spot, viewModel: viewModel)
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
}

#Preview {
    MapView()
}
