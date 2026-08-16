import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthStore
    var onGoToSignup: () -> Void

    @State private var role = RoleCustomer
    @State private var countryCode = "+91"
    @State private var phone = ""
    @State private var otp = ""
    @State private var step: AuthStep = .details
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var maskedPhone: String?
    @State private var demoCode: String?
    @State private var resendSecondsLeft = 0
    /// The role this number is really registered as, when it isn't the one
    /// picked. Drives the "Continue as …" shortcut.
    @State private var mismatchedRole: String?

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// The hero glows in the *portal's* colour, not simply the role's, so the
    /// surface someone signs in on is the one they land in. Only the hero: the
    /// card's own controls stay on the role's brand colour, which reads on white.
    private var accentOnDark: Color { heroAccentFor(role) }

    var body: some View {
        AuthScaffold(
            headline: step == .details ? "Welcome back" : "Enter the code",
            subtitle: step == .details
                ? "Pick your account type, then sign in with your phone number."
                : "We sent a 6-digit code to \(maskedPhone ?? "your phone").",
            eyebrow: step == .details ? "Sign in" : "Step 2 · Verify",
            accentOnDark: accentOnDark,
            step: step == .details ? 1 : 2,
            heroTrailing: { RoleHeroChip(role: role, accentOnDark: accentOnDark) }
        ) {
            if step == .details {
                detailsStep
            } else {
                otpStep
            }

            if AppConfig.signupEnabled {
                Spacer().frame(height: 28)

                HStack(spacing: 2) {
                    Text("New to Dealio?")
                        .font(.subheadline)
                        .foregroundColor(.dealioTextSecondary)
                    Button("Create an account", action: onGoToSignup)
                        .font(.subheadline.weight(.semibold))
                        .tint(.dealioTeal)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onReceive(ticker) { _ in
            if resendSecondsLeft > 0 { resendSecondsLeft -= 1 }
        }
    }

    // MARK: Steps

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            FieldGroupLabel("Sign in as")
            Spacer().frame(height: 10)
            RolePillRow(roles: SigninRoles, selected: $role, enabled: !loading)
                .onChange(of: role) { _, _ in clearError() }
            Spacer().frame(height: 10)
            Text(role.tagline)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(role.color)
                .animation(.snappy(duration: 0.22), value: role)

            Spacer().frame(height: 22)

            PhoneField(countryCode: $countryCode, phone: $phone, enabled: !loading)
                .onChange(of: phone) { _, _ in clearError() }
                .onChange(of: countryCode) { _, _ in clearError() }

            Spacer().frame(height: 24)
            DealioButton(title: "Send code", loading: loading, enabled: phone.count >= 6) {
                send()
            }
            AuthErrorText(message: errorMessage)

            // The pre-flight knows which role this number really is, so offer
            // the fix rather than leaving the user to guess which pill to try
            // next. Only for roles the picker has: an admin number still gets
            // the "registered as an Admin account" error but no shortcut in,
            // which would put back the path the Admin pill was removed to close.
            if let suggested = roleFor(mismatchedRole), suggested.isSignInOption {
                Spacer().frame(height: 12)
                SwitchRoleAction(role: suggested) {
                    role = suggested
                    clearError()
                    send(as: suggested)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy(duration: 0.25), value: mismatchedRole)
    }

    private var otpStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            OtpInput(value: $otp, enabled: !loading)
            DemoCodeHint(demoCode: demoCode) { otp = $0 }
            Spacer().frame(height: 24)
            DealioButton(title: "Verify & sign in", loading: loading, enabled: otp.count == 6) {
                verify()
            }
            AuthErrorText(message: errorMessage)
            Spacer().frame(height: 16)

            HStack {
                Button("Change number") { backToDetails() }
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

    private func send(as signingInAs: DealioRole? = nil) {
        let wanted = signingInAs ?? role
        clearError()
        loading = true
        Task {
            if await preflightFails(as: wanted) {
                loading = false
                return
            }
            do {
                let result = try await auth.sendOTP(isSignup: false, countryCode: countryCode, phone: phone)
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

    /// Checks the number against the picked role before an OTP is spent on it.
    ///
    /// Returns true when the caller should stop. A lookup that itself fails is
    /// *not* a stop: the endpoint is an optimisation, and an installed app
    /// outlives any one backend deploy — verify still rejects unregistered and
    /// suspended numbers, so a failure here costs an avoidable SMS, not a check.
    private func preflightFails(as wanted: DealioRole) async -> Bool {
        guard let lookup = try? await auth.lookup(countryCode: countryCode, phone: phone) else {
            return false
        }
        // Only enforce roles the picker can express. The backend also has
        // VENDOR/LANDOWNER/REFERRAL, which have no pill — blocking those would
        // lock them out of the app entirely.
        let actual = roleFor(lookup.role)
        let mismatched = actual != nil && actual!.value != wanted.value

        if !lookup.exists {
            errorMessage = "No account found for this number. Create an account first."
        } else if lookup.suspended {
            errorMessage = "Account suspended. Please contact support."
        } else if mismatched {
            errorMessage = "This number is registered as a \(actual!.label) account."
            mismatchedRole = actual!.value
        } else {
            return false
        }
        return true
    }

    private func verify() {
        clearError()
        loading = true
        Task {
            do {
                try await auth.verifyLogin(phone: phone, otp: otp)
            } catch {
                errorMessage = authMessage(error)
            }
            loading = false
        }
    }

    private func clearError() {
        errorMessage = nil
        mismatchedRole = nil
    }

    private func backToDetails() {
        otp = ""
        demoCode = nil
        resendSecondsLeft = 0
        step = .details
        clearError()
    }
}
