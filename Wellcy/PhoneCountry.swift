import Foundation

struct PhoneCountry: Identifiable {
    let name: String
    let flag: String
    let code: String

    var id: String { name }

    static let all = [
        PhoneCountry(name: "United States", flag: "🇺🇸", code: "+1"),
        PhoneCountry(name: "Canada", flag: "🇨🇦", code: "+1"),
        PhoneCountry(name: "United Kingdom", flag: "🇬🇧", code: "+44"),
        PhoneCountry(name: "Italy", flag: "🇮🇹", code: "+39"),
        PhoneCountry(name: "France", flag: "🇫🇷", code: "+33"),
        PhoneCountry(name: "Germany", flag: "🇩🇪", code: "+49"),
        PhoneCountry(name: "Spain", flag: "🇪🇸", code: "+34"),
        PhoneCountry(name: "Portugal", flag: "🇵🇹", code: "+351"),
        PhoneCountry(name: "Ireland", flag: "🇮🇪", code: "+353"),
        PhoneCountry(name: "Netherlands", flag: "🇳🇱", code: "+31"),
        PhoneCountry(name: "Belgium", flag: "🇧🇪", code: "+32"),
        PhoneCountry(name: "Switzerland", flag: "🇨🇭", code: "+41"),
        PhoneCountry(name: "Austria", flag: "🇦🇹", code: "+43"),
        PhoneCountry(name: "Greece", flag: "🇬🇷", code: "+30"),
        PhoneCountry(name: "Poland", flag: "🇵🇱", code: "+48"),
        PhoneCountry(name: "Sweden", flag: "🇸🇪", code: "+46"),
        PhoneCountry(name: "Norway", flag: "🇳🇴", code: "+47"),
        PhoneCountry(name: "Denmark", flag: "🇩🇰", code: "+45"),
        PhoneCountry(name: "Finland", flag: "🇫🇮", code: "+358"),
        PhoneCountry(name: "Turkey", flag: "🇹🇷", code: "+90"),
        PhoneCountry(name: "Ukraine", flag: "🇺🇦", code: "+380"),
        PhoneCountry(name: "India", flag: "🇮🇳", code: "+91"),
        PhoneCountry(name: "China", flag: "🇨🇳", code: "+86"),
        PhoneCountry(name: "Japan", flag: "🇯🇵", code: "+81"),
        PhoneCountry(name: "South Korea", flag: "🇰🇷", code: "+82"),
        PhoneCountry(name: "Australia", flag: "🇦🇺", code: "+61"),
        PhoneCountry(name: "New Zealand", flag: "🇳🇿", code: "+64"),
        PhoneCountry(name: "Brazil", flag: "🇧🇷", code: "+55"),
        PhoneCountry(name: "Mexico", flag: "🇲🇽", code: "+52"),
        PhoneCountry(name: "South Africa", flag: "🇿🇦", code: "+27"),
        PhoneCountry(name: "United Arab Emirates", flag: "🇦🇪", code: "+971"),
        PhoneCountry(name: "Singapore", flag: "🇸🇬", code: "+65")
    ]
}
