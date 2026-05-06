//
//  ListItemPhotoThumbnail.swift
//  Callaloo
//

import SwiftUI
import UIKit

struct ListItemPhotoThumbnail: View {
    let photoData: Data?
    var size: CGFloat = 52

    var body: some View {
        Group {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                    Image(systemName: "photo")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}
