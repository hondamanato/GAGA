import SwiftUI
import SceneKit
import UIKit

// MARK: - Tourism sticker catalog

private let tourismStickers: [String: [(asset: String, label: String)]] = [
    "中国":           [("sticker-china", "中国")],
    "ギリシャ":       [("sticker-greece", "ギリシャ")],
    "日本":           [("sticker-japan", "日本")],
    "フランス":       [("sticker-france", "フランス")],
    "イタリア":       [("sticker-italy", "イタリア")],
    "エジプト":       [("sticker-egypt", "エジプト")],
    "オーストラリア": [("sticker-australia", "オーストラリア")],
    "メキシコ":       [("sticker-mexico", "メキシコ")],
]

// MARK: - Sticker data (persisted via UserDefaults)

struct PlacedSticker: Codable, Identifiable {
    var id: String { "\(country)_\(stickerType)" }
    let country: String
    var stickerType: String
    var x: Float, y: Float, z: Float
    var nx: Float, ny: Float, nz: Float
    var tilt: Float

    private enum CodingKeys: String, CodingKey {
        case country, stickerType, x, y, z, nx, ny, nz, tilt
    }

    init(country: String, stickerType: String = "flag",
         x: Float, y: Float, z: Float,
         nx: Float, ny: Float, nz: Float, tilt: Float) {
        self.country = country
        self.stickerType = stickerType
        self.x = x; self.y = y; self.z = z
        self.nx = nx; self.ny = ny; self.nz = nz
        self.tilt = tilt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        country = try c.decode(String.self, forKey: .country)
        stickerType = try c.decodeIfPresent(String.self, forKey: .stickerType) ?? "flag"
        x = try c.decode(Float.self, forKey: .x)
        y = try c.decode(Float.self, forKey: .y)
        z = try c.decode(Float.self, forKey: .z)
        nx = try c.decode(Float.self, forKey: .nx)
        ny = try c.decode(Float.self, forKey: .ny)
        nz = try c.decode(Float.self, forKey: .nz)
        tilt = try c.decode(Float.self, forKey: .tilt)
    }
}

private struct TraySticker: Identifiable {
    var id: String { "\(country)_\(stickerType)" }
    let country: String
    let stickerType: String
    let label: String
}

/// Legacy format (faceIndex + UV) for migration
private struct FaceUVSticker: Codable {
    let country: String
    var stickerType: String?
    var faceIndex: Int
    var u: Float, v: Float
    var tilt: Float

    func migrated(w: Float, h: Float, l: Float) -> PlacedSticker {
        let hw = w / 2, hh = h / 2, hl = l / 2
        switch faceIndex {
        case 1:  return PlacedSticker(country: country, stickerType: stickerType ?? "flag",
                     x: hw, y: -hh + v * h, z: -hl + u * l, nx: 1, ny: 0, nz: 0, tilt: tilt)
        case 2:  return PlacedSticker(country: country, stickerType: stickerType ?? "flag",
                     x: -hw + u * w, y: -hh + v * h, z: -hl, nx: 0, ny: 0, nz: -1, tilt: tilt)
        case 3:  return PlacedSticker(country: country, stickerType: stickerType ?? "flag",
                     x: -hw, y: -hh + v * h, z: -hl + u * l, nx: -1, ny: 0, nz: 0, tilt: tilt)
        case 4:  return PlacedSticker(country: country, stickerType: stickerType ?? "flag",
                     x: -hw + u * w, y: hh, z: -hl + v * l, nx: 0, ny: 1, nz: 0, tilt: tilt)
        case 5:  return PlacedSticker(country: country, stickerType: stickerType ?? "flag",
                     x: -hw + u * w, y: -hh, z: -hl + v * l, nx: 0, ny: -1, nz: 0, tilt: tilt)
        default: return PlacedSticker(country: country, stickerType: stickerType ?? "flag",
                     x: -hw + u * w, y: -hh + v * h, z: hl, nx: 0, ny: 0, nz: 1, tilt: tilt)
        }
    }
}

/// Oldest legacy format for migration
private struct LegacyPlacedSticker: Codable {
    let country: String
    var x: Float, y: Float, z: Float
    var normalX: Float, normalY: Float, normalZ: Float
    var tilt: Float

