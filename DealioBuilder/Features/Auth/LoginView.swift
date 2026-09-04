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

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        AuthScaffold(
            headline: step == .details ? "Welcome back" : "Enter the code",
            subtitle: step == .details
                ? "Sign in with your phone number to continue."
                : "We sent a 6-digit code to \(maskedPhone ?? "your phone")."
        ) {
            if step == .details {
                detailsStep
            } else {
                otpStep
            }

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
        .onReceive(ticker) { _ in
            if resendSecondsLeft > 0 { resendSecondsLeft -= 1 }
        }
    }

    // MARK: Steps

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("I'm signing in as")
                .font(.caption.weight(.semibold))
                .foregroundColor(.dealioTextSecondary)
            Spacer().frame(height: 8)
            RoleSelector(roles: Roles.signin, selection: $role, showTagline: true)
                .disabled(loading)
            Spacer().frame(height: 20)

            PhoneField(countryCode: $countryCode, phone: $phone, enabled: !loading)
            Spacer().frame(height: 24)
            DealioButton(title: "Send code", loading: loading, enabled: phone.count >= 6) {
                send()
            }
            AuthErrorText(message: errorMessage)

            // The pre-flight knows the real role, so the fix is one tap rather
            // than a hunt back through the pills.
            if let mismatched = mismatchedRole, let actual = Roles.forValue(mismatched) {
                Spacer().frame(height: 10)
                Button("Sign in as \(actual.label) instead") {
                    role = actual.value
                    mismatchedRole = nil
                    errorMessage = nil
                    send()
                }
                .font(.subheadline.weight(.semibold))
                .tint(actual.color)
            }
        }
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
                try await auth.verifyLogin(phone: phone, otp: otp)
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
