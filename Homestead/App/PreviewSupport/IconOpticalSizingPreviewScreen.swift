#if DEBUG
import SwiftUI

struct IconOpticalSizingPreviewScreen: View {
    private let comparisonPointSize: CGFloat = 18
    private let iconFrame: CGFloat = 52
    private let scalePointSizes: [CGFloat] = [14, 18, 22, 26]
    private let comparisons = [
        IconOpticalComparison(title: "Home", sfSymbol: "house.fill", mdiName: "home"),
        IconOpticalComparison(title: "Walking", sfSymbol: "figure.walk", mdiName: "walk"),
        IconOpticalComparison(title: "Sunrise", sfSymbol: "sunrise.fill", mdiName: "weather-sunset-up"),
        IconOpticalComparison(title: "Calendar", sfSymbol: "calendar.badge.clock", mdiName: "calendar-clock"),
        IconOpticalComparison(title: "Light", sfSymbol: "lightbulb.fill", mdiName: "lightbulb")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    matchedPairGrid
                    houseScaleGrid
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Icon Optical Sizing")
        }
    }

    private var matchedPairGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading(
                title: "Matched Pairs",
                detail: "Both columns request \(Int(comparisonPointSize)) pt."
            )

            Grid(alignment: .center, horizontalSpacing: 14, verticalSpacing: 12) {
                columnHeadings

                ForEach(comparisons) { comparison in
                    GridRow {
                        Text(comparison.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        iconCell(icon: comparison.sfIcon, pointSize: comparisonPointSize)
                        iconCell(icon: comparison.mdiIcon, pointSize: comparisonPointSize)
                    }
                }
            }
        }
    }

    private var houseScaleGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading(
                title: "House Scale Ladder",
                detail: "Compare the same semantic shape across common sizes."
            )

            Grid(alignment: .center, horizontalSpacing: 14, verticalSpacing: 12) {
                columnHeadings

                ForEach(scalePointSizes, id: \.self) { pointSize in
                    GridRow {
                        Text("\(Int(pointSize)) pt")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        iconCell(icon: IconOpticalComparison.house.sfIcon, pointSize: pointSize)
                        iconCell(icon: IconOpticalComparison.house.mdiIcon, pointSize: pointSize)
                    }
                }
            }
        }
    }

    private var columnHeadings: some View {
        GridRow {
            Color.clear
                .frame(height: 1)

            Text("SF Symbol")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("MDI")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func sectionHeading(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func iconCell(icon: ResolvedIcon, pointSize: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 1)

            Rectangle()
                .fill(Color.secondary.opacity(0.12))
                .frame(height: 1)

            HomesteadIconView(icon: icon, pointSize: pointSize)
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: iconFrame, height: iconFrame)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct IconOpticalComparison: Identifiable {
    static let house = IconOpticalComparison(title: "Home", sfSymbol: "house.fill", mdiName: "home")

    let title: String
    let sfSymbol: String
    let mdiName: String

    var id: String { mdiName }

    var sfIcon: ResolvedIcon {
        .sfSymbol(sfSymbol, provenance: .homesteadSemanticMapping)
    }

    // Resolve directly to MDI so the curated bridge cannot substitute an SF Symbol in this comparison fixture.
    var mdiIcon: ResolvedIcon {
        ResolvedIcon(
            asset: .materialDesign(mdiName),
            fallbackSFSymbol: sfSymbol,
            provenance: .haExplicitIcon,
            sourceIdentifier: "mdi:\(mdiName)"
        )
    }
}

#Preview("Icon Optical Sizing") {
    IconOpticalSizingPreviewScreen()
        .preferredColorScheme(.dark)
}
#endif
