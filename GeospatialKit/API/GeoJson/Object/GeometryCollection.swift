internal typealias GeometryCollection = GeoJson.GeometryCollection

public protocol GeoJsonGeometryCollection: GeoJsonGeometry { }

extension GeoJson {
    /**
     Creates a GeoJsonGeometryCollection
     */
    public func geometryCollection(geometries: [GeoJsonGeometry]?) -> GeoJsonGeometryCollection {
        return GeometryCollection(logger: logger, geometries: geometries)
    }
    
    public class GeometryCollection: GeoJsonGeometryCollection, Equatable {
        public let type: GeoJsonObjectType = .geometryCollection
        public var geoJson: GeoJsonDictionary { return ["type": type.rawValue, "geometries": objectGeometries?.map { $0.geoJson } ?? [] ] }
        
        public var description: String {
            return """
            GeometryCollection: \(
            """
            (\n\(objectGeometries != nil ? objectGeometries!.enumerated().map { "Line \($0) - \($1)" }.joined(separator: ",\n") : "null")
            """
            .replacingOccurrences(of: "\n", with: "\n\t")
            )\n)
            """
        }
        
        private let logger: LoggerProtocol
        
        public let objectGeometries: [GeoJsonGeometry]?
        public let objectBoundingBox: GeoJsonBoundingBox?
        
        internal convenience init?(logger: LoggerProtocol, geoJsonParser: GeoJsonParserProtocol, geoJsonDictionary: GeoJsonDictionary) {
            guard let geometriesJson = geoJsonDictionary["geometries"] as? [GeoJsonDictionary] else { logger.error("A valid GeometryCollection must have a \"geometries\" key: String : \(geoJsonDictionary)"); return nil }
            
            var geometries = [GeoJsonGeometry]()
            for geometryJson in geometriesJson {
                guard let geometry = geoJsonParser.geoJsonObject(from: geometryJson) as? GeoJsonGeometry else { logger.error("Invalid Geometry for GeometryCollection"); return nil }
                
                geometries.append(geometry)
            }
            
            self.init(logger: logger, geometries: geometries)
        }
        
        fileprivate init(logger: LoggerProtocol, geometries: [GeoJsonGeometry]?) {
            self.logger = logger
            
            self.objectGeometries = geometries
            
            objectBoundingBox = BoundingBox.best(geometries?.flatMap { $0.objectBoundingBox } ?? [])
        }
        
        public func objectDistance(to point: GeodesicPoint, errorDistance: Double) -> Double? { return objectGeometries?.flatMap { $0.objectDistance(to: point, errorDistance: errorDistance) }.min() }
        
        public func contains(_ point: GeodesicPoint, errorDistance: Double) -> Bool { return objectGeometries?.first { $0.contains(point, errorDistance: errorDistance) } != nil }
        
        public static func == (lhs: GeometryCollection, rhs: GeometryCollection) -> Bool { return lhs as GeoJsonObject == rhs as GeoJsonObject }
    }
}
