import SwiftUI
import AppKit

struct EditorToolbarView: View {
    @Bindable var state: DrawingState

    var body: some View {
        HStack(spacing: 10) {
            Picker("", selection: $state.activeTool) {
                Image(systemName: "cursorarrow").tag(ToolType.select)
                Image(systemName: "pencil").tag(ToolType.pen)
                Image(systemName: "highlighter").tag(ToolType.highlighterPen)
                Image(systemName: "textformat").tag(ToolType.text)
                Image(systemName: "circle.badge.plus").tag(ToolType.stepMarker)
                Image(systemName: "arrow.up.right").tag(ToolType.arrow)
                Image(systemName: "rectangle").tag(ToolType.rect)
                Image(systemName: "circle").tag(ToolType.ellipse)
                Image(systemName: "rectangle.fill").tag(ToolType.highlight)
                Image(systemName: "aqi.medium").tag(ToolType.blur)
                Image(systemName: "plus.magnifyingglass").tag(ToolType.magnifier)
            }
            .pickerStyle(.segmented)
            .frame(width: 396)
            .help("Välj verktyg")

            Menu {
                ForEach(SymbolKind.allCases, id: \.self) { kind in
                    Button {
                        state.selectedSymbol = kind
                        state.activeTool = .symbol
                    } label: {
                        Label(kind.title, systemImage: kind.symbolName)
                    }
                }
            } label: {
                Image(systemName: state.selectedSymbol.symbolName)
                    .frame(width: 20, height: 20)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(state.activeTool == .symbol ? Color.accentColor.opacity(0.18) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .help("Symboler")

            Divider().frame(height: 22)

            ColorPicker("", selection: strokeColorBinding)
                .labelsHidden()
                .frame(width: 28)
                .help("Färg")

            if [ToolType.rect, ToolType.ellipse].contains(state.activeTool) {
                Toggle("", isOn: $state.fillEnabled)
                    .toggleStyle(.checkbox)
                    .help("Aktivera fyllning")
                ColorPicker("", selection: fillColorBinding)
                    .labelsHidden()
                    .frame(width: 28)
                    .opacity(state.fillEnabled ? 1.0 : 0.35)
                    .help("Fyllningsfärg")
            }

            if state.activeTool == .highlighterPen {
                Text("Opacitet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $state.highlighterOpacity, in: 0.1...0.9, step: 0.05)
                    .frame(width: 80)
                    .help("Opacitet: \(Int(state.highlighterOpacity * 100))%")
            }

            if state.activeTool == .magnifier {
                Text("Zoom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $state.bubbleZoomLevel, in: 1.5...5.0, step: 0.5)
                    .frame(width: 80)
                    .help("Zoomnivå: \(state.bubbleZoomLevel, specifier: "%.1f")x")
            }

            if state.activeTool == .blur {
                Picker("", selection: $state.blurMode) {
                    Text("Blur").tag(BlurMode.gaussian)
                    Text("Pixel").tag(BlurMode.pixelate)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
                .help("Blur-läge")
            }

            Text("Storlek")
                .font(.caption)
                .foregroundStyle(.secondary)

            Slider(value: $state.lineWidth, in: 1...20, step: 0.5)
                .frame(width: 80)
                .help("Linjebredd: \(Int(state.lineWidth))pt")

            Divider().frame(height: 22)

            Text("Canvas")
                .font(.caption)
                .foregroundStyle(.secondary)

            Slider(value: $state.zoomScale, in: 0.25...4.0, step: 0.05)
                .frame(width: 100)
                .help("Canvas-zoom: \(Int(state.zoomScale * 100))%")

            Text("\(Int(state.zoomScale * 100))%")
                .font(.caption.monospacedDigit())
                .frame(width: 42, alignment: .trailing)

            Button("100%") {
                state.zoomScale = 1.0
            }
            .font(.caption)
            .help("Återställ canvas-zoom")

            Divider().frame(height: 22)

            Button {
                state.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(state.annotations.isEmpty)
            .help("Ångra (⌘Z)")

            Button {
                state.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(state.redoStack.isEmpty)
            .help("Gör om (⌘⇧Z)")

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(.bar)
    }

    private var strokeColorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: state.activeColor) },
            set: { state.activeColor = NSColor($0) }
        )
    }

    private var fillColorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: state.fillColor) },
            set: { state.fillColor = NSColor($0) }
        )
    }
}
