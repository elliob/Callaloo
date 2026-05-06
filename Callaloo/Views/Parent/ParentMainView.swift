//
//  ParentMainView.swift
//  Callaloo
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ParentMainView: View {
    @Environment(SessionStore.self) private var session
    @State private var listModel = ListItemsModel()
    @State private var ordersModel = OrderRequestsModel()
    @State private var isSubmitting = false
    @State private var showThanks = false
    @State private var errorMessage: String?
    @State private var processedOrderedIds: Set<String> = []
    @State private var selectedItemIds: Set<String> = []

    private var householdId: String? { session.userProfile?.householdId }

    private var displayedItems: [ListItem] {
        listModel.items
            .filter(\.active)
            .sorted { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite && !rhs.isFavorite }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    private var selectedItems: [ListItem] {
        displayedItems.filter { selectedItemIds.contains($0.id) }
    }

    private var displayedItemIds: [String] { displayedItems.map(\.id) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if displayedItems.isEmpty {
                        ContentUnavailableView(
                            "Nothing on the list yet",
                            systemImage: "list.bullet.rectangle.portrait",
                            description: Text("When your family admin adds groceries, they will appear here.")
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(displayedItems) { item in
                            let isSelected = selectedItemIds.contains(item.id)
                            Button {
                                toggleSelection(item.id)
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(isSelected ? Color.accentColor : .secondary.opacity(0.55))
                                        .accessibilityHidden(true)
                                    ListItemPhotoThumbnail(photoData: item.photoData, size: 46)
                                    Text(item.title)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                    if item.isFavorite {
                                        Image(systemName: "star.fill")
                                            .font(.body)
                                            .foregroundStyle(.yellow)
                                            .symbolRenderingMode(.hierarchical)
                                            .accessibilityLabel("Favorite")
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Adds or removes this item from your order request")
                            .accessibilityLabel("\(item.title)\(item.isFavorite ? ", favorite" : "")\(isSelected ? ", selected for order" : ", not selected")")
                        }
                    }
                } header: {
                    Label("Your list", systemImage: "basket.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                } footer: {
                    if !displayedItems.isEmpty {
                        Text("Tap items to include in your request.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .callalooListBackground()
            .navigationTitle("Groceries")
            .callalooLogOutButton()
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 14) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button {
                        Task { await placeOrder() }
                    } label: {
                        HStack(spacing: 10) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(orderButtonTitle)
                        }
                    }
                    .buttonStyle(CallalooPrimaryCTAButtonStyle(isLoading: isSubmitting))
                    .disabled(isSubmitting || displayedItems.isEmpty || selectedItemIds.isEmpty)
                    .padding(.horizontal, 4)
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
            .sheet(isPresented: $showThanks) {
                ParentThanksView {
                    showThanks = false
                }
            }
            .task(id: householdId) {
                guard let householdId else { return }
                listModel.start(householdId: householdId)
                ordersModel.start(householdId: householdId)
                _ = await ReminderScheduler.requestAuthorizationIfNeeded()
            }
            .onDisappear {
                listModel.stop()
                ordersModel.stop()
            }
            .onChange(of: ordersModel.orders) { _, newOrders in
                handleNewlyOrdered(newOrders)
            }
            .onChange(of: displayedItemIds) { _, ids in
                let valid = Set(ids)
                selectedItemIds = selectedItemIds.intersection(valid)
            }
        }
    }

    private var orderButtonTitle: String {
        if displayedItems.isEmpty { return "Nothing to order" }
        if selectedItemIds.isEmpty { return "Select items to order" }
        if selectedItemIds.count == 1 { return "Request order" }
        return "Request order (\(selectedItemIds.count))"
    }

    private func toggleSelection(_ id: String) {
        if selectedItemIds.contains(id) {
            selectedItemIds.remove(id)
        } else {
            selectedItemIds.insert(id)
        }
    }

    private func handleNewlyOrdered(_ orders: [OrderRequest]) {
        for order in orders where order.status == .ordered {
            guard let orderedAt = order.orderedAt else { continue }
            let recent = Date().timeIntervalSince(orderedAt) < 120
            if recent, !processedOrderedIds.contains(order.id) {
                processedOrderedIds.insert(order.id)
                Task {
                    _ = await ReminderScheduler.requestAuthorizationIfNeeded()
                    ReminderScheduler.scheduleAfterOrderPlaced()
                }
            }
        }
    }

    private func placeOrder() async {
        guard let householdId, let uid = Auth.auth().currentUser?.uid else { return }
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let snapshot: [[String: String]] = selectedItems.map {
                ["title": $0.title, "listItemId": $0.id]
            }
            let ref = Firestore.firestore()
                .collection("households")
                .document(householdId)
                .collection("orderRequests")
                .document()
            try await ref.setData(
                [
                    "status": OrderRequest.Status.pending.rawValue,
                    "itemsSnapshot": snapshot,
                    "createdByParentUid": uid,
                    "createdAt": FieldValue.serverTimestamp(),
                ]
            )
            selectedItemIds = []
            showThanks = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ParentThanksView: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "paperplane.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.accentColor, Color.accentColor.opacity(0.3))
                    .font(.system(size: 72))
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text("Request sent!")
                        .font(.title.bold())
                    Text("Your family shopper has your list and will take it from here. Delivery timing will depend on how they fulfill orders.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Done", action: onDismiss)
                    .buttonStyle(CallalooPrimaryCTAButtonStyle())
                    .padding(.horizontal, 8)
            }
            .padding(28)
            .frame(maxWidth: CallalooTheme.contentMaxWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Thank you")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
