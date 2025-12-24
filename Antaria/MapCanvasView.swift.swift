import SwiftUI
import MapKit

struct MapCanvasView: UIViewRepresentable {
    var isEditing: Bool

    @Binding var drawingPoints: [CLLocationCoordinate2D]
    var savedPolygons: [[CLLocationCoordinate2D]]

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator

        // Tap: add a point
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.onTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        tap.isEnabled = isEditing
        context.coordinator.tap = tap
        map.addGestureRecognizer(tap)

        // Pan: drag to add continuous points
        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.onPan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = false
        pan.delegate = context.coordinator
        pan.isEnabled = isEditing
        context.coordinator.pan = pan
        map.addGestureRecognizer(pan)

        // Initial location (Tokyo Station)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        map.setRegion(region, animated: false)

        // Apply initial editing state
        context.coordinator.applyEditingState(to: map, isEditing: isEditing)

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.tap?.isEnabled = isEditing
        context.coordinator.pan?.isEnabled = isEditing
        context.coordinator.applyEditingState(to: map, isEditing: isEditing)

        map.removeOverlays(map.overlays)

        // Saved polygons
        for coords in savedPolygons where coords.count >= 3 {
            map.addOverlay(MKPolygon(coordinates: coords, count: coords.count))
        }

        // Currently drawing (show polygon when 3+)
        if drawingPoints.count >= 3 {
            map.addOverlay(MKPolygon(coordinates: drawingPoints, count: drawingPoints.count))
        } else if drawingPoints.count >= 2 {
            // Optional: show a line while still < 3 points
            map.addOverlay(MKPolyline(coordinates: drawingPoints, count: drawingPoints.count))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: MapCanvasView
        var tap: UITapGestureRecognizer?
        var pan: UIPanGestureRecognizer?

        // Used to avoid adding too many points when dragging
        private var lastAdded: CLLocationCoordinate2D?

        init(_ parent: MapCanvasView) {
            self.parent = parent
        }

        func applyEditingState(to map: MKMapView, isEditing: Bool) {
            // When editing, disable map interactions so gestures become drawing gestures.
            map.isScrollEnabled = !isEditing
            map.isZoomEnabled = !isEditing
            map.isRotateEnabled = !isEditing
            map.isPitchEnabled = !isEditing
        }

        @objc func onTap(_ sender: UITapGestureRecognizer) {
            guard parent.isEditing else { return }
            guard let map = sender.view as? MKMapView else { return }
            let p = sender.location(in: map)
            let coord = map.convert(p, toCoordinateFrom: map)
            parent.drawingPoints.append(coord)
            lastAdded = coord
        }

        @objc func onPan(_ sender: UIPanGestureRecognizer) {
            guard parent.isEditing else { return }
            guard let map = sender.view as? MKMapView else { return }

            let p = sender.location(in: map)
            let coord = map.convert(p, toCoordinateFrom: map)

            switch sender.state {
            case .began:
                lastAdded = nil
                parent.drawingPoints.append(coord)
                lastAdded = coord
            case .changed:
                // Add a point only if we've moved enough (avoid thousands of points)
                if shouldAppend(coord: coord) {
                    parent.drawingPoints.append(coord)
                    lastAdded = coord
                }
            case .ended, .cancelled, .failed:
                // Final point
                if shouldAppend(coord: coord) {
                    parent.drawingPoints.append(coord)
                    lastAdded = coord
                }
            default:
                break
            }
        }

        private func shouldAppend(coord: CLLocationCoordinate2D) -> Bool {
            guard let last = lastAdded else { return true }
            let a = CLLocation(latitude: last.latitude, longitude: last.longitude)
            let b = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            // threshold in meters (tweak if needed)
            return a.distance(from: b) >= 3
        }

        // Allow drawing gestures to coexist with map's internal recognizers.
        // (We also disable map interactions during editing, but keeping this helps stability.)
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: polyline)
                r.lineWidth = 2
                r.strokeColor = UIColor.systemGreen
                return r
            }

            let r = MKPolygonRenderer(overlay: overlay)
            r.lineWidth = 2
            r.strokeColor = UIColor.systemGreen
            r.fillColor = UIColor.systemGreen.withAlphaComponent(0.2)
            return r
        }
    }
}
