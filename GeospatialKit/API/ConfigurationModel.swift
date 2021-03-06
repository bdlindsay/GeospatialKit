/**
 Configuration for a specific instance of Geospatial
 
 - logLevel: The amount of logging to show in the console
 */
public struct ConfigurationModel {
    internal let logLevel: LogLevel
    
    public init(logLevel: LogLevel) {
        self.logLevel = logLevel
    }
}
