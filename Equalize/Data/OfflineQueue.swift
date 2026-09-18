import Foundation
import SwiftData

@Model
final class QueuedUpload {
    var id: UUID
    var lessonId: String
    var localFileURL: URL
    var courseId: String
    var title: String
    var sourceType: String
    var fileExtension: String
    var slidePhotoLocalURLs: [URL]
    var createdAt: Date
    var uploaded: Bool

    init(lessonId: String, localFileURL: URL, courseId: String, title: String, sourceType: String,
         fileExtension: String, slidePhotoLocalURLs: [URL] = []) {
        self.id = UUID()
        self.lessonId = lessonId
        self.localFileURL = localFileURL
        self.courseId = courseId
        self.title = title
        self.sourceType = sourceType
        self.fileExtension = fileExtension
        self.slidePhotoLocalURLs = slidePhotoLocalURLs
        self.createdAt = .now
        self.uploaded = false
    }
}
