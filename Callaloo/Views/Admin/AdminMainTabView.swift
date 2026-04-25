//
//  AdminMainTabView.swift
//  Callaloo
//

import SwiftUI

struct AdminMainTabView: View {
    var body: some View {
        TabView {
            AdminListView()
                .tabItem { Label("List", systemImage: "list.bullet") }

            AdminOrdersView()
                .tabItem { Label("Orders", systemImage: "shippingbox") }

            AdminFamilyView()
                .tabItem { Label("Family", systemImage: "person.3") }
        }
    }
}

#Preview {
    AdminMainTabView()
}