    func migrated() -> PlacedSticker {
        PlacedSticker(country: country, x: x, y: y, z: z,
                      nx: normalX, ny: normalY, nz: normalZ, tilt: tilt)
    }
}

// MARK: - Per-sticker decal projection shader (tangent-plane projection)

private let perStickerDecalShader = """
#pragma arguments
float stickerCX;
float stickerCY;
float stickerCZ;
float stickerNX;
float stickerNY;
float stickerNZ;
float stickerRadius;
float stickerTilt;

#pragma body
// Push decal slightly above the surface to prevent z-fighting
_geometry.position.xyz += normalize(_geometry.normal.xyz) * 0.005;
float3 pos = _geometry.position.xyz;
float3 center = float3(stickerCX, stickerCY, stickerCZ);
float3 toPos = pos - center;

float3 N = normalize(float3(stickerNX, stickerNY, stickerNZ));
float3 up = abs(N.y) < 0.9 ? float3(0,1,0) : float3(1,0,0);
float3 T = normalize(cross(up, N));
float3 B = cross(N, T);

float cs = cos(stickerTilt);
float sn = sin(stickerTilt);
float3 T2 = T * cs + B * sn;
float3 B2 = -T * sn + B * cs;

float3 vertNormal = normalize(_geometry.normal.xyz);
float facing = dot(vertNormal, N);
float u = dot(toPos, T2) / stickerRadius + 0.5;
float v = 0.5 - dot(toPos, B2) / stickerRadius;
float depth = dot(toPos, N);

// Pass UV for diffuse sampling, depth/facing for per-fragment rejection
_geometry.texcoords[0] = float2(u, v);
_geometry.texcoords[1] = float2(depth, facing);
"""

// MARK: - SuitcaseSceneView (UIViewRepresentable)

private struct SuitcaseSceneView: UIViewRepresentable {
    let scene: SCNScene
    let placedStickers: [PlacedSticker]
    let trayFrame: CGRect
    let onViewCreated: (SCNView) -> Void
    let onStickerSelected: (String?) -> Void
    let onStickerRepositioned: (String, SCNVector3, SCNVector3) -> Void
    let onStickerRemoved: (String) -> Void
    let onDragUpdate: (_ isDragging: Bool, _ country: String?, _ screenPos: CGPoint, _ overTray: Bool) -> Void

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = .clear

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.35
        scnView.addGestureRecognizer(longPress)

        context.coordinator.scnView = scnView
        DispatchQueue.main.async { onViewCreated(scnView) }
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        let c = context.coordinator
        c.placedStickers = placedStickers
        c.trayFrame = trayFrame
        c.onStickerSelected = onStickerSelected
        c.onStickerRepositioned = onStickerRepositioned
        c.onStickerRemoved = onStickerRemoved
        c.onDragUpdate = onDragUpdate
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        weak var scnView: SCNView?
        var placedStickers: [PlacedSticker] = []
        var trayFrame: CGRect = .zero
        var onStickerSelected: (String?) -> Void = { _ in }
        var onStickerRepositioned: (String, SCNVector3, SCNVector3) -> Void = { _, _, _ in }
        var onStickerRemoved: (String) -> Void = { _ in }
        var onDragUpdate: (Bool, String?, CGPoint, Bool) -> Void = { _, _, _, _ in }

        private var draggedCountry: String?

