//
//  StatusViews.swift
//  Native splash screen shown while the site boots, and the offline screen.
//

import SwiftUI

struct SplashView: View {

    let progress: Double

    var body: some View {
        ZStack {
            AppConfig.background.ignoresSafeArea()

            VStack(spacing: 26) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 132, height: 132)
                    .shadow(color: AppConfig.accent.opacity(0.35), radius: 26, x: 0, y: 10)

                Text(AppConfig.displayName.uppercased())
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundColor(.white.opacity(0.92))

                ProgressView(value: min(max(progress, 0.03), 1.0))
                    .progressViewStyle(.linear)
                    .tint(AppConfig.accent)
                    .frame(width: 150)
                    .scaleEffect(x: 1, y: 0.7, anchor: .center)
            }
            .padding(.bottom, 24)
        }
    }
}

struct OfflineView: View {

    let retry: () -> Void

    var body: some View {
        ZStack {
            AppConfig.background.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                Text("Can't reach Mystery Dice")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Check your internet connection, then try again.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button(action: retry) {
                    Text("Try Again")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(AppConfig.accent)
                        )
                }
                .padding(.top, 8)
            }
        }
    }
}

#if DEBUG
struct StatusViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SplashView(progress: 0.4)
            OfflineView(retry: {})
        }
        .preferredColorScheme(.dark)
    }
}
#endif
