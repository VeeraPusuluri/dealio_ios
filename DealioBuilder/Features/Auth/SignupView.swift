import SwiftUI

/// The same self-service roles the web/Android signup offers.
private struct RoleOption {
    let value: String
    let label: String
    let color: Color
}

private let signupRoles: [RoleOption] = [
    RoleOption(value: "CUSTOMER", label: "Customer",        color: .dealioTeal),
    RoleOption(value: "CP",       label: "Channel Partner", color: .dealioOrange),
    RoleOption(value: "BUILDER",  label: "Builder",         color: .dealioNavy),
    RoleOption(value: "BANK",     label: "Bank",            color: Color(hex: 0x16A34A)),
    RoleOption(value: "NRI",      label: "NRI",             color: Color(hex: 0x7C3AED)),
]

struct SignupView: View {
    @EnvironmentObject private var auth: AuthStore
    var onGoToLogin: () -> Void

    @State private var fullName = ""
    @State private var role = "CUSTOMER"
    @State private var countryCode = "+91"
    @State private var phone = ""
    @State private var referralCode = ""
    @State private var otp = ""

    @State private var step: AuthStep = .details
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var maskedPhone: String?
    @State private var demoCode: String?
    @State private var resendSecondsLeft = 0

    @FocusState private var nameFocused: Bool
    @FocusState private var referralFocused: Bool

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        AuthScaffold(
            headline: step == .details ? "Create your account" : "Verify your phone",
            subtitle: step == .details
                ? "Join Dealio — free forever, for every role."
                : "We sent a 6-digit code to \(maskedPhone ?? "your phone")."
        ) {
            if step == .details {
                detailsStep
            } else {
                otpStep
            }

            Spacer().frame(height: 28)

            HStack(spacing: 2) {
                Text("Already have an account?")
                    .font(.subheadline)
                    .foregroundColor(.dealioTextSecondary)
                Button("Sign in", action: onGoToLogin)
                    .font(.subheadline.weight(.semibold))
                    .tint(.dealioTeal)
            }
            .frame(maxWidth: .infinity)
        }
        .onReceive(ticker) { _ in
            if resendSecondsLeft > 0 { resendSecondsLeft -= 1 }
        }
    }

    // MARK: Steps

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            DealioField(label: "Full name", focused: nameFocused) {
                TextField("Your name", text: $fullName)
                    .textInputAutocapitalization(.words)
                    .focused($nameFocused)
            }
            .disabled(loading)
            Spacer().frame(height: 20)

            Text("I am a…")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.dealioTextSecondary)
            Spacer().frame(height: 8)
            FlowLayout(spacing: 8) {
                ForEach(signupRoles, id: \.value) { item in
                    RoleChip(label: item.label, color: item.color, selected: role == item.value, enabled: !loading) {
                        role = item.value
                    }
                }
            }
            Spacer().frame(height: 20)

            PhoneField(countryCode: $countryCode, phone: $phone, enabled: !loading)
            Spacer().frame(height: 20)

            DealioField(label: "Referral code (optional)", focused: referralFocused) {
                TextField("CP-JOHN-42", text: $referralCode)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .focused($referralFocused)
                    .onChange(of: referralCode) { _, new in
                        let upper = new.uppercased()
                        if upper != new { referralCode = upper }
                    }
            }
            .disabled(loading)
            Spacer().frame(height: 28)

            DealioButton(
                title: "Send code",
                loading: loading,
                enabled: phone.count >= 6 && !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                send()
            }
            AuthErrorText(message: errorMessage)
        }
    }

    private var otpStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            OtpInput(value: $otp, enabled: !loading)
            DemoCodeHint(demoCode: demoCode) { otp = $0 }
            Spacer().frame(height: 24)
            DealioButton(title: "Verify & create account", loading: loading, enabled: otp.count == 6) {
                verify()
            }
            AuthErrorText(message: errorMessage)
            Spacer().frame(height: 16)

            HStack {
                Button("Edit details") { backToDetails() }
                    .font(.subheadline)
                    .tint(.dealioTextSecondary)
                Spacer()
                if resendSecondsLeft > 0 {
                    Text("Resend in \(resendSecondsLeft)s")
                        .font(.subheadline)
                        .foregroundColor(.dealioTextSecondary)
                } else {
                    Button("Resend code") { otp = ""; send() }
                        .font(.subheadline.weight(.semibold))
                        .tint(.dealioTeal)
                }
            }
        }
    }

    // MARK: Actions

    private func send() {
        errorMessage = nil
        loading = true
        Task {
            do {
                let result = try await auth.sendOTP(isSignup: true, countryCode: countryCode, phone: phone)
                maskedPhone = result.maskedPhone
                demoCode = result.demoCode
                step = .otp
                resendSecondsLeft = 30
            } catch {
                errorMessage = authMessage(error)
            }
            loading = false
        }
    }

    private func verify() {
        errorMessage = nil
        loading = true
        Task {
            do {
                try await auth.verifySignup(
                    phone: phone,
                    otp: otp,
                    fullName: fullName,
                    role: role,
                    referralCode: referralCode
                )
            } catch {
                errorMessage = authMessage(error)
            }
            loading = false
        }
    }

    private func backToDetails() {
        otp = ""
        errorMessage = nil
        demoCode = nil
        resendSecondsLeft = 0
        step = .details
    }
}
