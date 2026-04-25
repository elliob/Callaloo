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

    private var householdId: String? { session.userProfile?.householdId }

    private var displayedItems: [ListItem] {
        listModel.items
            .filter(\.active)
            .sorted { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite && !rhs.isFavorite }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Your list") {
                    if displayedItems.isEmpty {
                        Text("Your family admin hasn’t added items yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(displayedItems) { item in
                            HStack {
                                Text(item.title)
                                if item.isFavorite {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                        .accessibilityLabel("Favorite")
                                }
                            }
                            .font(.title3)
                        }
                    }
                }
            }
            .navigationTitle("Callaloo")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Sign out", role: .destructive) {
                        session.signOut()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button {
                        Task { await placeOrder() }
                    } label: {
                        Text("Order")
                            .font(.title2.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)
                    .disabled(isSubmitting || displayedItems.isEmpty)
                    .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial)
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
            let snapshot: [[String: String]] = displayedItems.map { ["title": $0.title] }
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
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                Text("You’re all set")
                    .font(.title)
                Text("We’ve received your order request. It may take a little while to arrive depending on delivery.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Close") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Thank you")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
