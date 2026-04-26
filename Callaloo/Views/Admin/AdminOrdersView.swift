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

    private var pendingOrders: [OrderRequest] {
        model.orders.filter { $0.status == .pending }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach(pendingOrders) { order in
                        NavigationLink {
                            AdminOrderDetailView(order: order, householdId: householdId ?? "")
                        } label: {
                            orderRow(order)
                        }
                        .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 16))
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .callalooListBackground()

                if pendingOrders.isEmpty {
                    ContentUnavailableView(
                        "All caught up",
                        systemImage: "checkmark.circle.fill",
                        description: Text("When a parent requests an order from their list, it will appear here.")
                    )
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("To order")
            .safeAreaInset(edge: .bottom) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
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

    private func orderRow(_ order: OrderRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(order.createdAt.map { Self.format($0) } ?? "New request")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.12))
                    }
                Spacer(minLength: 0)
            }
            Text(order.itemsSnapshot.map { $0["title"] ?? "" }.joined(separator: ", "))
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 4)
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
            Section {
                ForEach(order.itemsSnapshot.indices, id: \.self) { index in
                    let row = order.itemsSnapshot[index]
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(Color.accentColor.opacity(0.6))
                            .accessibilityHidden(true)
                        Text(row["title"] ?? "Item")
                            .font(.body)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Items in this request")
                    .textCase(nil)
            }

            Section {
                Button {
                    Task { await markOrdered() }
                } label: {
                    HStack(spacing: 10) {
                        if isMarking {
                            ProgressView()
                        }
                        Text("Mark as ordered")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isMarking)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .callalooListBackground()
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
