import SwiftUI

struct WordRow: View {
    let word: Word
    var body: some View {
        HStack(spacing: 12) {
            Text(word.sourceLanguage.flag)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(LexiTheme.background, in: RoundedRectangle(cornerRadius: LexiTheme.smallCornerRadius))
            VStack(alignment: .leading, spacing: 3) {
                Text(word.originalText)
                    .font(.headline)
                    .foregroundStyle(LexiTheme.primaryText)
                Text(word.summary.isEmpty ? "No translation" : word.summary)
                    .font(.subheadline).foregroundStyle(LexiTheme.secondaryText).lineLimit(1)
            }
            Spacer()
            if word.isFavorite { Image(systemName: "star.fill").foregroundStyle(LexiTheme.favorite) }
        }
        .padding(.vertical, 6)
    }
}