        private func distance3D(_ a: SCNVector3, _ b: SCNVector3) -> Float {
            let dx = a.x - b.x, dy = a.y - b.y, dz = a.z - b.z
            return sqrt(dx*dx + dy*dy + dz*dz)
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard let scnView else { return }
            let point = gesture.location(in: scnView)

            switch gesture.state {
            case .began:
                let hits = scnView.hitTest(point, options: [
                    .searchMode: NSNumber(value: SCNHitTestSearchMode.all.rawValue)
                ])
                guard let hit = hits.first(where: { $0.node.name != "stickerDecal" }) else { return }
                let hitPos = hit.worldCoordinates

                let threshold3D: Float = 0.6
                let found = placedStickers.min(by: {
                    distance3D(SCNVector3($0.x, $0.y, $0.z), hitPos) <
                    distance3D(SCNVector3($1.x, $1.y, $1.z), hitPos)
                })

                if let sticker = found,
                   distance3D(SCNVector3(sticker.x, sticker.y, sticker.z), hitPos) < threshold3D {
                    draggedCountry = sticker.id
                    scnView.allowsCameraControl = false
                    onStickerSelected(sticker.id)

                    let screenPt = scnView.convert(point, to: nil)
                    onDragUpdate(true, sticker.id, screenPt, false)

                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }

            case .changed:
                guard let stickerID = draggedCountry else { return }
                let screenPt = scnView.convert(point, to: nil)
                let overTray = trayFrame.contains(screenPt)
                onDragUpdate(true, stickerID, screenPt, overTray)

            case .ended, .cancelled:
                guard let stickerID = draggedCountry else { return }
                let screenPt = scnView.convert(point, to: nil)

                if trayFrame.contains(screenPt) {
                    onStickerRemoved(stickerID)
                } else {
                    let hits = scnView.hitTest(point, options: [
                        .searchMode: NSNumber(value: SCNHitTestSearchMode.all.rawValue)
                    ])
                    if let hit = hits.first(where: { $0.node.name != "stickerDecal" }) {
                        onStickerRepositioned(stickerID, hit.worldCoordinates, hit.worldNormal)
                    }
                }

                draggedCountry = nil
                scnView.allowsCameraControl = true
                onStickerSelected(nil)
                onDragUpdate(false, nil, .zero, false)

            default:
                break
            }
        }
    }
}

// MARK: - SuitcaseView

struct SuitcaseView: View {
    let visitedCountries: [String]
    let userId: String
    var readOnly: Bool = false

    @State private var placedStickers: [PlacedSticker] = []
    @State private var scene: SCNScene = SCNScene()
    @State private var scnViewRef: SCNView?
    @State private var shellGeometry: SCNGeometry?
    @State private var decalNodes: [String: SCNNode] = [:]

    // Drag from tray → suitcase
    @State private var isDroppingOnSuitcase = false
    @State private var isDroppingOnTray = false

    // Long-press drag from suitcase
    @State private var selectedStickerID: String?
    @State private var isDraggingFromSuitcase = false
    @State private var draggedStickerID: String?
    @State private var dragScreenPosition: CGPoint = .zero
    @State private var isHoveringTray = false

    // Model dimensions (updated after USDZ load)
    @State private var boxDims: (w: Float, h: Float, l: Float) = (1.8, 2.8, 0.9)

    // Layout frames for coordinate conversion
    @State private var trayGlobalFrame: CGRect = .zero
    @State private var rootGlobalFrame: CGRect = .zero

    private var uniqueCountries: [String] {
        var seen = Set<String>()
        return visitedCountries.compactMap { c in
            let t = c.trimmingCharacters(in: .whitespaces)
            return !t.isEmpty && seen.insert(t).inserted ? t : nil
        }
    }

    private var trayItems: [TraySticker] {
        uniqueCountries.flatMap { country -> [TraySticker] in
            var items = [TraySticker(country: country, stickerType: "flag", label: country)]
            if let extras = tourismStickers[country] {
                items += extras.map { TraySticker(country: country, stickerType: $0.asset, label: $0.label) }
            }
            return items
        }
    }

