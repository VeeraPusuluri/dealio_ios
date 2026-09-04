import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthStore
    var onGoToSignup: () -> Void

    @State private var countryCode = "+91"
    @State private var phone = ""
    @State private var otp = ""
    @State private var step: AuthStep = .details
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var maskedPhone: String?
    @State private var demoCode: String?
    @State private var resendSecondsLeft = 0
    @State private var role = Roles.customer.value
    /// The account's real role, set when sign-in was attempted under a different
    /// one. Lets the screen offer a one-tap correction instead of making the
    /// user hunt for the right pill.
    @State private var mismatchedRole: String?
    /// Set once the phone field has been left, so the number is not marked wrong
    /// while it is still being typed.
    @State private var phoneTouched = false
    /// A wrong code shakes the boxes; cleared as soon as the person edits.
    @State private var codeRejected = false
    /// Held for a beat after a successful verify so the button can confirm.
    @State private var signedIn = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var phoneValidation: FieldValidation { .phone(phone) }
    private var canSend: Bool { phoneValidation.isValid && !phone.isEmpty }

    var body: some View {
        AuthScaffold(
            headline: step == .details ? "Welcome back" : "Enter the code",
            subtitle: step == .details
                ? "Sign in with your phone number to continue."
                : "We sent a 6-digit code to \(maskedPhone ?? "your phone").",
            phase: step == .details ? .details : .verify,
            onBack: step == .otp ? { withAnimation(.snappy) { backToDetails() } } : nil
        ) {
            // Says why the sign-in screen is showing when the user did not ask
            // for it — a session that expired mid-use otherwise looks like the
            // app logged them out at random.
            if let notice = auth.expiryNotice, step == .details {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(Color.dealioOrange)
                    Text(notice)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.dealioTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.dealioOrange.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer().frame(height: 18)
            }

            Group {
                if step == .details {
                    detailsStep
                } else {
                    otpStep
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            Spacer().frame(height: 26)

            HStack(spacing: 4) {
                Text("New to Dealio?")
                    .font(.subheadline)
                    .foregroundStyle(Color.dealioTextSecondary)
                Button("Create an account", action: onGoToSignup)
                    .font(.subheadline.weight(.semibold))
                    .tint(.dealioTeal)
                    .disabled(loading || signedIn)
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
            Text("I'm signing in as")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.dealioTextSecondary)
            Spacer().frame(height: 10)
            RoleSelector(roles: Roles.signin, selection: $role, showTagline: true)
                .disabled(loading)
            Spacer().frame(height: 22)

            PhoneField(
                countryCode: $countryCode,
                phone: $phone,
                enabled: !loading,
                error: phoneTouched ? phoneValidation.error : nil,
                onSubmit: { if canSend { send() } },
                onPhoneBlur: { phoneTouched = true }
            )
            Spacer().frame(height: 24)

            DealioButton(title: "Send code", loading: loading, enabled: canSend) {
                phoneTouched = true
                guard canSend else { return }
                send()
            }
            AuthErrorText(message: errorMessage)

            // The pre-flight knows the real role, so the fix is one tap rather
            // than a hunt back through the pills.
            if let mismatched = mismatchedRole, let actual = Roles.forValue(mismatched) {
                Spacer().frame(height: 12)
                Button {
                    role = actual.value
                    mismatchedRole = nil
                    errorMessage = nil
                    send()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: actual.icon).font(.caption)
                        Text("Sign in as \(actual.label) instead")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(actual.color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(actual.color.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(actual.color.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.pressable)
            }
        }
    }

    private var otpStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            OtpInput(value: $otp, enabled: !loading && !signedIn, invalid: codeRejected) {
                verify()
            }
            .onChange(of: otp) { _, _ in
                if codeRejected { codeRejected = false; errorMessage = nil }
            }
            DemoCodeHint(demoCode: demoCode) { otp = $0 }
            Spacer().frame(height: 24)

            DealioButton(title: "Verify & sign in", loading: loading,
                         enabled: otp.count == 6, succeeded: signedIn,
                         successTitle: "Signed in") {
                verify()
            }
            AuthErrorText(message: errorMessage)
            Spacer().frame(height: 18)

            HStack {
                Button("Change number") { withAnimation(.snappy) { backToDetails() } }
                    .font(.subheadline)
                    .tint(Color.dealioTextSecondary)
                    .disabled(loading || signedIn)
                Spacer()
                if resendSecondsLeft > 0 {
                    Text("Resend in \(resendSecondsLeft)s")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Color.dealioTextSecondary)
                } else {
                    Button("Resend code") { otp = ""; codeRejected = false; send() }
                        .font(.subheadline.weight(.semibold))
                        .tint(.dealioTeal)
                        .disabled(loading || signedIn)
                }
            }
        }
    }

    // MARK: Actions

    private func send() {
        errorMessage = nil
        mismatchedRole = nil
        loading = true
        Task {
            // Ask whether an account exists — and under which role — before an
            // SMS is spent on the number. A nil answer means the check could not
            // run, and the send goes ahead: verify still rejects unregistered
            // numbers, so a stale backend costs one avoidable SMS, not a hole.
            if let lookup = await auth.phoneLookup(countryCode: countryCode, phone: phone),
               let problem = auth.signInProblem(lookup, pickedRole: role) {
                errorMessage = problem.message
                mismatchedRole = problem.actualRole
                loading = false
                return
            }
            do {
                let result = try await auth.sendOTP(isSignup: false, countryCode: countryCode, phone: phone)
                maskedPhone = result.maskedPhone
                demoCode = result.demoCode
                withAnimation(.snappy) { step = .otp }
                resendSecondsLeft = 30
            } catch {
                errorMessage = authMessage(error)
            }
            loading = false
        }
    }

    private func verify() {
        guard otp.count == 6, !loading, !signedIn else { return }
        errorMessage = nil
        codeRejected = false
        loading = true
        Task {
            do {
                try await auth.verifyLogin(phone: phone, otp: otp)
                // Confirm before the portal replaces the screen — a sign-in that
                // simply vanishes leaves people unsure it worked.
                loading = false
                withAnimation { signedIn = true }
            } catch {
                errorMessage = authMessage(error)
                codeRejected = true
                loading = false
            }
        }
    }

    private func backToDetails() {
        otp = ""
        errorMessage = nil
        demoCode = nil
        codeRejected = false
        resendSecondsLeft = 0
        step = .details
    }
}
