import SwiftUI

@MainActor
final class BuilderMeetingsModel: ObservableObject {
    @Published var meetings: [BuilderMeeting] = []
    @Published var loading = true
    @Published var error: String?

    func load(builderId: Int) async {
        loading = meetings.isEmpty
        error = nil
        do {
            meetings = try await APIClient.shared.get("/builder/\(builderId)/meetings")
        } catch { self.error = authMessage(error) }
        loading = false
    }
}

struct BuilderMeetingsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderMeetingsModel()

    var body: some View {
        Group {
            if model.loading {
                ProgressView()
            } else if let error = model.error {
                ErrorBanner(message: error).padding()
            } else if model.meetings.isEmpty {
                ContentUnavailableView("No site visits", systemImage: "calendar",
                    description: Text("Customer visit requests will appear here."))
            } else {
                List(model.meetings) { meeting in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(meeting.customerName ?? "Visitor").font(.headline)
                            Spacer()
                            StatusBadge(text: meeting.status ?? "Pending", color: statusColor(meeting.status))
                        }
                        if let type = meeting.meetingType {
                            Label(type, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(.secondary)
                        }
                        if !meeting.whenText.isEmpty {
                            Label(meeting.whenText, systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                        }
                        if let phone = meeting.customerPhone, !phone.isEmpty {
                            Label(phone, systemImage: "phone").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.insetGrouped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Site Visits")
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        .refreshable { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
    }
}