    private func parseStickerID(_ id: String) -> (country: String, stickerType: String) {
        if let range = id.range(of: "_", options: .backwards) {
            let country = String(id[..<range.lowerBound])
            let type = String(id[range.upperBound...])
            if !type.isEmpty { return (country, type) }
        }
        return (id, "flag")
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                SuitcaseSceneView(
                    scene: scene,
                    placedStickers: placedStickers,
                    trayFrame: trayGlobalFrame,
                    onViewCreated: { scnViewRef = $0 },
                    onStickerSelected: { stickerID in
                        selectedStickerID = stickerID
                        rebuildDecalNodes()
                    },
                    onStickerRepositioned: { stickerID, pos, normal in
                        repositionSticker(stickerID: stickerID, pos: pos, normal: normal)
                    },
                    onStickerRemoved: { removeSticker(stickerID: $0) },
                    onDragUpdate: { isDragging, stickerID, pos, overTray in
                        isDraggingFromSuitcase = isDragging
                        draggedStickerID = stickerID
                        dragScreenPosition = pos
                        isHoveringTray = overTray
                    }
                )
                .frame(height: 420)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(GAGATheme.coral, lineWidth: 2)
                        .opacity(isDroppingOnSuitcase ? 1 : 0)
                        .padding(4)
                )
                .overlay(alignment: .bottom) {
                    if !readOnly {
                        stickerTray
                            .padding(.bottom, 12)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear { trayGlobalFrame = geo.frame(in: .global) }
                                        .onChange(of: geo.size) { _, _ in
                                            trayGlobalFrame = geo.frame(in: .global)
                                        }
                                }
                            )
                    }
                }
                .dropDestination(for: String.self) { items, location in
                    guard !readOnly, let stickerID = items.first else { return false }
                    if placedStickers.contains(where: { $0.id == stickerID }) { return false }
                    let parsed = parseStickerID(stickerID)
                    guard uniqueCountries.contains(parsed.country) else { return false }
                    if let scnView = scnViewRef {
                        let hits = scnView.hitTest(location, options: [
                            .searchMode: SCNHitTestSearchMode.closest.rawValue
                        ])
                        if let hit = hits.first(where: { $0.node.name != "stickerDecal" }) {
                            placeStickerAtPosition(
                                stickerID: stickerID,
                                position: hit.worldCoordinates,
                                normal: hit.worldNormal
                            )
                            return true
                        }
                    }
                    placeStickerRandom(stickerID: stickerID)
                    return true
                } isTargeted: { targeted in
                    isDroppingOnSuitcase = targeted
                }
            }

        }
        .background(
            GeometryReader { geo in
                Color.clear.onAppear { rootGlobalFrame = geo.frame(in: .global) }
            }
        )
        .onAppear {
            buildScene()
            loadStickers()
        }
    }

    // MARK: - Sticker tray

    private var stickerTray: some View {
        Group {
            if uniqueCountries.isEmpty {
                Text("旅行をするとステッカーが貰えます")
                    .font(GAGATheme.captionFont)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(trayItems.filter { item in
                            !placedStickers.contains { $0.id == item.id }
                        }) { item in
                            stickerCell(item: item)
                                .onTapGesture {
                                    placeStickerRandom(stickerID: item.id)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                                .draggable(item.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            Capsule()
                .stroke((isDroppingOnTray || isHoveringTray) ? GAGATheme.coral : Color.white.opacity(0.1), lineWidth: 1)
        )
        .dropDestination(for: String.self) { items, _ in
            guard let stickerID = items.first else { return false }
            if placedStickers.contains(where: { $0.id == stickerID }) {
                removeSticker(stickerID: stickerID)
                return true
            }
            return false
        } isTargeted: { targeted in
            isDroppingOnTray = targeted
        }
    }

    private func stickerCell(item: TraySticker) -> some View {
        Group {
            if item.stickerType == "flag" {
                Text(flagEmoji(for: item.country))
                    .font(.system(size: 32))
            } else {
                Image(item.stickerType)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
            }
        }
    }

    // MARK: - Place / Reposition / Remove

    private func placeStickerAtPosition(stickerID: String, position: SCNVector3, normal: SCNVector3) {
        let parsed = parseStickerID(stickerID)
        let n = simd_normalize(SIMD3<Float>(normal.x, normal.y, normal.z))
        let sticker = PlacedSticker(
            country: parsed.country, stickerType: parsed.stickerType,
            x: position.x, y: position.y, z: position.z,
            nx: n.x, ny: n.y, nz: n.z,
            tilt: Float.random(in: -0.15...0.15)
        )
        placedStickers.append(sticker)
        saveStickers()
        rebuildDecalNodes()
    }

    private func placeStickerRandom(stickerID: String) {
        let parsed = parseStickerID(stickerID)
        let hw = boxDims.w / 2, hh = boxDims.h / 2, hl = boxDims.l / 2
        let face = Int.random(in: 0...3)
        let x: Float, y: Float, z: Float, nx: Float, ny: Float, nz: Float
        switch face {
        case 0:
            x = Float.random(in: -hw * 0.7...hw * 0.7)
            y = Float.random(in: -hh * 0.5...hh * 0.5)
            z = hl; nx = 0; ny = 0; nz = 1
        case 1:
            x = hw; nx = 1; ny = 0; nz = 0
            y = Float.random(in: -hh * 0.5...hh * 0.5)
            z = Float.random(in: -hl * 0.7...hl * 0.7)
        case 2:
            x = Float.random(in: -hw * 0.7...hw * 0.7)
            y = Float.random(in: -hh * 0.5...hh * 0.5)
            z = -hl; nx = 0; ny = 0; nz = -1
        default:
            x = -hw; nx = -1; ny = 0; nz = 0
            y = Float.random(in: -hh * 0.5...hh * 0.5)
            z = Float.random(in: -hl * 0.7...hl * 0.7)
        }
        let sticker = PlacedSticker(
            country: parsed.country, stickerType: parsed.stickerType,
            x: x, y: y, z: z, nx: nx, ny: ny, nz: nz,
            tilt: Float.random(in: -0.15...0.15)
        )
        placedStickers.append(sticker)
        saveStickers()
        rebuildDecalNodes()
    }

    private func repositionSticker(stickerID: String, pos: SCNVector3, normal: SCNVector3) {
        guard let idx = placedStickers.firstIndex(where: { $0.id == stickerID }) else { return }
        let old = placedStickers[idx]
        placedStickers[idx] = PlacedSticker(
            country: old.country, stickerType: old.stickerType,
            x: pos.x, y: pos.y, z: pos.z,
            nx: normal.x, ny: normal.y, nz: normal.z,
            tilt: old.tilt
        )
        saveStickers()
        rebuildDecalNodes()
    }

    private func removeSticker(stickerID: String) {
        placedStickers.removeAll { $0.id == stickerID }
        saveStickers()
        rebuildDecalNodes()
    }

    // MARK: - Scene building

    private func buildScene() {
        scene.background.contents = CGColor(gray: 0, alpha: 0)

        // --- 1. Load USDZ model ---
        let usdzContainer = SCNNode()
        usdzContainer.name = "usdzContainer"
        if let url = Bundle.main.url(forResource: "TRAVEL_SUITCASE", withExtension: "usdz"),
           let usdzScene = try? SCNScene(url: url) {
            let modelNode = SCNNode()
            for child in usdzScene.rootNode.childNodes {
                modelNode.addChildNode(child)
            }
            let (minB, maxB) = modelNode.boundingBox
            let mw = maxB.x - minB.x, mh = maxB.y - minB.y, ml = maxB.z - minB.z
            let cx = (minB.x + maxB.x) / 2, cy = (minB.y + maxB.y) / 2, cz = (minB.z + maxB.z) / 2

            let targetH: Float = 2.8
            let s = targetH / max(mw, mh, ml)
            modelNode.scale = SCNVector3(s, s, s)
            modelNode.position = SCNVector3(-cx * s, -cy * s, -cz * s)

            usdzContainer.addChildNode(modelNode)
            boxDims = (mw * s, mh * s, ml * s)
        }
        scene.rootNode.addChildNode(usdzContainer)

        // --- 2. Extract shell geometry for per-sticker decal nodes ---
        let shell = usdzContainer.flattenedClone()
        shellGeometry = shell.geometry

        // --- 3. Camera ---
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0.4, 5.0)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)

        // --- 4. Lighting (3-point) ---
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 350
        scene.rootNode.addChildNode(ambient)

        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 800
        keyLight.light?.castsShadow = true
        keyLight.light?.shadowRadius = 3.0
        keyLight.position = SCNVector3(2, 4, 5)
        keyLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 300
        fillLight.position = SCNVector3(-3, 1, -2)
        fillLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(fillLight)

        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .directional
        rimLight.light?.intensity = 400
        rimLight.position = SCNVector3(0, 2, -5)
        rimLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(rimLight)
    }

    // MARK: - Per-sticker decal rendering

    private let stickerRadius: Float = 0.4

    private func renderStickerTexture(sticker: PlacedSticker, selected: Bool) -> UIImage {
        let size: CGFloat = 256
        let padding: CGFloat = 16
        let drawSize = size - padding * 2

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        return renderer.image { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: size, height: size)))

            let center = size / 2
            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: center, y: center)

            if sticker.stickerType == "flag" {
                let flag = flagEmoji(for: sticker.country)
                guard !flag.isEmpty else { ctx.cgContext.restoreGState(); return }
                let text = flag as NSString
                let fontSize = drawSize * 0.7
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: fontSize)]
                let textSize = text.size(withAttributes: attrs)
                text.draw(at: CGPoint(x: -textSize.width / 2, y: -textSize.height / 2),
                          withAttributes: attrs)
            } else if let image = UIImage(named: sticker.stickerType) {
                let rect = CGRect(x: -drawSize / 2, y: -drawSize / 2,
                                  width: drawSize, height: drawSize)
                image.draw(in: rect)
            }


            ctx.cgContext.restoreGState()
        }
    }

    private func rebuildDecalNodes() {
        print("🔄 [SuitcaseView] rebuildDecalNodes called, stickers: \(placedStickers.count), shellGeometry: \(shellGeometry != nil ? "✅" : "nil")")
        // shellGeometry may be nil if @State wasn't committed yet (e.g. during .onAppear).
        // Fall back to recomputing from the scene graph.
        if shellGeometry == nil,
           let container = scene.rootNode.childNode(withName: "usdzContainer", recursively: false) {
            shellGeometry = container.flattenedClone().geometry
            print("🔄 [SuitcaseView] Recomputed shellGeometry from scene: \(shellGeometry != nil ? "✅" : "❌ still nil")")
        }
        guard let baseGeometry = shellGeometry else {
            print("❌ [SuitcaseView] shellGeometry is nil, skipping decal rendering")
            return
        }

        // Remove nodes for stickers that no longer exist
        let currentIDs = Set(placedStickers.map(\.id))
        for (id, node) in decalNodes where !currentIDs.contains(id) {
            node.removeFromParentNode()
            decalNodes.removeValue(forKey: id)
        }

        // Add/update nodes for each sticker
        for (index, sticker) in placedStickers.enumerated() {
            let node: SCNNode
            if let existing = decalNodes[sticker.id] {
                node = existing
            } else {
                let geoCopy = baseGeometry.copy() as! SCNGeometry
                node = SCNNode(geometry: geoCopy)
                node.name = "stickerDecal"
                scene.rootNode.addChildNode(node)
                decalNodes[sticker.id] = node
            }

            let mat = SCNMaterial()
            mat.diffuse.contents = renderStickerTexture(sticker: sticker,
                                                         selected: sticker.id == selectedStickerID)
            mat.diffuse.wrapS = .clamp
            mat.diffuse.wrapT = .clamp
            mat.transparencyMode = .aOne
            mat.blendMode = .alpha
            mat.writesToDepthBuffer = true
            mat.readsFromDepthBuffer = true
            mat.isDoubleSided = false
            mat.lightingModel = .constant
            mat.ambient.contents = UIColor.white
            mat.ambient.mappingChannel = 1
            mat.shaderModifiers = [
                .geometry: perStickerDecalShader,
                .surface: """
                    #pragma body
                    float2 uv = _surface.diffuseTexcoord;
                    float2 info = _surface.ambientTexcoord;
                    float depth = info.x;
                    float facing = info.y;
                    if (facing < 0.15 || abs(depth) > 0.15 ||
                        uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0 ||
                        _surface.diffuse.a < 0.5) {
                        discard_fragment();
                    }
                """
            ]

            mat.setValue(NSNumber(value: sticker.x), forKey: "stickerCX")
            mat.setValue(NSNumber(value: sticker.y), forKey: "stickerCY")
            mat.setValue(NSNumber(value: sticker.z), forKey: "stickerCZ")
            mat.setValue(NSNumber(value: sticker.nx), forKey: "stickerNX")
            mat.setValue(NSNumber(value: sticker.ny), forKey: "stickerNY")
            mat.setValue(NSNumber(value: sticker.nz), forKey: "stickerNZ")
            mat.setValue(NSNumber(value: stickerRadius), forKey: "stickerRadius")
            mat.setValue(NSNumber(value: sticker.tilt), forKey: "stickerTilt")

            if let geo = node.geometry {
                geo.materials = Array(repeating: mat, count: max(1, geo.elements.count))
            }
            node.renderingOrder = 100 + index
        }
    }

    // MARK: - Persistence (Firestore)

    private let userService = UserService()

    private func saveStickers() {
        Task {
            try? await userService.saveStickers(placedStickers, userId: userId)
        }
    }

    private func loadStickers() {
        Task {
            do {
                let stickers = try await userService.fetchStickers(userId: userId)
                placedStickers = stickers
                rebuildDecalNodes()
            } catch {
                print("[SuitcaseView] Failed to load stickers: \(error)")
            }
        }
    }
}
