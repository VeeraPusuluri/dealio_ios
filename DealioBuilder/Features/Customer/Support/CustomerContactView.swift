import SwiftUI
import UIKit

struct CustomerContactView: View {
    @Environment(\.openURL) private var openURL
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var city = ""
    @State private var interest = ""
    @State private var message = ""
    @State private var submitted = false

    private let cities = ["Hyderabad", "Bengaluru", "Mumbai", "Pune", "Delhi NCR", "Chennai"]
    private let interests = ["Buy a home", "Schedule a site visit", "Loan assistance", "Investment query", "NRI purchase", "Other"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tell us what you're looking for").font(.title3.weight(.bold))
                    Text("Our team will reach out within 24 hours.").font(.subheadline).foregroundStyle(.secondary)
                }

                if submitted {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(.green)
                        Text("Message received!").font(.headline)
                        Text("Thank you\(name.isEmpty ? "" : ", \(name)"). We'll be in touch within 24 hours.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("Send another") { submitted = false; name = ""; phone = ""; email = ""; message = "" }
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity).padding(20).cardSurface()
                } else {
                    VStack(spacing: 12) {
                        field("Full name *", $name, .default)
                        field("Phone *", $phone, .phonePad)
                        field("Email", $email, .emailAddress)
                        Picker("Preferred city", selection: $city) {
                            Text("Select city").tag("")
                            ForEach(cities, id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                        Picker("I'm interested in", selection: $interest) {
                            Text("Select topic").tag("")
                            ForEach(interests, id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Message").font(.caption).foregroundStyle(.secondary)
                            TextEditor(text: $message).frame(minHeight: 90).font(.subheadline)
                                .padding(6).background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                        }
                        Button { submitted = true } label: {
                            Text("Send message").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 13)
                                .background(name.isEmpty || phone.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.4)) : AnyShapeStyle(LinearGradient.brand), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                        }.disabled(name.isEmpty || phone.isEmpty)
                        Button { if let u = Share.whatsAppURL(phone: nil, text: "Hi, I'm looking for a property. Please get in touch.") { openURL(u) } } label: {
                            Label("Chat on WhatsApp", systemImage: "message.fill").font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 11)
                                .background(Color(red: 0.14, green: 0.83, blue: 0.4).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(Color(red: 0.12, green: 0.66, blue: 0.33))
                        }
                    }
                    .padding(16).cardSurface()
                }

                // Contact details
                VStack(spacing: 0) {
                    contactRow("phone.fill", "Call us", "+91 40 6688 0000", "Mon–Sat, 9am–7pm IST") { if let u = URL(string: "tel:+914066880000") { openURL(u) } }
                    Divider()
                    contactRow("envelope.fill", "Email us", "hello@dealio.in", "We reply within 24 hours") { if let u = URL(string: "mailto:hello@dealio.in") { openURL(u) } }
                    Divider()
                    contactRow("mappin.and.ellipse", "Visit us", "Hyderabad, Telangana", "By appointment", nil)
                }
                .padding(.horizontal, 16).cardSurface()
            }
            .padding()
        }
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Contact Us")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func field(_ label: String, _ text: Binding<String>, _ keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField("", text: text).keyboardType(keyboard)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
        }
    }
    private func contactRow(_ icon: String, _ label: String, _ value: String, _ sub: String, _ action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).foregroundStyle(.brandTeal).frame(width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(sub).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(.vertical, 12)
        }.buttonStyle(.plain).disabled(action == nil)
    }
}
