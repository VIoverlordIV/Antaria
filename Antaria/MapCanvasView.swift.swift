import SwiftUI
import MapKit

struct MapCanvasView: UIViewRepresentable {
    var isEditing: Bool

    @Binding var drawingPoints: [CLLocationCoordinate2D]
    var savedPolygons: [[CLLocationCoordinate2D]]

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.onTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        tap.isEnabled = isEditing
        context.coordinator.tap = tap
        map.addGestureRecognizer(tap)

        // 初始显示位置（先写东京站，之后你再改成“定位当前位置”）
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        map.setRegion(region, animated: false)

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.tap?.isEnabled = isEditing
        map.removeOverlays(map.overlays)

        // 已保存
        for coords in savedPolygons where coords.count >= 3 {
            map.addOverlay(MKPolygon(coordinates: coords, count: coords.count))
        }

        // 正在画
        if drawingPoints.count >= 3 {
            map.addOverlay(MKPolygon(coordinates: drawingPoints, count: drawingPoints.count))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: MapCanvasView
        var tap: UITapGestureRecognizer?
        init(_ parent: MapCanvasView) { self.parent = parent }

        @objc func onTap(_ sender: UITapGestureRecognizer) {
            guard parent.isEditing else { return }
            guard let map = sender.view as? MKMapView else { return }
            let p = sender.location(in: map)
            let coord = map.convert(p, toCoordinateFrom: map)
            parent.drawingPoints.append(coord)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let r = MKPolygonRenderer(overlay: overlay)
            r.lineWidth = 2
            r.strokeColor = UIColor.systemGreen
            r.fillColor = UIColor.systemGreen.withAlphaComponent(0.2)
            return r
        }
    }
}
