//
//  GeoCodec.swift.swift
//  Antaria
//
//  Created by cmStudent on 2025/12/24.
//

import Foundation
import CoreLocation

struct CodCoord: Codable {
    var lat: Double
    var lon: Double
}

enum GeoCodec {
    static func encode(_ coords: [CLLocationCoordinate2D]) throws -> Data {
        let arr = coords.map { CodCoord(lat: $0.latitude, lon: $0.longitude) }
        return try JSONEncoder().encode(arr)
    }

    static func decode(_ data: Data) throws -> [CLLocationCoordinate2D] {
        let arr = try JSONDecoder().decode([CodCoord].self, from: data)
        return arr.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }
}
