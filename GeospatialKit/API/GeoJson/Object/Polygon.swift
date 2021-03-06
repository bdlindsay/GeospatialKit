internal typealias Polygon = GeoJson.Polygon

public protocol GeoJsonPolygon: GeoJsonMultiCoordinatesGeometry {
    var linearRings: [GeoJsonLineString] { get }
    var area: Double { get }
}

extension GeoJson {
    /**
     Creates a GeoJsonPolygon
     */
    public func polygon(linearRings: [GeoJsonLineString]) -> GeoJsonPolygon? {
        return Polygon(logger: logger, geodesicCalculator: geodesicCalculator, linearRings: linearRings)
    }
    
    public class Polygon: GeoJsonPolygon, Equatable {
        public let type: GeoJsonObjectType = .polygon
        public var geoJsonCoordinates: [Any] { return linearRings.map { $0.geoJsonCoordinates } }
        
        public var description: String {
            return """
            Polygon: \(
            """
            (\n\(linearRings.enumerated().map { "\($0 == 0 ? "Main Ring" : "Negative Ring \($0)") - \($1)" }.joined(separator: ",\n"))
            """
            .replacingOccurrences(of: "\n", with: "\n\t")
            )\n)
            """
        }
        
        private let logger: LoggerProtocol
        
        public let linearRings: [GeoJsonLineString]
        
        public let points: [GeoJsonPoint]
        public let boundingBox: GeoJsonBoundingBox
        public let centroid: GeodesicPoint
        
        public let area: Double
        
        internal convenience init?(logger: LoggerProtocol, geodesicCalculator: GeodesicCalculatorProtocol, coordinatesJson: [Any]) {
            guard let linearRingsJson = coordinatesJson as? [[Any]] else { logger.error("A valid Polygon must have valid coordinates"); return nil }
            
            var linearRings = [GeoJsonLineString]()
            for linearRingJson in linearRingsJson {
                if let linearRing = LineString(logger: logger, geodesicCalculator: geodesicCalculator, coordinatesJson: linearRingJson) {
                    linearRings.append(linearRing)
                } else {
                    logger.error("Invalid linear ring (LineString) in Polygon"); return nil
                }
            }
            
            self.init(logger: logger, geodesicCalculator: geodesicCalculator, linearRings: linearRings)
        }
        
        // TODO: See this helpful link for validations: https://github.com/mapbox/mapnik-vector-tile/issues/153
        // TODO: More strict additions:
        
        // TODO: Check for validity beyond geoJson specification of geometries - Perhaps this will set an isValid flag or an invalidReasonEnum on the GeoJsonObject itself rather than failing.
        
        //Checking winding order is valid
        //Checking geometry is_valid
        //Checking geometry is_simple
        //Triangle that reprojection to tile coordinates will cause winding order reversed
        //Polygon that will be reprojected into tile coordinates as a line
        //Polygon with "spike"
        //Polygon with hole that has a "spike"
        //Polygon with large number of points repeated
        //Polygon where area threshold removes geometry AFTER clipping
        //Bowtie Polygon where two points touch
        
        // Polygon with reversed winding order
        // Polygon with hole where hole has invalid winding order
        //    o  A linear ring MUST follow the right-hand rule with respect to the
        //    area it bounds, i.e., exterior rings are counterclockwise, and
        //    holes are clockwise.
        // TODO: Can run contains on all interior polygon points to be contained in the exterior polygon and NOT contains in other interior polygons.
        // Polygon where hole intersects with same point as exterior edge point
        // Polygon where hole extends past edge of polygon
        //    o  For Polygons with more than one of these rings, the first MUST be
        //    the exterior ring, and any others MUST be interior rings.  The
        //    exterior ring bounds the surface, and the interior rings (if
        //    present) bound holes within the surface.
        fileprivate init?(logger: LoggerProtocol, geodesicCalculator: GeodesicCalculatorProtocol, linearRings: [GeoJsonLineString]) {
            guard linearRings.count >= 1 else { logger.error("A valid Polygon must have at least one LinearRing"); return nil }
            
            self.logger = logger
            
            // TODO: Save up errors to present which rings were incorrect.
            for linearRing in linearRings {
                guard linearRing.points.first! == linearRing.points.last! else { logger.error("A valid Polygon LinearRing must have the first and last points equal"); return nil }
                
                guard linearRing.points.count >= 4 else { logger.error("A valid Polygon LinearRing must have at least 4 points"); return nil }
            }
            
            self.linearRings = linearRings
            
            points = linearRings.flatMap { $0.points }
            boundingBox = BoundingBox.best(linearRings.map { $0.boundingBox })!
            
            area = geodesicCalculator.area(polygonRings: linearRings)
            centroid = geodesicCalculator.centroid(polygonRings: linearRings)
        }
        
        public func distance(to point: GeodesicPoint, errorDistance: Double) -> Double { return linearRings.first!.distance(to: point, errorDistance: errorDistance) }
        
        // TODO: Need to code for overlap for errorDistance to work as intended.
        // TODO: Avoid MapKit to support service side swift.
        public func contains(_ point: GeodesicPoint, errorDistance: Double) -> Bool {
            let polygonCoordinates = linearRings.first!.points.map { $0.locationCoordinate }
            
            let polygonOverlay = MKPolygon(coordinates: polygonCoordinates, count: polygonCoordinates.count)
            
            let polygonRenderer = MKPolygonRenderer(overlay: polygonOverlay)
            
            let mapPoint: MKMapPoint = MKMapPointForCoordinate(point.locationCoordinate)
            let polygonViewPoint: CGPoint = polygonRenderer.point(for: mapPoint)
            
            guard errorDistance >= 0 else { return distance(to: point) > abs(errorDistance) && polygonRenderer.path.contains(polygonViewPoint) }

            return distance(to: point) > errorDistance ? polygonRenderer.path.contains(polygonViewPoint) : true
        }
        
        public static func == (lhs: Polygon, rhs: Polygon) -> Bool { return lhs as GeoJsonObject == rhs as GeoJsonObject }
    }
}
