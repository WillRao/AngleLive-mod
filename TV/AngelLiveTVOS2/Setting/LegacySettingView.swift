//
//  TranslationSettingView.swift
//  AngelLiveTVOS2
//
//  房间标题翻译与字幕设置（移植自旧宿主，依赖全部在 Core）。
//

import SwiftUI
import AngelLiveCore
import AngelLiveDependencies

// MARK: - Room title translation

struct TranslationSettingView: View {
    private struct TargetLanguage: Identifiable {
        let code: String
        let name: String

        var id: String { code }
    }

    private let targetLanguages = [
        TargetLanguage(code: "zh-Hans", name: "中文简体"),
        TargetLanguage(code: "zh-Hant", name: "中文繁体"),
        TargetLanguage(code: "en", name: "英语"),
        TargetLanguage(code: "ja", name: "日语"),
        TargetLanguage(code: "ko", name: "韩语")
    ]

    @Environment(\.scenePhase) private var scenePhase
    @State private var settings = RoomTranslationSettings.shared
    @State private var translationService = RoomTitleTranslationService.shared
    @State private var baseURL = ""
    @State private var model = ""
    @State private var apiKey = ""
    @State private var isSaving = false
    @State private var isTesting = false
    @State private var isDeletingKey = false
    @State private var inlineMessage: String?
    @State private var testResult: String?
    @State private var activeTask: Task<Void, Never>?
    @State private var testGeneration = UUID()
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case enabled
        case danmakuEnabled
        case targetLanguage
        case baseURL
        case model
        case apiKey
        case save
        case delete
        case test
    }

    private var configurationNeedsSave: Bool {
        let normalizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedBaseURL != settings.cloudBaseURL
            || normalizedModel != settings.cloudModel
            || !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canTest: Bool {
        guard !isSaving, !isTesting, !isDeletingKey else { return false }
        return !configurationNeedsSave
            && settings.hasAPIKey
            && !settings.cloudBaseURL.isEmpty
            && !settings.cloudModel.isEmpty
    }

    private var cloudServiceExplanation: String {
        "填写服务商提供的 API 地址（通常以 /v1 结尾），需支持 Chat Completions 接口。\n只发送待翻译文字，不上传音频；服务商可能收费。API Key 仅保存在本机。"
    }

    var body: some View {
        @Bindable var settings = settings

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Toggle(isOn: $settings.isEnabled) {
                    Text("自动翻译房间标题")
                        .font(.system(size: 30, weight: .semibold))
                }
                .focused($focusedField, equals: .enabled)
                .frame(height: 55)

                Toggle(isOn: $settings.isDanmakuEnabled) {
                    Text("自动翻译弹幕")
                        .font(.system(size: 30, weight: .semibold))
                }
                .focused($focusedField, equals: .danmakuEnabled)
                .frame(height: 55)

                VStack(alignment: .leading, spacing: 10) {
                    Text("翻译成")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.secondary)

                    Picker("翻译成", selection: $settings.targetLanguage) {
                        ForEach(targetLanguages) { language in
                            Text(language.name)
                                .tag(language.code)
                        }
                    }
                    .focused($focusedField, equals: .targetLanguage)
                    .frame(height: 55)
                }

                Text("自动识别标题和弹幕的语言，翻译不成功时显示原文。")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LiveSubtitleSettingsSection()

                VStack(alignment: .leading, spacing: 12) {
                    Text("大模型翻译")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Apple TV 不支持系统翻译。填写下方配置，保存后点“测试翻译”。")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("API 地址")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("https://api.example.invalid/v1", text: $baseURL)
                        .focused($focusedField, equals: .baseURL)
                        .font(.system(size: 26))
                        .frame(height: 55)
                        .accessibilityLabel("API 地址")

                    Text("模型名称")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("模型名称", text: $model)
                        .focused($focusedField, equals: .model)
                        .font(.system(size: 26))
                        .frame(height: 55)
                        .accessibilityLabel("模型名称")

                    Text("API Key")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.secondary)
                    SecureField(settings.hasAPIKey ? "已保存，留空不修改" : "API Key", text: $apiKey)
                        .focused($focusedField, equals: .apiKey)
                        .font(.system(size: 26))
                        .frame(height: 55)
                        .accessibilityLabel("API Key")

                    HStack(spacing: 18) {
                        Button {
                            saveConfiguration()
                        } label: {
                            HStack(spacing: 10) {
                                Text("保存配置")
                                if isSaving {
                                    ProgressView()
                                }
                            }
                        }
                        .focused($focusedField, equals: .save)
                        .disabled(isSaving || isTesting || isDeletingKey)

                        if settings.hasAPIKey {
                            Button("删除 API Key", role: .destructive) {
                                deleteAPIKey()
                            }
                            .focused($focusedField, equals: .delete)
                            .disabled(isSaving || isTesting || isDeletingKey)
                        }
                    }

                    Text(cloudServiceExplanation)
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if configurationNeedsSave {
                    Text("请先保存配置，再测试翻译。")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }

                Button {
                    testTranslation()
                } label: {
                    HStack(spacing: 10) {
                        Text("测试翻译")
                        if isTesting {
                            ProgressView()
                        }
                    }
                }
                .focused($focusedField, equals: .test)
                .disabled(!canTest)

                if let inlineMessage {
                    Text(inlineMessage)
                        .font(.system(size: 22))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let serviceError = translationService.lastErrorMessage {
                    Text(serviceError)
                        .font(.system(size: 22))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let testResult {
                    Text("结果：\(testResult)")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(.vertical, 45)
            .padding(.horizontal, 60)
        }
        .scrollClipDisabled()
        .onAppear {
            if settings.engine != .llm {
                settings.engine = .llm
            }
            baseURL = settings.cloudBaseURL
            model = settings.cloudModel
        }
        .onChange(of: settings.targetLanguage) { _, _ in
            resetTranslationFeedback()
        }
        .onDisappear {
            testGeneration = UUID()
            activeTask?.cancel()
            activeTask = nil
            isTesting = false
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background, isTesting else { return }
            testGeneration = UUID()
            activeTask?.cancel()
            activeTask = nil
            isTesting = false
            inlineMessage = nil
            testResult = nil
            translationService.clearError()
        }
    }

    private func saveConfiguration() {
        testGeneration = UUID()
        activeTask?.cancel()
        activeTask = Task { @MainActor in
            isSaving = true
            inlineMessage = nil
            testResult = nil
            defer { isSaving = false }

            do {
                try settings.saveCloudConfiguration(baseURL: baseURL, model: model, apiKey: apiKey)
                baseURL = settings.cloudBaseURL
                model = settings.cloudModel
                apiKey = ""
            } catch {
                guard !Task.isCancelled else { return }
                inlineMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func deleteAPIKey() {
        testGeneration = UUID()
        activeTask?.cancel()
        activeTask = Task { @MainActor in
            isDeletingKey = true
            inlineMessage = nil
            testResult = nil
            defer { isDeletingKey = false }

            do {
                try settings.deleteAPIKey()
            } catch {
                guard !Task.isCancelled else { return }
                inlineMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func testTranslation() {
        let generation = UUID()
        testGeneration = generation
        activeTask?.cancel()
        activeTask = Task { @MainActor in
            guard !Task.isCancelled, testGeneration == generation else { return }
            isTesting = true
            inlineMessage = nil
            testResult = nil
            translationService.clearError()
            defer {
                if testGeneration == generation {
                    isTesting = false
                    activeTask = nil
                }
            }

            do {
                let result = try await translationService.testTranslation()
                guard !Task.isCancelled, testGeneration == generation else { return }
                testResult = result
            } catch {
                guard !Task.isCancelled, testGeneration == generation else { return }
                inlineMessage = translationService.lastErrorMessage
                    ?? (error as? RoomTranslationError)?.recoveryMessage(for: settings.engine)
                    ?? (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
        }
    }

    private func resetTranslationFeedback() {
        testGeneration = UUID()
        activeTask?.cancel()
        isTesting = false
        inlineMessage = nil
        testResult = nil
        translationService.clearError()
    }
}
