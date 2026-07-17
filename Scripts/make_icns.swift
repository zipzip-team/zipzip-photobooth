import Foundation

let args = CommandLine.arguments
guard args.count == 3 else {
    fatalError("Usage: make_icns.swift input.iconset output.icns")
}

let iconset = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])

let chunks: [(String, String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

func uint32(_ value: Int) -> Data {
    var big = UInt32(value).bigEndian
    return Data(bytes: &big, count: MemoryLayout<UInt32>.size)
}

var body = Data()
for (type, filename) in chunks {
    let fileURL = iconset.appendingPathComponent(filename)
    guard let data = try? Data(contentsOf: fileURL) else {
        continue
    }
    body.append(type.data(using: .ascii)!)
    body.append(uint32(data.count + 8))
    body.append(data)
}

var file = Data()
file.append("icns".data(using: .ascii)!)
file.append(uint32(body.count + 8))
file.append(body)
try file.write(to: output)
