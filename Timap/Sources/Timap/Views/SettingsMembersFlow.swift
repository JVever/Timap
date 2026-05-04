import SwiftUI
import AppKit
import TimapCore

private let bdAccent = Color(hex: "#ff8a5b")
private let dangerRed = Color(hex: "#e85a5a")

/// Chip-flow + "+ 同事" affordance. Chip → inline edit form on pencil. All
/// pills (chip / edit form / add button / confirm) share the same 26pt
/// outer height so the row visually aligns.
struct MembersFlowView: View {
    let cityName: String
    let members: [Teammate]
    let workStart: Double
    let workEnd: Double
    let onUpsert: (Teammate) -> Void
    let onRemove: (UUID) -> Void

    @EnvironmentObject var state: AppState
    @State private var editingId: UUID? = nil
    @State private var addingDraft: Teammate? = nil
    @State private var confirmId: UUID? = nil

    var body: some View {
        WrappingHStack(spacing: 6, lineSpacing: 6) {
            ForEach(members) { p in
                if editingId == p.id {
                    AnyView(MemberEditForm(
                        member: p, isNew: false,
                        onSave: { updated in
                            onUpsert(updated)
                            editingId = nil
                        },
                        onCancel: { editingId = nil }
                    ))
                } else {
                    AnyView(MemberChip(
                        person: p,
                        confirming: confirmId == p.id,
                        canDelete: true,
                        onEdit: { editingId = p.id },
                        onAskRemove: { confirmId = p.id },
                        onConfirmRemove: {
                            onRemove(p.id)
                            confirmId = nil
                        },
                        onCancelRemove: { confirmId = nil }
                    ))
                }
            }
            if let draft = addingDraft {
                AnyView(MemberEditForm(
                    member: draft, isNew: true,
                    onSave: { updated in
                        onUpsert(updated)
                        addingDraft = nil
                    },
                    onCancel: { addingDraft = nil }
                ))
            } else {
                AnyView(addButton)
            }
        }
    }

    private var addButton: some View {
        Button(action: {
            addingDraft = Teammate(
                name: "", role: "",
                city: cityName, country: "", flag: "",
                tzIdentifier: "UTC", lat: 0, lng: 0,
                workStart: workStart, workEnd: workEnd,
                colorHex: Palette.color(for: UUID().uuidString)
            )
        }) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .heavy))
                Text(state.tr(.addTeammateChip))
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.55))
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 999)
                    .strokeBorder(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 0.5, dash: [3]))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chip (display state)

private struct MemberChip: View {
    let person: Teammate
    let confirming: Bool
    let canDelete: Bool
    let onEdit: () -> Void
    let onAskRemove: () -> Void
    let onConfirmRemove: () -> Void
    let onCancelRemove: () -> Void

    @EnvironmentObject var state: AppState
    @State private var hovered = false

    var body: some View {
        if confirming {
            confirmView
        } else {
            chipView
        }
    }

    private var chipView: some View {
        HStack(spacing: 6) {
            AvatarView(person: person, size: 20)
            Text(person.name.isEmpty ? state.tr(.unnamed) : person.name)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: true, vertical: false)
            HStack(spacing: 2) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .help(state.tr(.editTooltip))
                if canDelete {
                    Button(action: onAskRemove) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .help(state.tr(.deleteTooltip))
                }
            }
            .opacity(hovered ? 1 : 0.55)
        }
        .padding(.leading, 3).padding(.trailing, 6)
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: 999)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 999)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .onHover { hovered = $0 }
    }

    private var confirmView: some View {
        HStack(spacing: 6) {
            Text(L10n.deletePersonPrompt(person.name, state.language))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "#ff9b9b"))
                .fixedSize(horizontal: true, vertical: false)
            Button(state.tr(.confirm), action: onConfirmRemove)
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 3).fill(dangerRed.opacity(0.3)))
                .fixedSize()
            Button(state.tr(.cancel), action: onCancelRemove)
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.55))
                .fixedSize()
        }
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: 999)
                .fill(dangerRed.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 999)
                        .stroke(dangerRed.opacity(0.4), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Inline edit form

private struct MemberEditForm: View {
    let member: Teammate
    let isNew: Bool
    let onSave: (Teammate) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var state: AppState
    @State private var name: String
    @State private var avatarData: Data?
    @FocusState private var nameFocused: Bool

    init(member: Teammate, isNew: Bool, onSave: @escaping (Teammate) -> Void, onCancel: @escaping () -> Void) {
        self.member = member
        self.isNew = isNew
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: member.name)
        _avatarData = State(initialValue: member.avatarData)
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private var preview: Teammate {
        var p = member
        p.name = name.isEmpty ? (member.name.isEmpty ? "?" : member.name) : name
        p.avatarData = avatarData
        return p
    }

    var body: some View {
        HStack(spacing: 6) {
            // Avatar (click to upload). Re-uses .fixedSize() to claim its
            // own 22pt slot so the surrounding HStack doesn't compress it.
            Button(action: pickAvatar) {
                AvatarView(person: preview, size: 22)
            }
            .buttonStyle(.plain)
            .help(state.tr(.uploadAvatarTooltip))
            .fixedSize()

            // Name input. Bound width so a long-typed name doesn't push
            // the save/cancel buttons out of the chip.
            TextField(isNew ? state.tr(.teammateNamePlaceholder) : state.tr(.fieldName), text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 78)
                .focused($nameFocused)
                .onSubmit { if canSave { onSave(commit()) } }
                .onAppear { DispatchQueue.main.async { nameFocused = true } }

            // "Use initials" — only when an image is set. Compact label.
            if avatarData != nil {
                Button(action: { avatarData = nil }) {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help(state.tr(.useInitials))
                .fixedSize()
            }

            // Save / Cancel — both .fixedSize() so neither gets truncated
            // by the FlowLayout's natural-size proposal when the chip is
            // wider than the available row width.
            Button(state.tr(.save)) { if canSave { onSave(commit()) } }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(canSave ? bdAccent : .white.opacity(0.3))
                .padding(.horizontal, 8).padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(canSave ? bdAccent.opacity(0.18) : Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(canSave ? bdAccent.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                )
                .disabled(!canSave)
                .fixedSize()
            Button(state.tr(.cancel), action: onCancel)
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.55))
                .fixedSize()
                .keyboardShortcut(.cancelAction)
        }
        .padding(.leading, 4).padding(.trailing, 8)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 999)
                .fill(bdAccent.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 999)
                        .stroke(bdAccent.opacity(0.32), lineWidth: 0.5)
                )
        )
    }

    private func commit() -> Teammate {
        var p = member
        p.name = name.trimmingCharacters(in: .whitespaces)
        p.avatarData = avatarData
        if p.colorHex.isEmpty { p.colorHex = Palette.color(for: p.id.uuidString) }
        return p
    }

    private func pickAvatar() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .image]
        panel.title = state.tr(.uploadAvatarTooltip)
        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url),
               let image = NSImage(data: data) {
                avatarData = Self.scaledPNG(from: image, side: 192) ?? data
            }
        }
    }

    private static func scaledPNG(from image: NSImage, side: CGFloat) -> Data? {
        let original = image.size
        let scale = min(1, side / max(original.width, original.height))
        let newSize = NSSize(width: original.width * scale, height: original.height * scale)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(newSize.width),
            pixelsHigh: Int(newSize.height),
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )
        guard let rep = rep else { return nil }
        rep.size = newSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: original),
            operation: .copy, fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }
}

