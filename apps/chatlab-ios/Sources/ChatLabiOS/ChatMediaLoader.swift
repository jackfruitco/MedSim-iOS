import Foundation
import Networking
import SwiftUI

#if canImport(UIKit)
    import UIKit
    typealias PlatformImage = UIImage
#elseif canImport(AppKit)
    import AppKit
    typealias PlatformImage = NSImage
#endif

public protocol ChatMediaLoading: Sendable {
    func loadMediaData(for media: ChatMessageMedia) async throws -> Data
}

public actor AuthenticatedChatMediaLoader: ChatMediaLoading {
    private let authLoader: AuthorizedResourceLoading
    private let session: URLSession
    private let cache = NSCache<NSString, NSData>()

    public init(authLoader: AuthorizedResourceLoading, session: URLSession = .shared) {
        self.authLoader = authLoader
        self.session = session
        cache.countLimit = 128
    }

    public func loadMediaData(for media: ChatMessageMedia) async throws -> Data {
        let cacheKey = NSString(string: media.uuid)
        if let cached = cache.object(forKey: cacheKey) {
            return Data(referencing: cached)
        }

        var lastError: Error?
        let baseURL = await authLoader.baseURL()

        for candidate in candidateURLs(for: media) {
            do {
                let data: Data
                if candidate.host == baseURL.host {
                    data = try await authLoader.loadData(
                        from: candidate,
                        accept: "image/*",
                        requiresAccountContext: true,
                    )
                } else {
                    let (responseData, response) = try await session.data(from: candidate)
                    guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                        throw URLError(.badServerResponse)
                    }
                    data = responseData
                }

                guard PlatformImage(data: data) != nil else {
                    throw URLError(.cannotDecodeContentData)
                }

                cache.setObject(data as NSData, forKey: cacheKey)
                return data
            } catch {
                lastError = error
            }
        }

        throw lastError ?? URLError(.fileDoesNotExist)
    }

    private func candidateURLs(for media: ChatMessageMedia) -> [URL] {
        var seen = Set<String>()
        return [media.thumbnailURL, media.url, media.originalURL]
            .compactMap { raw in
                guard !raw.isEmpty, seen.insert(raw).inserted else {
                    return nil
                }
                return URL(string: raw)
            }
    }
}

@MainActor
final class ChatMediaThumbnailModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(Image)
        case failed
    }

    @Published private(set) var state: State = .idle

    private let media: ChatMessageMedia
    private let loader: ChatMediaLoading
    private var task: Task<Void, Never>?

    init(media: ChatMessageMedia, loader: ChatMediaLoading) {
        self.media = media
        self.loader = loader
    }

    deinit {
        task?.cancel()
    }

    func loadIfNeeded() {
        guard case .idle = state else {
            return
        }

        state = .loading
        task = Task { [weak self, media, loader] in
            do {
                let data = try await loader.loadMediaData(for: media)
                guard !Task.isCancelled, let platformImage = PlatformImage(data: data) else {
                    return
                }
                let image = chatImage(from: platformImage)
                await MainActor.run {
                    self?.state = .loaded(image)
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                await MainActor.run {
                    self?.state = .failed
                }
            }
        }
    }
}

@MainActor
private func chatImage(from image: PlatformImage) -> Image {
    #if canImport(UIKit)
        Image(uiImage: image)
    #elseif canImport(AppKit)
        Image(nsImage: image)
    #else
        Image(systemName: "photo")
    #endif
}
