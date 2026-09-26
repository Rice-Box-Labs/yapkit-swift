import SwiftUI
import YapKit

public struct YapDefaultComposerRenderer: YapComposerRenderer {
    public init() {}

    public func makeBody(context: YapComposerRendererContext) -> some View {
        YapComposer(
            draft: context.draft,
            replyMessage: context.replyMessage,
            stagedAttachmentNames: context.stagedAttachmentNames,
            isShowingAttachments: context.isShowingAttachments,
            theme: context.theme,
            onSend: context.send
        )
    }
}
struct YapComposer: View {
    @Binding var draft: String
    @Binding var replyMessage: YapMessage?
    @Binding var stagedAttachmentNames: [String]
    @Binding var isShowingAttachments: Bool
    let theme: YapTheme
    let onSend: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            if let replyMessage {
                HStack {
                    Rectangle().fill(theme.accent).frame(width: 3)
                    VStack(alignment: .leading) {
                        Text("Replying").font(.caption.bold()).foregroundStyle(
                            theme.accent
                        )
                        Text(replyMessage.text).font(.caption).lineLimit(1)
                    }
                    Spacer()
                    Button {
                        self.replyMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(
                            theme.secondaryText
                        )
                    }
                }.padding(.horizontal)
            }
            if !stagedAttachmentNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(stagedAttachmentNames, id: \.self) { name in
                            Label(name, systemImage: "doc").font(.caption)
                                .padding(8).background(
                                    theme.accent.opacity(0.1),
                                    in: Capsule()
                                )
                        }
                    }.padding(.horizontal)
                }
            }
            if isShowingAttachments {
                HStack {
                    Button {
                        stagedAttachmentNames.append("Photo")
                    } label: {
                        Label("Photos", systemImage: "photo")
                    }
                    Button {
                        stagedAttachmentNames.append("File")
                    } label: {
                        Label("Files", systemImage: "doc")
                    }
                }.font(.subheadline).foregroundStyle(theme.accent).padding(
                    .horizontal
                ).transition(.move(edge: .bottom).combined(with: .opacity))
            }
            GlassEffectContainer {
                HStack(alignment: .bottom, spacing: 8) {
                    Button {
                        withAnimation(.snappy) { isShowingAttachments.toggle() }
                    } label: {
                        Image(systemName: isShowingAttachments ? "xmark" : "plus")
                            .font(.title3)
                            .symbolEffect(.rotate, value: isShowingAttachments)
                            .padding(10)
                        //                        .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive())
                    .accessibilityLabel("Attachments")

                    HStack(alignment: .bottom) {
                        TextField("Message", text: $draft,axis: .vertical)
                            .lineLimit(1...5)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)

                        //                    .background(theme.incomingBubble, in: Capsule())
                        //                    .overlay(Capsule().stroke(theme.separator.opacity(0.55)))

                        Button(action: onSend) {
                            Image(systemName: "arrow.up")
                        }
                        .buttonStyle(.glassProminent)
                        .accentColor(
                            draft.trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty &&
                            stagedAttachmentNames.isEmpty ?
                            theme.secondaryText.opacity(0.35) : theme.accent
                        )
                        .disabled(
                            draft.trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty && stagedAttachmentNames.isEmpty
                        )
                        .padding(5)
                    }
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)
            //            .background(.bar)
        }
    }
}
struct EditMessageSheet: View {
    let message: YapMessage
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    init(message: YapMessage, onSave: @escaping (String) -> Void) {
        self.message = message
        self.onSave = onSave
        _text = State(initialValue: message.text)
    }
    var body: some View {
        NavigationStack {
            TextField("Message", text: $text, axis: .vertical).textFieldStyle(
                .roundedBorder
            ).padding().navigationTitle("Edit message").toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }.disabled(
                        text.trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    )
                }
            }
        }
    }
}

struct YapNewConversationView: View {
    let service: any YapChatService
    let tenantID: String
    let onCreated: (YapChannel) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var name = ""
    @State private var users: [YapUser] = []
    @State private var selected: Set<String> = []
    @State private var groupMode = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $groupMode) {
                        Text("Direct").tag(false)
                        Text("Group").tag(true)
                    }.pickerStyle(.segmented)
                }
                if groupMode {
                    Section("Group name") {
                        TextField("Weekend Crew", text: $name)
                    }
                }
                Section("People") {
                    ForEach(users) { user in
                        Button {
                            if groupMode {
                                if selected.contains(user.id) {
                                    selected.remove(user.id)
                                } else {
                                    selected.insert(user.id)
                                }
                            } else {
                                selected = [user.id]
                            }
                        } label: {
                            HStack {
                                Text(user.displayName ?? user.id)
                                Spacer()
                                if selected.contains(user.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
                Section {
                    Button(groupMode ? "Create group" : "Start conversation") {
                        Task {
                            do {
                                let channel =
                                    groupMode
                                    ? try await service.createGroupChannel(
                                        name: name.isEmpty ? "New group" : name,
                                        memberIds: Array(selected)
                                    )
                                    : try await service.createDirectChannel(
                                        otherUserId: selected.first ?? ""
                                    )
                                onCreated(channel)
                            } catch {}
                        }
                    }.disabled(
                        selected.isEmpty || (groupMode && selected.count < 2)
                    )
                }
            }.navigationTitle("New conversation").searchable(
                text: $query,
                prompt: "Search people"
            ).toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }.task(id: query) {
                users =
                    (try? await service.users(tenantId: tenantID, query: query))
                    ?? []
            }
        }
    }
}
