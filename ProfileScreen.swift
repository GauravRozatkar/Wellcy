import SwiftUI
import PhotosUI
import UIKit

struct ProfileScreen: View {
    @AppStorage("wellcy.userName") private var userName = Sample.userName
    @AppStorage("wellcy.userSurname") private var surname = ""
    @AppStorage("wellcy.profileEmail") private var email = ""
    @AppStorage("wellcy.profilePhone") private var phoneNumber = ""
    @AppStorage("wellcy.profilePhoneCountryCode") private var phoneCountryCode = "+39"
    @AppStorage("wellcy.profilePhoneCountryName") private var phoneCountryName = "Italy"
    @AppStorage("wellcy.healthInsurance") private var insurance = ""
    @AppStorage("wellcy.profileGender") private var gender = ""
    @AppStorage("wellcy.profileWeight") private var weight = ""
    @AppStorage("wellcy.profileHeight") private var height = ""
    @AppStorage("wellcy.profilePhoto") private var photoData: Data = Data()
    @AppStorage("wellcy.appearance") private var appearance = "system"

    @State private var showingEditProfile = false
    @State private var showingPrivacy = false
    @State private var showingPassword = false
    @State private var showingPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingPasswordNotice = false

    private var profileImage: Image {
        if let image = UIImage(data: photoData) {
            Image(uiImage: image)
        } else {
            Image(systemName: "person.crop.circle.fill")
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ScreenHeader(title: "Profile", subtitle: "Your account and preferences")

                VStack(spacing: 12) {
                    Button { showingPhotoPicker = true } label: {
                        ZStack(alignment: .bottomTrailing) {
                            profileImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 104, height: 104)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Theme.amethyst.opacity(0.35), lineWidth: 2))
                            Image(systemName: "camera.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Theme.amethyst, in: Circle())
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Change profile picture")

                    Text([userName, surname].filter { !$0.isEmpty }.joined(separator: " ").isEmpty ? "Set up your profile" : [userName, surname].filter { !$0.isEmpty }.joined(separator: " "))
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text(email.isEmpty ? "Add your email address" : email)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.ink.opacity(0.65))
                    if !phoneNumber.isEmpty {
                        Text("\(PhoneCountry.all.first(where: { $0.name == phoneCountryName })?.flag ?? "🌐") \(phoneCountryCode) \(phoneNumber)")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink.opacity(0.55))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .glassCard()

                VStack(spacing: 0) {
                    settingsRow("Edit profile", detail: "Name, surname, email and insurance", icon: "person.text.rectangle") {
                        showingEditProfile = true
                    }
                    Divider().padding(.leading, 54)
                    settingsRow("Privacy and policy", detail: nil, icon: "hand.raised") {
                        showingPrivacy = true
                    }
                    Divider().padding(.leading, 54)
                    settingsRow("Change password", detail: nil, icon: "lock") {
                        showingPassword = true
                    }
                }
                .glassCard()

                VStack(alignment: .leading, spacing: 12) {
                    Label("App appearance", systemImage: "circle.lefthalf.filled")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.amethyst)
                    Picker("Appearance", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .tint(Theme.amethyst)
                }
                .glassCard()

                if !insurance.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "cross.case")
                            .foregroundStyle(Theme.amethyst)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Health insurance")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.ink.opacity(0.6))
                            Text(insurance)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        Spacer()
                    }
                    .glassCard()
                }
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .background(BackgroundView())
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    photoData = data
                }
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileSheet(name: $userName, surname: $surname, email: $email, phoneNumber: $phoneNumber, phoneCountryCode: $phoneCountryCode, phoneCountryName: $phoneCountryName, insurance: $insurance, gender: $gender, weight: $weight, height: $height)
        }
        .sheet(isPresented: $showingPrivacy) {
            PrivacyPolicySheet()
        }
        .sheet(isPresented: $showingPassword) {
            ChangePasswordSheet()
        }
        .alert("Password update", isPresented: $showingPasswordNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Password changes are not connected to an account service yet.")
        }
    }

    private func settingsRow(
        _ title: String,
        detail: String?,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.amethyst)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    if let detail {
                        Text(detail)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.ink.opacity(0.6))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.4))
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var name: String
    @Binding var surname: String
    @Binding var email: String
    @Binding var phoneNumber: String
    @Binding var phoneCountryCode: String
    @Binding var phoneCountryName: String
    @Binding var insurance: String
    @Binding var gender: String
    @Binding var weight: String
    @Binding var height: String

    @State private var nameDraft = ""
    @State private var surnameDraft = ""
    @State private var emailDraft = ""
    @State private var phoneDraft = ""
    @State private var phoneCountryCodeDraft = "+39"
    @State private var phoneCountryNameDraft = "Italy"
    @State private var insuranceDraft = ""
    @State private var genderDraft = ""
    @State private var weightDraft = ""
    @State private var heightDraft = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal information") {
                    TextField("Name", text: $nameDraft)
                        .textContentType(.givenName)
                        .textInputAutocapitalization(.words)
                    TextField("Surname", text: $surnameDraft)
                        .textContentType(.familyName)
                        .textInputAutocapitalization(.words)
                    TextField("Email", text: $emailDraft)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Phone number") {
                    Picker("Country code", selection: $phoneCountryNameDraft) {
                        ForEach(PhoneCountry.all) { country in
                            Text("\(country.flag) \(country.name) (\(country.code))")
                                .tag(country.name)
                        }
                    }
                    .onChange(of: phoneCountryNameDraft) { _, name in
                        phoneCountryCodeDraft = PhoneCountry.all.first(where: { $0.name == name })?.code ?? "+39"
                    }
                    TextField("Phone number", text: $phoneDraft)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .onChange(of: phoneDraft) { _, value in
                            let digits = value.filter(\.isNumber)
                            if digits != value {
                                phoneDraft = digits
                            }
                        }
                }
                Section("Health insurance") {
                    TextField("Provider or policy name", text: $insuranceDraft)
                }
                Section("Health details") {
                    Picker("Gender", selection: $genderDraft) {
                        Text("Not specified").tag("")
                        Text("Female").tag("Female")
                        Text("Male").tag("Male")
                        Text("Non-binary").tag("Non-binary")
                        Text("Prefer not to say").tag("Prefer not to say")
                    }
                    TextField("Weight (kg)", text: $weightDraft)
                        .keyboardType(.decimalPad)
                    TextField("Height (cm)", text: $heightDraft)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        name = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        surname = surnameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        email = emailDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        phoneCountryCode = PhoneCountry.all.first(where: { $0.name == phoneCountryNameDraft })?.code ?? "+39"
                        phoneCountryName = phoneCountryNameDraft
                        phoneNumber = phoneDraft.filter(\.isNumber)
                        insurance = insuranceDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        gender = genderDraft
                        weight = weightDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        height = heightDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                }
            }
            .onAppear {
                nameDraft = name
                surnameDraft = surname
                emailDraft = email
                phoneDraft = phoneNumber.filter(\.isNumber)
                phoneCountryNameDraft = phoneCountryName
                phoneCountryCodeDraft = PhoneCountry.all.first(where: { $0.name == phoneCountryName })?.code ?? phoneCountryCode
                insuranceDraft = insurance
                genderDraft = gender
                weightDraft = weight
                heightDraft = height
            }
        }
    }
}

private struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Your privacy matters")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Profile details and preferences are stored locally on this device. Wellcy does not currently send this profile information to an online account or health service.")
                    Text("Avoid entering information you do not want stored on this device. You can remove or change profile details from Edit profile.")
                    Text("This in-app summary is not a substitute for a published privacy policy.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Privacy and policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct ChangePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Change password") {
                    SecureField("Current password", text: $currentPassword)
                    SecureField("New password", text: $newPassword)
                    SecureField("Confirm new password", text: $confirmPassword)
                }
                Section {
                    Text("Password changes require an account service, which is not connected in this app yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Change password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
