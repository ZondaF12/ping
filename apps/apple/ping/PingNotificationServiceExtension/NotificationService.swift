import UserNotifications

/// Downloads `image_url` from the push payload and attaches it so the system banner
class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        guard
            let urlString = bestAttemptContent.userInfo["image_url"] as? String,
            !urlString.isEmpty,
            let imageURL = URL(string: urlString)
        else {
            contentHandler(bestAttemptContent)
            return
        }

        downloadAttachment(from: imageURL) { attachment in
            if let attachment {
                bestAttemptContent.attachments = [attachment]
            }
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    private func downloadAttachment(
        from url: URL,
        completion: @escaping (UNNotificationAttachment?) -> Void
    ) {
        let task = URLSession.shared.downloadTask(with: url) { localURL, _, _ in
            guard let localURL else {
                completion(nil)
                return
            }
            let ext: String = {
                let p = url.pathExtension.lowercased()
                if !p.isEmpty, p.count <= 5 { return p }
                return "jpg"
            }()
            let dest = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            try? FileManager.default.removeItem(at: dest)
            do {
                try FileManager.default.moveItem(at: localURL, to: dest)
                let attachment = try UNNotificationAttachment(
                    identifier: "image",
                    url: dest,
                    options: nil
                )
                completion(attachment)
            } catch {
                completion(nil)
            }
        }
        task.resume()
    }
}
