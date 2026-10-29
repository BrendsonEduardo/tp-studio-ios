import SwiftUI

struct RundownListView: View {
    @EnvironmentObject var engine: BroadcastEngine
    @Binding var selectedTab: Int

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Cabeçalho da Escaleta
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ESCALETA DE LAUDAS / BLOCOS")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(.white)
                        Text("Toque em uma matéria para carregá-la no Teleprompter")
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.6))
                    }
                    Spacer()
                    Button {
                        _ = engine.addNewStory()
                        selectedTab = 3 // Vai para a aba Editor
                    } label: {
                        Text("+ Nova Lauda")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(red: 0.04, green: 0.52, blue: 1.0))
                            .cornerRadius(10)
                    }
                }
                .modifier(CockpitCardModifier())

                // Lista de Matérias da Escaleta
                ForEach(Array(engine.stories.enumerated()), id: \.element.id) { index, story in
                    let isCurrent = (story.id == engine.state.storyId)
                    let durationSecs = story.estimatedSeconds(atSpeed: engine.state.speed)
                    let durationStr = String(format: "%02d:%02d", durationSecs / 60, durationSecs % 60)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("#\(index + 1) • \(story.bloco)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(white: 0.65))
                            Spacer()
                            Text("\(story.cam) • \(story.cleanWordCount) pal. (\(durationStr))")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(white: 0.22))
                                .cornerRadius(6)
                        }

                        Text(story.retranca)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(.white)

                        Text(story.text.replacingOccurrences(of: "\n", with: " "))
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.62))
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            Button {
                                engine.selectStory(id: story.id, resetScroll: true)
                                selectedTab = 0 // Abre a aba Prompter
                            } label: {
                                Text(isCurrent ? "● NA AGULHA (NO AR)" : "▶ Carregar no Prompter")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(isCurrent ? Color(red: 0.29, green: 0.87, blue: 0.5) : .white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        isCurrent
                                            ? Color(red: 0.13, green: 0.77, blue: 0.37).opacity(0.22)
                                            : Color.white.opacity(0.08)
                                    )
                                    .cornerRadius(8)
                            }

                            Button {
                                engine.selectStory(id: story.id, resetScroll: false)
                                selectedTab = 3 // Abre o Editor
                            } label: {
                                Text("✏️ Editar")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(8)
                            }

                            Button {
                                engine.deleteStories(at: IndexSet(integer: index))
                            } label: {
                                Text("🗑")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color.red.opacity(0.18))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        isCurrent
                            ? Color(red: 0.22, green: 0.74, blue: 0.97).opacity(0.14)
                            : Color(red: 0.06, green: 0.09, blue: 0.16)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isCurrent
                                    ? Color(red: 0.22, green: 0.74, blue: 0.97)
                                    : Color.white.opacity(0.1),
                                lineWidth: isCurrent ? 1.5 : 1
                            )
                    )
                    .cornerRadius(12)
                }
            }
            .padding(12)
        }
        .background(Color(red: 0.03, green: 0.04, blue: 0.07))
    }
}

