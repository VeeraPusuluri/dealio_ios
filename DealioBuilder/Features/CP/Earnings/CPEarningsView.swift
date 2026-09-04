import SwiftUI

/// Which slice of the ledger is on screen.
enum EarningsFilter: String, CaseIterable, Identifiable {
    case all = "All", released = "Released", pending = "Pending"
    var id: String { rawValue }
}

@MainActor
final class CPEarningsModel: ObservableObject {
    @Published var commissions: [CpCommission] = []
    @Published var filter: EarningsFilter = .all
    @Published var loading = true
    @Published var error: String?

    func load(cpUserId: Int) async {
        loading = commissions.isEmpty
        error = nil
        do {
            commissions = try await APIClient.shared.get("/cp/\(cpUserId)/commissions")
        } catch { self.error = authMessage(error) }
        loading = false
    }

    func isReleased(_ c: CpCommission) -> Bool {
        let s = (c.commissionStatus ?? "").lowercased()
        return s.contains("released") || s == "paid"
    }

    var totalEarned: Double {
        commissions.filter(isReleased).reduce(0) { $0 + $1.commissionAmount }
    }
    var totalPending: Double {
        commissions.filter { !isReleased($0) }.reduce(0) { $0 + $1.commissionAmount }
    }

    var visible: [CpCommission] {
        switch filter {
        case .all: return commissions
        case .released: return commissions.filter(isReleased)
        case .pending: return commissions.filter { !isReleased($0) }
        }
    }

    func count(_ filter: EarningsFilter) -> Int {
        switch filter {
        case .all: return commissions.count
        case .released: return commissions.filter(isReleased).count
        case .pending: return commissions.filter { !isReleased($0) }.count
        }
    }
}

struct CPEarningsView: View {
    @EnvironmentObject private var router: PortalRouter
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPEarningsModel()
    @State private var openCommission: CpCommission?

