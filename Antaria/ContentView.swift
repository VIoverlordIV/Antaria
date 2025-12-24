import SwiftUI
import CoreData
import CoreLocation

struct ContentView: View {
    @State private var isEditing = false
    @State private var showDeleteAllConfirm = false
    
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(sortDescriptors: [SortDescriptor(\Region.createdAt, order: .reverse)])
    private var regions: FetchedResults<Region>

    @State private var drawingPoints: [CLLocationCoordinate2D] = []

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 12) {
                    MapCanvasView(
                        isEditing: isEditing,
                        drawingPoints: $drawingPoints,
                        savedPolygons: loadSavedPolygons()
                    )
                    .ignoresSafeArea(edges: .top)

                    if isEditing {
                        HStack {
                            Button("撤销") {
                                if !drawingPoints.isEmpty { drawingPoints.removeLast() }
                            }
                            .buttonStyle(.bordered)

                            Button("清空点") { drawingPoints.removeAll() }
                                .buttonStyle(.bordered)

                            Button("保存范围") { saveCurrentPolygon() }
                                .buttonStyle(.borderedProminent)
                                .disabled(drawingPoints.count < 3)

                            Button("完成") {
                                isEditing = false
                                drawingPoints.removeAll()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    }
                }

                // 🖊 画笔按钮：只有未编辑时显示
                if !isEditing {
                    Button {
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil.tip")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 16)
                    .accessibilityLabel("画笔")
                }
            }
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("清空所有", role: .destructive) {
                            showDeleteAllConfirm = true
                        }
                    }
                }
            }
            .alert("清空所有范围？", isPresented: $showDeleteAllConfirm) {
                Button("删除", role: .destructive) { deleteAllRegions() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作会删除本机保存的所有范围，且无法撤销。")
            }
        }
    }

    private func loadSavedPolygons() -> [[CLLocationCoordinate2D]] {
        regions.compactMap { r in
            guard let data = r.pointsData else { return nil }
            return try? GeoCodec.decode(data)
        }
    }
    // test commit
    private func saveCurrentPolygon() {
        guard drawingPoints.count >= 3 else { return }
        do {
            let r = Region(context: context)
            r.id = UUID()
            r.createdAt = Date()
            r.pointsData = try GeoCodec.encode(drawingPoints)

            try context.save()
            drawingPoints.removeAll()
        } catch {
            print("保存失败: \(error)")
        }
    }

    private func deleteAllRegions() {
        for r in regions { context.delete(r) }
        do { try context.save() } catch { print("删除失败: \(error)") }
    }
}
#Preview {
    ContentView()
       
}
