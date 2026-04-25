//
//  AdminOrdersView.swift
//  Callaloo
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AdminOrdersView: View {
    @Environment(SessionStore.self) private var session
    @State private var model = OrderRequestsModel()
    @State private var errorMessage: String?

    private var householdId: String? { session.userProfile?.householdId }

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach(model.orders.filter { $0.status == .pending }) { order in
                        NavigationLink {
                            AdminOrderDetailView(order: order, householdId: householdId ?? "")
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(order.createdAt.map { Self.format($0) } ?? "New request")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(order.itemsSnapshot.map { $0["title"] ?? "" }.joined(separator: ", "))
                                    .font(.body)
                                    .lineLimit(2)
                            }
                        }
                    }
                }

                if model.orders.filter({ $0.status == .pending }).isEmpty {
                    ContentUnavailableView(
                        "No open requests",
                        systemImage: "checkmark.circle",
                        description: Text("When a parent taps Order, it will show up here.")
                    )
                }
            }
            .navigationTitle("To order")
            .safeAreaInset(edge: .bottom) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                }
            }
            .task(id: householdId) {
                guard let householdId else { return }
                model.start(householdId: householdId)
            }
            .onDisappear { model.stop() }
        }
    }

    private static func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

struct AdminOrderDetailView: View {
    let order: OrderRequest
    let householdId: String

    @Environment(\.dismiss) private var dismiss
    @State private var isMarking = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Items") {
                ForEach(order.itemsSnapshot.indices, id: \.self) { index in
                    let row = order.itemsSnapshot[index]
                    Text(row["title"] ?? "Item")
                }
            }

            Section {
                Button("Mark as ordered") {
                    Task { await markOrdered() }
                }
                .disabled(isMarking)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
        }
        .navigationTitle("Request")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func markOrdered() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        errorMessage = nil
        isMarking = true
        defer { isMarking = false }
        do {
            let ref = Firestore.firestore()
                .collection("households")
                .document(householdId)
                .collection("orderRequests")
                .document(order.id)
            try await ref.updateData(
                [
                    "status": OrderRequest.Status.ordered.rawValue,
                    "orderedAt": FieldValue.serverTimestamp(),
                    "orderedByAdminUid": uid,
                ]
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