    var body: some View {
        NavigationStack(path: router.path(3)) {
            ScrollView {
                VStack(spacing: 16) {
                    if model.loading && model.commissions.isEmpty {
                        ProgressView().padding(.top, 40)
                    } else if let error = model.error, model.commissions.isEmpty {
                        VStack(spacing: 12) {
                            ErrorBanner(message: error)
                            Button("Try again") { Task { await reload() } }
                                .buttonStyle(.borderedProminent).tint(.brandTeal)
                        }
                        .padding(.horizontal)
                    } else {
                        HStack(spacing: 12) {
                            StatCard(title: "Released", value: Money.inr(model.totalEarned),
                                     systemImage: "checkmark.seal", tint: .green) {
                                withAnimation(.snappy) { model.filter = .released }
                            }
                            StatCard(title: "Pending", value: Money.inr(model.totalPending),
                                     systemImage: "hourglass", tint: .dealioOrange) {
                                withAnimation(.snappy) { model.filter = .pending }
                            }
                        }
                        .padding(.horizontal)

                        if model.commissions.isEmpty {
                            ContentUnavailableView("No commissions yet",
                                systemImage: "indianrupeesign.circle",
                                description: Text("Earnings from your booked deals appear here."))
                                .padding(.top, 30)
                        } else {
                            filterChips
                            list
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .dealioPageBackground()
            .portalDestinations()
            .navigationTitle("Earnings")
            // Every line is now openable: the amount alone never explained how it
            // was arrived at, which is the first thing a partner asks.
            .navigationDestination(item: $openCommission) { CPCommissionDetailView(commission: $0) }
            .task { await reload() }
            .refreshable { await reload() }
        }
    }

    private func reload() async { await model.load(cpUserId: auth.user?.id ?? 0) }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EarningsFilter.allCases) { option in
                    let selected = model.filter == option
                    Button { withAnimation(.snappy) { model.filter = option } } label: {
                        Text("\(option.rawValue) · \(model.count(option))")
                            .font(.caption.weight(selected ? .bold : .medium))
                            .foregroundStyle(selected ? .white : Color.dealioTextSecondary)
                            .padding(.horizontal, 13).padding(.vertical, 7)
                            .background(selected ? Color.brandTeal : Color.dealioSurface, in: Capsule())
                            .overlay(Capsule().strokeBorder(
                                selected ? Color.brandTeal : Color.dealioCardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
        }
    }

    private var list: some View {
        VStack(spacing: 12) {
            if model.visible.isEmpty {
                ContentUnavailableView("Nothing \(model.filter.rawValue.lowercased())",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Switch the filter above to see your other commissions."))
                    .padding(.top, 20)
            } else {
                ForEach(model.visible) { commission in
                    Button { openCommission = commission } label: {
                        CommissionRow(commission: commission, released: model.isReleased(commission))
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Row

private struct CommissionRow: View {
    let commission: CpCommission
    let released: Bool

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(systemImage: released ? "checkmark.seal.fill" : "hourglass",
                      tint: released ? .green : .dealioOrange)
            VStack(alignment: .leading, spacing: 2) {
                Text(commission.customerName.nilIfEmpty ?? "—")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dealioTextPrimary)
                    .lineLimit(1)
                Text(commission.projectName.nilIfEmpty ?? "—")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 4) {
                Text(Money.inr(commission.commissionAmount))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.dealioTextPrimary)
                StatusBadge(text: commission.commissionStatus ?? "Pending",
                            color: statusColor(commission.commissionStatus))
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

/// How one commission was arrived at, and where the deal behind it stands.
///
/// A commission row's id *is* its deal id — the backend derives commissions from
/// deals — so the whole deal room is one tap from here.
struct CPCommissionDetailView: View {
    let commission: CpCommission

    private var released: Bool {
        let s = (commission.commissionStatus ?? "").lowercased()
        return s.contains("released") || s == "paid"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                amountCard
                breakdownCard
                dealCard
                NavigationLink(value: PortalRoute.cpDealDetail(commission.id)) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Open the deal").font(.subheadline.weight(.bold))
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 15)
                    .background(LinearGradient.brand,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.pressable)
            }
            .padding(16)
        }
        .dealioPageBackground()
        .navigationTitle("Commission")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var amountCard: some View {
        VStack(spacing: 10) {
            Image(systemName: released ? "checkmark.seal.fill" : "hourglass")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(tintGradient(released ? .dealioStatusGreen : .dealioOrange), in: Circle())

            Text(Money.inr(commission.commissionAmount))
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.dealioTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            StatusBadge(text: commission.commissionStatus ?? "Pending",
                        color: statusColor(commission.commissionStatus))

            if let releasedAt = commission.commissionReleasedAt?.trimmedOrNil {
                Text("Released \(releasedAt.prefix(10))")
                    .font(.caption).foregroundStyle(.secondary)
            } else if !released {
                Text("Paid out once the builder releases it.")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .cardSurface()
    }

    /// The arithmetic, spelled out. "2% of ₹80 L" answers the question the bare
    /// figure raises.
    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "How it was worked out")
            VStack(spacing: 0) {
                detailRow("Deal value", Money.inr(commission.dealValue))
                Divider()
                detailRow("Commission rate",
                          commission.commissionPercent > 0
                            ? String(format: "%.2f%%", commission.commissionPercent)
                            : "—")
                Divider()
                detailRow("Your commission", Money.inr(commission.commissionAmount), bold: true)
                if let tier = commission.cpTier?.trimmedOrNil {
                    Divider()
                    detailRow("Partner tier", tier)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var dealCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "The deal")
            VStack(spacing: 0) {
                detailRow("Buyer", commission.customerName.nilIfEmpty ?? "—")
                Divider()
                detailRow("Project", commission.projectName.nilIfEmpty ?? "—")
                if let city = commission.projectCity.nilIfEmpty {
                    Divider()
                    detailRow("City", city)
                }
                if let stage = commission.status.nilIfEmpty {
                    Divider()
                    detailRow("Stage", stage)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func detailRow(_ label: String, _ value: String, bold: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.dealioTextSecondary)
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
