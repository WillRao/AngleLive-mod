//
//  AboutUSView.swift
//  AngelLiveTVOS2
//
//  关于页：不复用旧版位图资源（新包没有对应 asset），用系统样式呈现。
//

import SwiftUI

struct AboutUSView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))

            Text("Angel Live")
                .font(.system(size: 40, weight: .bold))

            Text("v: \(versionText)")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)

            Text("本软件完全免费，仅用于学习交流编程技术，严禁将本项目用于商业目的。如有任何商业行为，均与本项目无关。")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 900)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var versionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(short) (\(build))"
    }
}
