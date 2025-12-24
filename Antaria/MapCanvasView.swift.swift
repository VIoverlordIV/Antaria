import SwiftUI
import MapKit
import CoreLocation

struct MapCanvasView: UIViewRepresentable {
    var isEditing: Bool

    @Binding var drawingPoints: [CLLocationCoordinate2D]
    var savedPolygons: [[CLLocationCoordinate2D]]

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        // Initial sync
        context.coordinator.parent = self

        // Tap: add a point
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.onTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        tap.isEnabled = isEditing
        context.coordinator.tap = tap
        map.addGestureRecognizer(tap)

        // Draw Pan: 1-finger drag to add continuous points
        let drawPan = UIPanGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.onDrawPan(_:)))
        drawPan.minimumNumberOfTouches = 1
        drawPan.maximumNumberOfTouches = 1
        drawPan.cancelsTouchesInView = true
        drawPan.delegate = context.coordinator
        drawPan.isEnabled = isEditing
        context.coordinator.drawPan = drawPan
        map.addGestureRecognizer(drawPan)

        // Move Pan (editing only): 2-finger drag to move the map while editing
        let movePan = UIPanGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.onMovePan(_:)))
        movePan.minimumNumberOfTouches = 2
        movePan.maximumNumberOfTouches = 2
        movePan.cancelsTouchesInView = false
        movePan.delegate = context.coordinator
        movePan.isEnabled = isEditing
        context.coordinator.movePan = movePan
        map.addGestureRecognizer(movePan)

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
        // Keep coordinator in sync with latest SwiftUI values (isEditing, bindings, etc.)
        context.coordinator.parent = self
        context.coordinator.tap?.isEnabled = isEditing
        context.coordinator.drawPan?.isEnabled = isEditing
        context.coordinator.movePan?.isEnabled = isEditing
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
        var drawPan: UIPanGestureRecognizer?
        var movePan: UIPanGestureRecognizer?

        // For 2-finger map move while editing
        private var movePanStartPoint: CGPoint?
        private var movePanStartCenter: CLLocationCoordinate2D?

        // Used to avoid adding too many points when dragging
        private var lastAdded: CLLocationCoordinate2D?

        init(_ parent: MapCanvasView) {
            self.parent = parent
        }

        func applyEditingState(to map: MKMapView, isEditing: Bool) {
            // While editing we want to draw with 1 finger.
            // To avoid conflicts with MKMapView's 1-finger scroll, disable scroll during editing.
            // We still allow zoom/rotate/pitch, and we provide our own 2-finger pan to move the map.
            map.isScrollEnabled = !isEditing
            map.isZoomEnabled = true
            map.isRotateEnabled = true
            map.isPitchEnabled = true
        }

        @objc func onTap(_ sender: UITapGestureRecognizer) {
            guard parent.isEditing else { return }
            guard let map = sender.view as? MKMapView else { return }
            let p = sender.location(in: map)
            let coord = map.convert(p, toCoordinateFrom: map)
            parent.drawingPoints.append(coord)
            lastAdded = coord
        }

        @objc func onDrawPan(_ sender: UIPanGestureRecognizer) {
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

        @objc func onMovePan(_ sender: UIPanGestureRecognizer) {
            guard parent.isEditing else { return }
            guard let map = sender.view as? MKMapView else { return }

            switch sender.state {
            case .began:
                movePanStartPoint = sender.location(in: map)
                movePanStartCenter = map.centerCoordinate

            case .changed:
                guard let startPoint = movePanStartPoint,
                      let startCenter = movePanStartCenter else { return }

                let currentPoint = sender.location(in: map)

                // Convert points to coordinates and compute the delta in coordinate space
                let startCoord = map.convert(startPoint, toCoordinateFrom: map)
                let currentCoord = map.convert(currentPoint, toCoordinateFrom: map)

                let dLat = startCoord.latitude - currentCoord.latitude
                let dLon = startCoord.longitude - currentCoord.longitude

                var newCenter = CLLocationCoordinate2D(
                    latitude: startCenter.latitude + dLat,
                    longitude: startCenter.longitude + dLon
                )

                // Keep longitude within [-180, 180]
                if newCenter.longitude > 180 { newCenter.longitude -= 360 }
                if newCenter.longitude < -180 { newCenter.longitude += 360 }

                map.setCenter(newCenter, animated: false)

            case .ended, .cancelled, .failed:
                movePanStartPoint = nil
                movePanStartCenter = nil

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

        // Allow our drawing gestures to coexist with the map's built-in recognizers.
        // (Map interactions stay enabled; drawing is done with 2-finger pan while editing.)
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Allow our gestures to coexist, but keep 1-finger drawing exclusive.
            if gestureRecognizer === drawPan { return false }
            return true
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
