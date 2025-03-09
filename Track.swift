import Foundation

struct Track: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let url: URL
}
