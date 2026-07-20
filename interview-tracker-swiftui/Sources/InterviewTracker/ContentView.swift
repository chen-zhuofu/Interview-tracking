import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var language: LanguageStore
    @StateObject private var chatViewModel = ChatViewModel()
    @StateObject private var navigation = NavigationStore()
    @State private var warpTrigger = 0

    var body: some View {
        GeometryReader { geo in
            let panelWidth = max(260, geo.size.width * 0.25)

            ZStack(alignment: .bottom) {
                DeepSpaceBackground(warpTrigger: warpTrigger)

                VStack(spacing: 0) {
                    topBar
                    overviewDetail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(navigation.current)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.985)),
                            removal: .opacity.combined(with: .scale(scale: 1.015))
                        ))
                }
                .animation(.easeOut(duration: 0.45), value: navigation.current)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: chatViewModel.isExpanded ? 390 : 78)
                }

                if navigation.isCalendarPanelOpen {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture {
                            navigation.closeCalendar()
                        }
                        .transition(.opacity)

                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        CalendarView(isPanel: true)
                            .frame(width: panelWidth)
                            .frame(maxHeight: .infinity)
                            .background(AppTheme.card)
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(AppTheme.stroke)
                                    .frame(width: 1)
                            }
                            .shadow(color: .black.opacity(0.35), radius: 28, x: -8, y: 0)
                            .transition(.move(edge: .trailing))
                    }
                    .ignoresSafeArea(edges: .trailing)
                }

                if chatViewModel.isExpanded {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            chatViewModel.collapse()
                        }
                }

                ChatPanelView(viewModel: chatViewModel)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .frame(maxWidth: 720)
            }
        }
        .environmentObject(navigation)
        .environmentObject(chatViewModel)
        .background(AppTheme.backgroundDeep)
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: navigation.isCalendarPanelOpen)
        .onChange(of: navigation.current) { _, _ in
            warpTrigger += 1
        }
        .onAppear {
            LegacyMigrator.runIfNeeded(in: modelContext)
            // 兜底：若某张表被静默清空，从最新快照还原；随后存一份新快照。
            AutoBackupService.runStartupGuard(context: modelContext)
        }
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            Button {
                navigation.goOverview()
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    LangbridgeLogoView(size: 40)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Interview")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Tracker")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(language.t("Home", "返回首页"))
            .accessibilityLabel(language.t("Home", "返回首页"))

            HStack(spacing: 8) {
                Button {
                    navigation.back()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.hoverCue)
                .foregroundStyle(navigation.canGoBack ? AppTheme.textPrimary : AppTheme.muted)
                .disabled(!navigation.canGoBack)
                .help(language.t("Back (⌥⌘←)", "后退（⌥⌘←）"))

                Button {
                    navigation.forward()
                } label: {
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.hoverCue)
                .foregroundStyle(navigation.canGoForward ? AppTheme.textPrimary : AppTheme.muted)
                .disabled(!navigation.canGoForward)
                .help(language.t("Forward (⌥⌘→)", "前进（⌥⌘→）"))
            }
            .padding(.leading, 16)

            Spacer()

            languageToggle

            Button {
                if case .todos = navigation.current {
                    navigation.goOverview()
                } else {
                    navigation.openTodos()
                }
            } label: {
                let active: Bool = { if case .todos = navigation.current { return true }; return false }()
                Image(systemName: "checklist")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(active ? AppTheme.accent : AppTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.elevated.opacity(0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.hoverCue)
            .help(language.t("Todos", "待办清单：我要做的事"))

            Button {
                if case .reading = navigation.current {
                    navigation.goOverview()
                } else {
                    navigation.openReading()
                }
            } label: {
                let active: Bool = { if case .reading = navigation.current { return true }; return false }()
                Image(systemName: "books.vertical")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(active ? AppTheme.accent : AppTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.elevated.opacity(0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.hoverCue)
            .help(language.t("Reading library", "阅读收藏：论文 / tech blog"))

            Button {
                if case .documents = navigation.current {
                    navigation.goOverview()
                } else {
                    navigation.openDocuments()
                }
            } label: {
                let active: Bool = { if case .documents = navigation.current { return true }; return false }()
                Image(systemName: "tray.full")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(active ? AppTheme.orange : AppTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.elevated.opacity(0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.hoverCue)
            .help(language.t("Documents: resume / slides / cover letter", "求职资料库：简历 / Slides / Cover Letter"))
            .padding(.trailing, 4)

            Button {
                chatViewModel.showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.elevated.opacity(0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.hoverCue)
            .help(language.t("Settings", "设置"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(AppTheme.background.opacity(0.55))
        .background(navigationKeyShortcuts)
    }

    private var languageToggle: some View {
        Menu {
            ForEach(AppLanguage.allCases) { lang in
                Button {
                    language.language = lang
                } label: {
                    HStack {
                        Text(lang.pickerLabel)
                        if language.language == lang {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(language.language == .chinese ? "中" : "EN")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 32, height: 32)
                .background(AppTheme.elevated.opacity(0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .help(language.t("Language", "语言"))
    }

    /// Hidden buttons so ⌥⌘← / ⌥⌘→ work anywhere in the window.
    private var navigationKeyShortcuts: some View {
        ZStack {
            Button(language.t("Back", "后退")) { navigation.back() }
                .keyboardShortcut(.leftArrow, modifiers: [.option, .command])
            Button(language.t("Forward", "前进")) { navigation.forward() }
                .keyboardShortcut(.rightArrow, modifiers: [.option, .command])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var overviewDetail: some View {
        switch navigation.current {
        case .overview:
            DashboardView()
        case .company(let id):
            CompanyDetailView(companyID: id)
        case .reading:
            ReadingLibraryView()
        case .readingItem(let id):
            ReadingNotesView(itemID: id)
        case .documents:
            DocumentVaultView()
        case .journal:
            JournalView()
        case .todos:
            TodoListView()
        }
    }
}

enum AppTheme {
    /// Deep ink — not flat black, not purple glow.
    static let background = Color(red: 0.07, green: 0.09, blue: 0.12)
    static let backgroundDeep = Color(red: 0.05, green: 0.06, blue: 0.09)
    static let sidebar = Color(red: 0.06, green: 0.08, blue: 0.11)
    static let card = Color(red: 0.10, green: 0.13, blue: 0.17)
    static let elevated = Color(red: 0.14, green: 0.17, blue: 0.22)
    static let stroke = Color.white.opacity(0.07)

    /// Teal accent
    static let accent = Color(red: 0.18, green: 0.80, blue: 0.72)
    static let orange = Color(red: 0.96, green: 0.62, blue: 0.26)
    static let green = Color(red: 0.36, green: 0.82, blue: 0.55)
    static let rose = Color(red: 0.95, green: 0.40, blue: 0.45)
    static let softBlue = Color(red: 0.35, green: 0.55, blue: 0.95)

    static let textPrimary = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.52)
    static let muted = Color.white.opacity(0.45)

    // Keep purple alias for existing call sites (desire stars etc.)
    static let purple = Color(red: 0.55, green: 0.72, blue: 0.98)
}
