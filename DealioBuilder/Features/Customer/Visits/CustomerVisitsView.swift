import SwiftUI

@MainActor
final class VisitsModel: ObservableObject {
    @Published var meetings: [CustomerMeeting] = []
    @Published var loading = true
    @Published var error: String?

    func load(phone: String) async {
        loading = meetings.isEmpty
        error = nil
        do {
            meetings = try await APIClient.shared.get("/portal/customer/meetings?phone=\(phone)")
        } catch { self.error = authMessage(error) }
        loading = false
    }
}

struct CustomerVisitsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = VisitsModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.loading {
                    ProgressView()
                } else if let error = model.error {
                    ErrorBanner(message: error).padding()
                } else if model.meetings.isEmpty {
                    ContentUnavailableView("No site visits yet",
                        systemImage: "calendar",
                        description: Text("Book a visit from a project to see it here."))
                } else {
                    List(model.meetings) { meeting in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(meeting.projectName ?? "Site visit").font(.headline)
                                Spacer()
                                StatusBadge(text: meeting.status ?? "Requested", color: statusColor(meeting.status))
                            }
                            if let builder = meeting.builderName {
                                Label(builder, systemImage: "building.2").font(.caption).foregroundStyle(.secondary)
                            }
                            if !meeting.whenText.isEmpty {
                                Label(meeting.whenText, systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationTitle("Visits")
            .task { await model.load(phone: auth.phone) }
            .refreshable { await model.load(phone: auth.phone) }
        }
    }
}
