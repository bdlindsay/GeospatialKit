internal protocol WktParserProtocol {
    func geoJsonObject(from wkt: String) -> GeoJsonObject?
}

// TODO: Forced unwrapping leads to exceptions when WKT is invalid.
internal struct WktParser: WktParserProtocol {
    let logger: LoggerProtocol
    let geoJson: GeoJsonProtocol
    
    func geoJsonObject(from wkt: String) -> GeoJsonObject? {
        guard let startRange = wkt.range(of: "(") else { logger.error("Malformed WKT: \(wkt)"); return nil }
        guard let endRange = wkt.range(of: ")", options: .backwards) else { logger.error("Malformed WKT: \(wkt)"); return nil }
        
        let range = startRange.upperBound..<endRange.lowerBound
        let data = String(wkt[range])
        
        // TODO: Does not nearly support all of the types.
        do {
            if wkt.uppercased().hasPrefix("POINT") {
                return try parsePointString(data)
            } else if wkt.uppercased().hasPrefix("LINESTRING") {
                let lineString = wkt.wktTokens[0]
                
                return try parseLineString(lineString)
            } else if wkt.uppercased().hasPrefix("MULTILINESTRING") {
                let lineStrings = wkt.wktTokens.flatMap { $0.wktTokens }
                
                return geoJson.multiLineString(lineStrings: try lineStrings.map { try parseLineString($0) })
            } else {
                if wkt.uppercased().hasPrefix("MULTIPOLYGON") {
                    let regex = try NSRegularExpression(pattern: "(\\({2}.*?\\){2})", options: [])
                    let results = regex.matches(in: data, options: [], range: NSRange(location: 0, length: data.count))
                    let polygonStrings = results.map { result -> String in
                        let begin = data.index(data.startIndex, offsetBy: result.range.location + 1)
                        let end = data.index(data.startIndex, offsetBy: result.range.location + result.range.length - 1)
                        return String(data[begin..<end])
                    }
                    
                    return geoJson.multiPolygon(polygons: try polygonStrings.map { try parsePolygonString($0) })
                } else if wkt.uppercased().hasPrefix("POLYGON") {
                    return try parsePolygonString(data)
                } else {
                    logger.error("Unsupported Geometry type: \(wkt)")
                    
                    return nil
                }
            }
        } catch {
            logger.error("Could not parse geometry: \(wkt)")
            
            return nil
        }
    }
    
    private func parsePointString(_ data: String) throws -> GeoJsonPoint {
        let formatter = NumberFormatter.formatterForCoordinates
        
        let coordinates = data.trimmingCharacters(in: CharacterSet(charactersIn: " ")).components(separatedBy: " ")
        let longitude = formatter.number(from: coordinates[0])!.doubleValue
        let latitude = formatter.number(from: coordinates[1])!.doubleValue
        
        return geoJson.point(longitude: longitude, latitude: latitude)
    }
    
    private func parseLineString(_ data: String) throws -> GeoJsonLineString {
        let points = try data.components(separatedBy: ",").map { try parsePointString($0) }
        
        return geoJson.lineString(points: points)!
    }
    
    private func parsePolygonString(_ data: String) throws -> GeoJsonPolygon {
        let linearRings: [GeoJsonLineString] = try data.wktTokens.map { wktLinearRing in
            let wktPoints = wktLinearRing.components(separatedBy: ",")
            
            return geoJson.lineString(points: try wktPoints.map { try parsePointString($0) })!
        }
        
        return geoJson.polygon(linearRings: linearRings)!
    }
}

fileprivate extension String {
    fileprivate var wktTokens: [String] {
        var tokens = [String]()
        
        var startIndex = 0
        
        var currentTokenDepth = 0
        
        self.enumerated().forEach { currentIndex, character in
            if character == "(" {
                if currentTokenDepth == 0 {
                    startIndex = currentIndex + 1
                }
                
                currentTokenDepth += 1
            } else if character == ")" {
                if currentTokenDepth == 1 {
                    let range = self.index(self.startIndex, offsetBy: startIndex)..<self.index(self.startIndex, offsetBy: currentIndex)
                    tokens.append(String(self[range]))
                }
                
                currentTokenDepth -= 1
            }
        }
        
        return tokens
    }
}

fileprivate extension NumberFormatter {
    fileprivate static let formatterForCoordinates: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = NumberFormatter.Style.decimal
        formatter.minimumFractionDigits = 7
        formatter.maximumFractionDigits = 7
        return formatter
    }()
}
