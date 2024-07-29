@preconcurrency
import Vapor

func getDocumentsDirectory() -> URL {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
}

func routes(_ app: Application) throws {
    let k = getDocumentsDirectory()
    print("Home Directory: \(k)")

    app.webSocket { _, ws in
        ws.onText { _, text in
            guard let data = text.data(using: .utf8) else { return }

            FileManager.default.createFile(
                atPath: k.appendingPathComponent("/shader.metal").path,
                contents: data,
                attributes: nil
            )

            do {
                try shell([
                    "-sdk",
                    "macosx",
                    "metal",
                    "-c",
                    "-o",
                    "shader.ir",
                    "shader.metal"
                ])

                try shell([
                    "-sdk",
                    "macosx",
                    "metallib",
                    "-o",
                    "shader.metallib",
                    "shader.ir"
                ])

                let url = k.appendingPathComponent("/shader.metallib")
                if let data = try? Data(contentsOf: url) {
                    ws.send(data)
                }
            }
            catch {
                ws.send("Error: \(error)")
            }
        }
    }

    @Sendable func shell(_ args: [String]) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        task.currentDirectoryURL = k
        task.arguments = args
        try task.run()
        task.waitUntilExit()
    }
}