// MARK: - Avatar (image or initials)

struct AvatarView: View {
    let person: Teammate
    let size: CGFloat

    var body: some View {
        Group {
            if let data = person.avatarData, let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle().fill(Color(hex: person.colorHex.isEmpty
                                        ? Palette.color(for: person.id.uuidString)
                                        : person.colorHex))
                    Text(Initials.of(person.name))
                        .font(.system(size: max(8, size * fontScale), weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: size, height: size)
            }
        }
    }

    private var fontScale: CGFloat {
        let initials = Initials.of(person.name)
        let chinese = Initials.hasCJK(person.name)
        if chinese && initials.count >= 2 { return 0.36 }
        return 0.42
    }
}

// MARK: - Wrapping HStack

struct WrappingHStack<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    let content: Content

    init(spacing: CGFloat, lineSpacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.content = content()
    }

    var body: some View {
        FlowLayoutHost(spacing: spacing, lineSpacing: lineSpacing) {
            content
        }
    }
}

private struct FlowLayoutHost<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    let content: Content

    init(spacing: CGFloat, lineSpacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.content = content()
    }

    var body: some View {
        if #available(macOS 13.0, *) {
            FlowLayout(spacing: spacing, lineSpacing: lineSpacing) {
                content
            }
        } else {
            HStack(spacing: spacing) { content }
        }
    }
}

@available(macOS 13.0, *)
private struct FlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var rowW: CGFloat = 0
        var totalH: CGFloat = 0
        var rowH: CGFloat = 0
        var firstInRow = true
        for sv in subviews {
            let natural = sv.sizeThatFits(.unspecified)
            // Clamp oversized children to row width so a long chip never
            // overflows past the card edge.
            let clampedWidth = min(natural.width, maxW)
            let probe = sv.sizeThatFits(ProposedViewSize(width: clampedWidth, height: natural.height))
            let sz = CGSize(width: clampedWidth, height: probe.height)
            let candidate = firstInRow ? sz.width : rowW + spacing + sz.width
            if candidate > maxW && !firstInRow {
                totalH += rowH + lineSpacing
                rowW = sz.width
                rowH = sz.height
                firstInRow = false
            } else {
                rowW = candidate
                rowH = max(rowH, sz.height)
                firstInRow = false
            }
        }
        totalH += rowH
        return CGSize(width: min(maxW, max(rowW, 0)), height: totalH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxW = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowH: CGFloat = 0
        var firstInRow = true
        for sv in subviews {
            let natural = sv.sizeThatFits(.unspecified)
            let clampedWidth = min(natural.width, maxW)
            let probe = sv.sizeThatFits(ProposedViewSize(width: clampedWidth, height: natural.height))
            let sz = CGSize(width: clampedWidth, height: probe.height)
            let candidateRight = firstInRow ? bounds.minX + sz.width : x + spacing + sz.width
            if candidateRight > bounds.minX + maxW && !firstInRow {
                y += rowH + lineSpacing
                x = bounds.minX
                rowH = 0
                firstInRow = true
            }
            let placeX = firstInRow ? x : x + spacing
            sv.place(
                at: CGPoint(x: placeX, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: sz.width, height: sz.height)
            )
            x = placeX + sz.width
            rowH = max(rowH, sz.height)
            firstInRow = false
        }
    }
}
