import Foundation

public class SharingServerHandler {
    public static let shared = SharingServerHandler()

    public struct PodcastList: Decodable {
        public let title: String?
        public let listDescription: String?
        public let podcasts: [ListPodcast]?

        public enum CodingKeys: String, CodingKey {
            case title, podcasts
            case listDescription = "description"
        }
    }

    public struct ListPodcast: Decodable {
        public let title: String?
        public let uuid: String?
        public let podcastDescription: String?
        public let author: String?
        public let iTunesId: Int?

        public enum CodingKeys: String, CodingKey {
            case title, uuid, author
            case podcastDescription = "description"
            case iTunesId = "collection_id"
        }
    }

    public func loadList(listUrl: URL, completion: @escaping (_ podcastList: PodcastList?) -> Void) {
        URLSession.shared.dataTask(with: listUrl) { data, response, error in
            guard (response as? HTTPURLResponse)?.statusCode == ServerConstants.HttpConstants.ok, let data, error == nil else {
                completion(nil)

                return
            }

            do {
                let podcastList = try JSONDecoder().decode(PodcastList.self, from: data)
                completion(podcastList)
            } catch {
                completion(nil)
            }
        }.resume()
    }
}
