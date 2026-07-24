import Foundation

nonisolated struct EntityOptionSelectionPresentation: Equatable, Sendable {
    struct Option: Equatable, Identifiable, Sendable {
        let value: String
        let displayValue: String
        let isSelected: Bool

        var id: String { value }
    }

    let selectedValue: String
    let selectedDisplayValue: String
    let options: [Option]

    init(options: [String], selectedValue: String) {
        self.selectedValue = selectedValue
        selectedDisplayValue = Self.displayValue(selectedValue)
        self.options = options.map { option in
            Option(
                value: option,
                displayValue: Self.displayValue(option),
                isSelected: option == selectedValue
            )
        }
    }

    private static func displayValue(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
