//
//  AdminListView.swift
//  Callaloo
//

import SwiftUI
import FirebaseFirestore
import PhotosUI
import UIKit

struct AdminListView: View {
    @Environment(SessionStore.self) private var session
    @State private var model = ListItemsModel()
    @State private var newTitle = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoItemId: String?

    private var householdId: String? { session.userProfile?.householdId }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.items) { item in
                        HStack(alignment: .top, spacing: 12) {
                            ListItemPhotoThumbnail(photoData: item.photoData)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.body.weight(.semibold))
                                if !item.notes.isEmpty {
                                    Text(item.notes)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 8)
                            Button {
                                Task { await toggleFavorite(item) }
                            } label: {
                                Image(systemName: item.isFavorite ? "star.fill" : "star")
                                    .font(.body)
                                    .foregroundStyle(item.isFavorite ? Color.yellow : Color.secondary)
                                    .symbolRenderingMode(.hierarchical)
                                    .frame(width: 36, height: 36)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(item.isFavorite ? "Remove favorite" : "Mark favorite")
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(item.photoData == nil ? "Add Photo" : "Change Photo", systemImage: "photo") {
                                selectedPhotoItemId = item.id
                                selectedPhotoItem = nil
                                showingPhotoPicker = true
                            }
                            .tint(.blue)
                            Button("Hide", systemImage: "eye.slash", role: .destructive) {
                                Task { await setActive(item, active: false) }
                            }
                        }
                    }
                } header: {
                    Label("Visible to parents", systemImage: "eye")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .callalooListBackground()
            .navigationTitle("Groceries")
            .callalooLogOutButton()
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if let listenErr = model.lastListenError {
                        Text(listenErr)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    HStack(alignment: .center, spacing: 10) {
                        TextField("Add an item", text: $newTitle)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background {
                                RoundedRectangle(cornerRadius: CallalooTheme.cornerRadiusMedium, style: .continuous)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            }
                            .submitLabel(.done)
                            .onSubmit { Task { await addItem() } }

                        Button {
                            Task { await addItem() }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                        }
                        .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                        .accessibilityLabel("Add item")
                    }
                    .padding(.bottom, 6)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .background {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .mask {
                            LinearGradient(
                                colors: [.black, .black.opacity(0.92)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .task(id: householdId) {
                guard let householdId else { return }
                model.start(householdId: householdId)
            }
            .photosPicker(
                isPresented: $showingPhotoPicker,
                selection: $selectedPhotoItem,
                matching: .images
            )
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem, let itemId = selectedPhotoItemId else { return }
                Task { await savePhoto(from: newItem, to: itemId) }
            }
            .onDisappear {
                model.stop()
            }
        }
    }

    private func addItem() async {
        guard let householdId else { return }
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            let ref = Firestore.firestore()
                .collection("households")
                .document(householdId)
                .collection("listItems")
                .document()
            let order = Int(Date().timeIntervalSince1970)
            try await ref.setData(
                [
                    "title": title,
                    "notes": "",
                    "isFavorite": false,
                    "sortOrder": order,
                    "active": true,
                ]
            )
            newTitle = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleFavorite(_ item: ListItem) async {
        guard let householdId else { return }
        errorMessage = nil
        do {
            let ref = Firestore.firestore()
                .collection("households")
                .document(householdId)
                .collection("listItems")
                .document(item.id)
            try await ref.updateData(["isFavorite": !item.isFavorite])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func savePhoto(from photoItem: PhotosPickerItem, to itemId: String) async {
        guard let householdId else { return }
        errorMessage = nil
        do {
            guard let originalData = try await photoItem.loadTransferable(type: Data.self) else {
                errorMessage = "Could not read the selected photo."
                return
            }
            guard let image = UIImage(data: originalData), let photoData = resizedJPEGData(from: image) else {
                errorMessage = "Could not process the selected photo."
                return
            }
            let ref = Firestore.firestore()
                .collection("households")
                .document(householdId)
                .collection("listItems")
                .document(itemId)
            try await ref.updateData(["photoData": photoData])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resizedJPEGData(from image: UIImage) -> Data? {
        let maxSide: CGFloat = 320
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }

        let scale = min(maxSide / sourceSize.width, maxSide / sourceSize.height, 1)
        let targetSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let renderedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return renderedImage.jpegData(compressionQuality: 0.72)
    }

    private func setActive(_ item: ListItem, active: Bool) async {
        guard let householdId else { return }
        errorMessage = nil
        do {
            let ref = Firestore.firestore()
                .collection("households")
                .document(householdId)
                .collection("listItems")
                .document(item.id)
            try await ref.updateData(["active": active])
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
