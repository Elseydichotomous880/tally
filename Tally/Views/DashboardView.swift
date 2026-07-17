import SwiftUI

/// The main app window: a resizable dashboard of every account, complementing the compact menu-bar
/// popover. Cards flow in an adaptive grid so a wider window shows more per row.
struct DashboardView: View {
    @Bindable var store: UsageStore
    @Bindable var settings: SettingsStore

    var body: some View {
        // Key `.id` on the language so a change tears down + rebuilds the whole tree — a bare read
        // wouldn't re-localize the AccountCardView children (see PopoverRootView for the full note).
        VStack(spacing: 0) {
            content
            Divider()
            footer
        }
        .frame(minWidth: 380, minHeight: 300)
        // The window's own titlebar is the header ("Tally" title leads, actions trail) — an
        // in-content header row doubled the branding and pushed the cards down for nothing.
        // Bridged onto the NSWindow via `sceneBridgingOptions = [.toolbars]`.
        .toolbar { toolbarItems }
        .id(settings.languageOverride ?? "system")
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let counter = store.isRefreshing
                    ? L("updating…")
                    : UsageFormat.updatesIn(store.nextRefreshAt, now: context.date) {
                    Text(counter).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            Button {
                Task { await store.refresh(userInitiated: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(store.isRefreshing ? 360 : 0))
                    .animation(store.isRefreshing
                        ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                        value: store.isRefreshing)
            }
            .disabled(store.isRefreshing)
            .accessibilityLabel(L("Refresh"))
            .help(L("Refresh"))
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.contentState != .hasAccounts {
            EmptyStateView(state: store.contentState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                // Track width capped at 312pt: the meters are legible at popover width, and a
                // resizable window should add columns, not stretch one card's bars ever longer.
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 276, maximum: 312), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(store.orderedAccounts) { usage in
                        AccountCardView(usage: usage, settings: settings)
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
                .padding(TallyMetrics.pagePaddingH)
            }
        }
    }

    // Same footer as the popover, so the two dashboards share one set of muscle memory.
    private var footer: some View {
        HStack {
            Picker("", selection: $settings.displayMode) {
                Text(L("Left")).tag(DisplayMode.remaining)
                Text(L("Used")).tag(DisplayMode.used)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.mini)
            .fixedSize()
            .help(L("Meters show"))
            Spacer()
            Button {
                StatusItemController.openSettingsWindow()
            } label: {
                Image(systemName: "gearshape")
                    .font(.callout)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help(L("Settings…"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
