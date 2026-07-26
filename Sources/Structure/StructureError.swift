enum StructureError: Error, CustomStringConvertible {
    case sqlite(String)
    case storagePathUnavailable

    var description: String {
        switch self {
        case .sqlite(let message):
            return message
        case .storagePathUnavailable:
            return "Could not create the Structure application support folder."
        }
    }
}
