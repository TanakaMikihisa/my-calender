import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SettingsViewModel()
    @State private var showTagForm = false
    @State private var editingTag: Tag?

    var body: some View {
        NavigationStack {
            Form {
                Section("タグ") {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if viewModel.tags.isEmpty {
                        Text("タグがありません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.tags) { tag in
                            Button {
                                editingTag = tag
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.from(hex: tag.colorHex))
                                        .frame(width: 24, height: 24)
                                    Text(tag.name)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                    Button("タグを追加") {
                        editingTag = nil
                        showTagForm = true
                    }
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear { viewModel.loadTags() }
            .sheet(isPresented: $showTagForm) {
                TagFormSheet(
                    tag: editingTag,
                    onSave: { viewModel.loadTags() },
                    onDismiss: { showTagForm = false }
                )
            }
            .sheet(item: $editingTag) { tag in
                TagFormSheet(
                    tag: tag,
                    onSave: { viewModel.loadTags(); editingTag = nil },
                    onDismiss: { editingTag = nil }
                )
            }
            .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

/// 追加用: tag == nil。編集用: tag != nil。
struct TagFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tag: Tag?
    let onSave: () -> Void
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var selectedColorHex: String = Constants.tagPresetColors[0]
    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("名前") {
                    TextField("タグ名", text: $name)
                }
                Section("色") {
                    let colorOptions: [String] = {
                        if let tag, !Constants.tagPresetColors.contains(tag.colorHex) {
                            return [tag.colorHex] + Constants.tagPresetColors
                        }
                        return Constants.tagPresetColors
                    }()
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Button {
                                selectedColorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color.from(hex: hex))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColorHex == hex ? Color.primary : Color.clear, lineWidth: 3)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if tag != nil {
                    Section {
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            Text("このタグを削除")
                        }
                    }
                }
            }
            .navigationTitle(tag == nil ? "タグを追加" : "タグを編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { onDismiss(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tag == nil ? "追加" : "更新") {
                        Task { await save() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .onAppear {
                if let tag {
                    name = tag.name
                    selectedColorHex = tag.colorHex
                } else {
                    name = ""
                    selectedColorHex = Constants.tagPresetColors[0]
                }
            }
            .alert("タグを削除", isPresented: $showDeleteConfirm) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    Task { await deleteTag() }
                }
            } message: {
                Text("このタグを削除しますか？")
            }
            .alert("エラー", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() async {
        let vm = SettingsViewModel()
        isSaving = true
        defer { isSaving = false }
        if let tag {
            var t = tag
            t.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            t.colorHex = selectedColorHex
            let ok = await vm.updateTag(t)
            if ok { onSave(); dismiss() }
            else { errorMessage = vm.errorMessage }
        } else {
            let ok = await vm.addTag(name: name, colorHex: selectedColorHex)
            if ok { onSave(); dismiss() }
            else { errorMessage = vm.errorMessage }
        }
    }

    private func deleteTag() async {
        guard let tag else { return }
        let vm = SettingsViewModel()
        let ok = await vm.deactivateTag(id: tag.id)
        if ok { onSave(); dismiss() }
        else { errorMessage = vm.errorMessage }
    }
}

#Preview {
    SettingsSheet()
}
