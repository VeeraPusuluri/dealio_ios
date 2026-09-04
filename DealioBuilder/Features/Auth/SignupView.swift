import SwiftUI

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
    @State private var submitted = false
    @State private var phoneTouched = false
    @State private var nameTouched = false
    @State private var codeRejected = false
    @State private var created = false

    @FocusState private var nameFocused: Bool
    @FocusState private var referralFocused: Bool

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var nameValidation: FieldValidation { .required(fullName, "Your name") }
    private var phoneValidation: FieldValidation { .phone(phone) }
    private var canSend: Bool { nameValidation.isValid && phoneValidation.isValid }

    var body: some View {
        AuthScaffold(
            headline: step == .details ? "Create your account" : "Verify your phone",
            subtitle: step == .details
                ? "Join Dealio — free forever, for every role."
                : "We sent a 6-digit code to \(maskedPhone ?? "your phone").",
            phase: step == .details ? .details : .verify,
            onBack: step == .otp ? { withAnimation(.snappy) { backToDetails() } } : nil
        ) {
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
                Text("Already have an account?")
                    .font(.subheadline)
                    .foregroundStyle(Color.dealioTextSecondary)
                Button("Sign in", action: onGoToLogin)
                    .font(.subheadline.weight(.semibold))
                    .tint(.dealioTeal)
                    .disabled(loading || created)
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
            DealioField(label: "Full name", focused: nameFocused,
                        icon: "person.fill",
                        error: (nameTouched || submitted) ? nameValidation.error : nil) {
                TextField("Your name", text: $fullName)
                    .textInputAutocapitalization(.words)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .focused($nameFocused)
            }
            .disabled(loading)
            .onChange(of: nameFocused) { was, _ in if was { nameTouched = true } }
            Spacer().frame(height: 20)

            Text("I am a…")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.dealioTextSecondary)
            Spacer().frame(height: 10)
            RoleSelector(roles: Roles.signup, selection: $role, showTagline: true)
                .disabled(loading)
            Spacer().frame(height: 22)

            PhoneField(
                countryCode: $countryCode,
                phone: $phone,
                enabled: !loading,
                error: (phoneTouched || submitted) ? phoneValidation.error : nil,
                onSubmit: { if canSend { send() } },
                onPhoneBlur: { phoneTouched = true }
            )
            Spacer().frame(height: 20)

            DealioField(label: "Referral code (optional)", focused: referralFocused,
                        icon: "gift.fill") {
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
            Spacer().frame(height: 26)

            DealioButton(title: "Send code", loading: loading, enabled: canSend) {
                submitted = true
                guard canSend else { return }
                send()
            }
            AuthErrorText(message: errorMessage)
        }
    }

    private var otpStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            OtpInput(value: $otp, enabled: !loading && !created, invalid: codeRejected) {
                verify()
            }
            .onChange(of: otp) { _, _ in
                if codeRejected { codeRejected = false; errorMessage = nil }
            }
            DemoCodeHint(demoCode: demoCode) { otp = $0 }
            Spacer().frame(height: 24)

            DealioButton(title: "Verify & create account", loading: loading,
                         enabled: otp.count == 6, succeeded: created,
                         successTitle: "Account created") {
                verify()
            }
            AuthErrorText(message: errorMessage)
            Spacer().frame(height: 18)

            HStack {
                Button("Edit details") { withAnimation(.snappy) { backToDetails() } }
                    .font(.subheadline)
                    .tint(Color.dealioTextSecondary)
                    .disabled(loading || created)
                Spacer()
                if resendSecondsLeft > 0 {
                    Text("Resend in \(resendSecondsLeft)s")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Color.dealioTextSecondary)
                } else {
                    Button("Resend code") { otp = ""; codeRejected = false; send() }
                        .font(.subheadline.weight(.semibold))
                        .tint(.dealioTeal)
                        .disabled(loading || created)
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
                withAnimation(.snappy) { step = .otp }
                resendSecondsLeft = 30
            } catch {
                errorMessage = authMessage(error)
            }
            loading = false
        }
    }

    private func verify() {
        guard otp.count == 6, !loading, !created else { return }
        errorMessage = nil
        codeRejected = false
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
                loading = false
                withAnimation { created = true }
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
