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
            PhoneField(countryCode: $countryCode, phone: $phone, enabled: !loading)
            Spacer().frame(height: 24)
            DealioButton(title: "Send code", loading: loading, enabled: phone.count >= 6) {
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
        loading = true
        Task {
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
