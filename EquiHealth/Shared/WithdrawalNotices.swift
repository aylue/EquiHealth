import EquiCore
import SwiftUI

/// Running withdrawal periods as clear notices (F-BEH-09). For food-producing horses the food
/// withdrawal is highlighted additionally (F-BEH-10).
struct WithdrawalNoticeRows: View {
  let horse: Horse

  var body: some View {
    ForEach(horse.activeWithdrawals()) { withdrawal in
      WithdrawalNoticeRow(withdrawal: withdrawal, isFoodProducing: horse.isFoodProducingAnimal == true)
    }
  }
}

struct WithdrawalNoticeRow: View {
  let withdrawal: ActiveWithdrawal
  let isFoodProducing: Bool

  private var isHighlighted: Bool { withdrawal.kind == .food && isFoodProducing }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: isHighlighted ? "exclamationmark.triangle.fill" : "hourglass")
        .foregroundStyle(isHighlighted ? Color.red : Color.categoryMedications)
        .font(.title3)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text("\(withdrawal.kind.title) bis \(withdrawal.endDate.formatted(.dateTime.day().month(.wide)))")
          .font(.subheadline.weight(.semibold))
        Text(withdrawal.medication.productName)
          .font(.caption)
          .foregroundStyle(.secondary)
        if isHighlighted {
          Text("Schlachttier laut Equidenpass")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.red)
        }
      }
    }
    .padding(.vertical, 2)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("withdrawal.\(withdrawal.kind.rawValue)")
  }
}
