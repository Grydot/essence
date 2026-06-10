import SwiftUI

/// Flat list of every character across every account — click to launch. Launch
/// as many as you like (each is an independent RuneLite process), then close
/// the window to quit Essence entirely.
struct PickerView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.accounts.isEmpty {
                Text("No accounts yet").font(.headline)
                Text("Sign in to add a Jagex account.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(model.accounts) { account in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(account.nickname).font(.headline)
                            Spacer()
                            Button(role: .destructive) { model.remove(account) } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove this account")
                        }
                        ForEach(account.characters) { ch in
                            Button {
                                model.launch(account: account, character: ch)
                            } label: {
                                Label(ch.displayName.isEmpty ? ch.id : ch.displayName,
                                      systemImage: "play.fill")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .controlSize(.large)
                        }
                    }
                }
            }

            Divider()

            Button {
                model.beginLogin()
            } label: {
                Label(model.isLoggingIn ? "Signing in…" : "Log in / add account…",
                      systemImage: "person.badge.plus")
            }
            .disabled(model.isLoggingIn)

            if let err = model.errorMessage {
                Text(err).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(18)
        .frame(width: 360)
    }
}
