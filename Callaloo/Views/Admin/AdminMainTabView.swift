//
//  AdminMainTabView.swift
//  Callaloo
//

import SwiftUI

struct AdminMainTabView: View {
    var body: some View {
        TabView {
            AdminListView()
                .tabItem { Label("List", systemImage: "list.bullet.rectangle") }

            AdminOrdersView()
                .tabItem { Label("Orders", systemImage: "shippingbox.fill") }

            AdminFamilyView()
                .tabItem { Label("Family", systemImage: "person.3.fill") }
        }
    }
}

#Preview {
    AdminMainTabView()
}
