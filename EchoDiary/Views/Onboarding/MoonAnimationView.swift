import SwiftUI

struct MoonAnimationView: View {
    var isDone: Bool
    @State private var phase: CGFloat = 0
    
    var body: some View {
        ZStack {
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.green)
            } else {
                // 月相动画
                Circle()
                    .fill(.gray.opacity(0.3))
                    .overlay(
                        Circle()
                            .fill(.white)
                            .overlay(
                                Circle()
                                    .fill(.gray.opacity(0.3))
                                    .offset(x: phase)
                            )
                            .mask(Circle())
                    )
                    .onAppear {
                        withAnimation(.linear(duration: 2).repeatForever(autoreverses: true)) {
                            phase = 30
                        }
                    }
            }
        }
        .frame(width: 64, height: 64)
    }
}


