import SwiftUI
import Security
import PoetryCore

/// Shared with backup settings. The bearer token never enters UserDefaults.
enum PoetryServiceSettings {
    private static let service = "com.nanfl.PoetryApp.personal-service"
    static func load() throws -> ServiceCredentials? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: "connection", kSecReturnData: true] as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: String],
              let url = object["url"].flatMap(URL.init(string:)), let token = object["token"] else { throw ContentUpdateError.unavailable }
        return try ServiceCredentials(baseURL: url, token: token)
    }
    static func save(_ credentials: ServiceCredentials) throws {
        let data = try JSONSerialization.data(withJSONObject: ["url": credentials.baseURL.absoluteString, "token": credentials.token])
        let query = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: "connection"] as CFDictionary
        let status = SecItemUpdate(query, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            let insert = SecItemAdd([kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: "connection", kSecValueData: data, kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly] as CFDictionary, nil)
            guard insert == errSecSuccess else { throw ContentUpdateError.unavailable }
        } else if status != errSecSuccess { throw ContentUpdateError.unavailable }
    }
}

struct ServiceSettingsView: View {
    @EnvironmentObject private var collection: CollectionStore
    let application: PoetryApplication
    @State private var address = ""
    @State private var token = ""
    @State private var message = "离线时仍可阅读和收藏。"
    @State private var updating = false
    var body: some View {
        Form {
            Section("个人服务") {
                TextField("私网 HTTPS 地址", text: $address).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                SecureField("访问凭据", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("保存连接") {
                    do { try PoetryServiceSettings.save(connection()); message = "连接已安全保存。"; Task { await collection.attemptBackup() } }
                    catch { message = "请检查 HTTPS 地址与访问凭据。" }
                }
            }
            Section("收藏备份") {
                Text(collection.backupMessage).font(.footnote).accessibilityIdentifier("collectionBackupStatus")
                Button("备份 / 重试") { Task { await collection.attemptBackup() } }.disabled(collection.backupBusy)
                Button("查看远端备份") { Task { await collection.previewRestore() } }.disabled(collection.backupBusy)
                if let receipt = collection.restorePreview {
                    Text("设备：" + receipt.snapshot.deviceID)
                    Text("修订：\(receipt.snapshot.revision) · \(receipt.snapshot.favorites.count) 首")
                    Text("备份时间：" + Date(timeIntervalSince1970: receipt.receivedAt).formatted())
                    Text("恢复将替换本机收藏，并沿用此备份的设备标识。")
                    Button("确认恢复此备份", role: .destructive) { collection.restore() }.disabled(collection.backupBusy)
                }
            }
            Section("内容") {
                Button(updating ? "正在检查更新…" : "检查更新 / 重试") { Task { await update() } }.disabled(updating)
                Text(message).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("contentUpdateStatus")
            }
        }.navigationTitle("个人服务").task {
            if let saved = try? PoetryServiceSettings.load() { address = saved.baseURL.absoluteString; token = saved.token }
        }
    }
    private func connection() throws -> ServiceCredentials {
        guard let url = URL(string: address) else { throw ContentUpdateError.invalid }
        return try ServiceCredentials(baseURL: url, token: token)
    }
    @MainActor private func update() async {
        updating = true
        defer { updating = false }
        do {
            let credentials = try connection()
            try PoetryServiceSettings.save(credentials)
            let data = try await PoetryServiceClient(credentials: credentials).downloadContent()
            try application.installContentPackage(data: data)
            message = "内容已更新，当日推荐与收藏已保留。"
        } catch let error as ContentUpdateError { message = error.localizedDescription }
        catch { message = "更新未完成，原有内容仍可阅读。可稍后重试。" }
    }
}
