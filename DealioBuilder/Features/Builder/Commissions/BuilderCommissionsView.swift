import SwiftUI

@MainActor
final class BuilderCommissionsModel: ObservableObject {
    @Published var commissions: [Commission] = []
    @Published var loading = true
    @Published var error: String?
    @Published var message: String?

    func load(builderId: Int) async {
        loading = commissions.isEmpty
        error = nil
        do {
            commissions = try await APIClient.shared.get("/builder/\(builderId)/commissions")
        } catch { self.error = authMessage(error) }
        loading = false
    }

    func isReleased(_ c: Commission) -> Bool {
        let status = (c.status ?? "").lowercased()
        return status.contains("released") || status == "paid"
    }
    var released: Double { commissions.filter(isReleased).reduce(0) { $0 + ($1.amount ?? 0) } }
    var pending: Double { commissions.filter { !isReleased($0) }.reduce(0) { $0 + ($1.amount ?? 0) } }
}

struct BuilderCommissionsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderCommissionsModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if model.loading && model.commissions.isEmpty {
                    ProgressView().padding(.top, 40)
                } else if let error = model.error, model.commissions.isEmpty {
                    ErrorBanner(message: error).padding(.horizontal)
                } else {
                    HStack(spacing: 12) {
                        StatCard(title: "Released", value: Money.inr(model.released),
                                 systemImage: "checkmark.seal", tint: .green)
                        StatCard(title: "Pending", value: Money.inr(model.pending),
                                 systemImage: "hourglass", tint: .orange)
                    }
                    .padding(.horizontal)

                    if model.commissions.isEmpty {
                        ContentUnavailableView("No commissions", systemImage: "indianrupeesign.circle",
                            description: Text("CP commissions on your deals appear here."))
                            .padding(.top, 30)
                    } else {
                        VStack(spacing: 12) {
                            // The whole card opens the breakdown; Release stays a
                            // separate control inside it so a tap meant to read
                            // never pays anyone.
                            ForEach(model.commissions) { c in
                                NavigationLink(value: c) {
                                    row(c)
                                }
                                .buttonStyle(.pressable)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .dealioPageBackground(Color(.systemGroupedBackground))
        .navigationTitle("Commissions")
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        .refreshable { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        // A release on the detail screen changes a row here.
        .onReceive(NotificationCenter.default.publisher(for: .commissionReleased)) { _ in
            Task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        }
        .alert("Commissions", isPresented: Binding(get: { model.message != nil },
                                                   set: { if !$0 { model.message = nil } })) {
            Button("OK", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }

    private func row(_ c: Commission) -> some View {
        let isReleased = model.isReleased(c)
        return HStack(spacing: 12) {
            IconBadge(systemImage: isReleased ? "checkmark.seal.fill" : "hourglass",
                      tint: isReleased ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.customerName ?? "—")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dealioTextPrimary)
                    .lineLimit(1)
                Text(c.projectName ?? "—")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 4) {
                Text(Money.inr(c.amount))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.dealioTextPrimary)
                StatusBadge(text: c.status ?? "Pending", color: statusColor(c.status))
            }
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.dealioTextSecondary.opacity(0.6))
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .cardSurface()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the commission breakdown")
    }
}

// MARK: - Detail

/// Releases one commission. Lives on the detail screen rather than being handed
/// down from the list, so the screen can be pushed from anywhere — including a
/// notification — and still act.
@MainActor
final class CommissionReleaseModel: ObservableObject {
    @Published var working = false
    @Published var releasedNow = false
    @Published var message: String?

    func release(builderId: Int, commissionId: String) async {
        working = true
        defer { working = false }
        do {
            try await APIClient.shared.patchVoid("/builder/\(builderId)/commissions/\(commissionId)/release")
            releasedNow = true
            message = "Commission released. The partner has been told."
            NotificationCenter.default.post(name: .commissionReleased, object: nil)
        } catch { message = authMessage(error) }
    }
}

extension Notification.Name {
    /// Posted after a successful release so any open commission list refreshes.
    static let commissionReleased = Notification.Name("dealio.commissionReleased")
}

/// One commission, spelled out — and the place the release actually happens.
struct BuilderCommissionDetailView: View {
    let commission: Commission

    @EnvironmentObject private var auth: AuthStore
    @StateObject private var release = CommissionReleaseModel()
    @State private var confirming = false

    private var released: Bool {
        if release.releasedNow { return true }
        let status = (commission.status ?? "").lowercased()
        return status.contains("released") || status == "paid"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                amountCard
                breakdownCard

                if !released {
                    Button { confirming = true } label: {
                        HStack(spacing: 8) {
                            if release.working {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Release this commission").font(.subheadline.weight(.bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.dealioStatusGreen,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                    .disabled(release.working)

                    Text("The partner is notified as soon as you release.")
                        .font(.caption)
                        .foregroundStyle(Color.dealioTextSecondary)
                }

                if let dealId = Int(commission.id) {
                    NavigationLink(value: PortalRoute.builderDealDetail(dealId)) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Open the deal").font(.subheadline.weight(.bold))
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.brandTeal)
                        .padding(.horizontal, 16).padding(.vertical, 15)
                        .frame(maxWidth: .infinity)
                        .background(Color.brandTeal.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.brandTeal.opacity(0.32), lineWidth: 1))
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(16)
        }
        .dealioPageBackground(Color(.systemGroupedBackground))
        .navigationTitle("Commission")
        .navigationBarTitleDisplayMode(.inline)
        // Releasing moves real money to the partner, so it asks first.
        .alert("Release this commission?", isPresented: $confirming) {
            Button("Release", role: .destructive) {
                Task {
                    guard let builderId = await auth.resolvedBuilderId() else { return }
                    await release.release(builderId: builderId, commissionId: commission.id)
                }
            }
            Button("Not yet", role: .cancel) {}
        } message: {
            Text("\(Money.inr(commission.amount)) goes to the partner who brought \(commission.customerName ?? "this buyer"). This is recorded and the partner is told.")
        }
        .alert("Commission", isPresented: Binding(get: { release.message != nil },
                                                  set: { if !$0 { release.message = nil } })) {
            Button("OK", role: .cancel) { release.message = nil }
        } message: { Text(release.message ?? "") }
    }

    private var amountCard: some View {
        VStack(spacing: 10) {
            Image(systemName: released ? "checkmark.seal.fill" : "hourglass")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(tintGradient(released ? .dealioStatusGreen : .dealioOrange), in: Circle())

            Text(Money.inr(commission.amount))
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.dealioTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            StatusBadge(text: commission.status ?? "Pending", color: statusColor(commission.status))

            if let date = commission.releasedDate?.trimmedOrNil {
                Text("Released \(date.prefix(10))").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .cardSurface()
    }

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "How it was worked out")
            VStack(spacing: 0) {
                detailRow("Buyer", commission.customerName?.nilIfEmpty ?? "—")
                Divider()
                detailRow("Project", commission.projectName?.nilIfEmpty ?? "—")
                Divider()
                detailRow("Sale value", Money.inr(commission.saleValue))
                Divider()
                detailRow("Commission rate",
                          (commission.commissionPercent ?? 0) > 0
                            ? String(format: "%.2f%%", commission.commissionPercent ?? 0)
                            : "—")
                Divider()
                detailRow("Partner commission", Money.inr(commission.amount), bold: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func detailRow(_ label: String, _ value: String, bold: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.subheadline).foregroundStyle(Color.dealioTextSecondary)
            Spacer(minLength: 12)
            Text(value)
                .font(bold ? .subheadline.weight(.bold) : .subheadline.weight(.medium))
                .foregroundStyle(bold ? Color.brandTeal : Color.dealioTextPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }
}
