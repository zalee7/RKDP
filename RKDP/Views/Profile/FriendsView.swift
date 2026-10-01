import SwiftUI

struct FriendsView: View {
    let user: AppUser
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = FriendsViewModel()
    @State private var inviteFriend: FriendSummary?
    @State private var selectedFriend: FriendSummary?
    @State private var friendToRemove: FriendSummary?
    @State private var showPartySetup = false
    @State private var partyLaunch: PartyLaunch?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.arenaBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        header
                        partySection
                        #if !PP_SOCIAL_SANDBOX
                        searchCard
                        #endif
                        if let error = vm.errorMessage {
                            Text(error)
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.warning)
                                .padding(.horizontal)
                        }
                        invitesSection
                        requestsSection
                        friendsSection
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear { vm.start(user: user) }
            .onDisappear { vm.stop() }
            .sheet(item: $inviteFriend) { friend in
                InviteFriendSheet(friend: friend) { mode, difficulty, inviteType in
                    Task { await vm.sendInvite(from: user, to: friend, mode: mode, difficulty: difficulty, inviteType: inviteType) }
                }
            }
            .sheet(item: $selectedFriend) { friend in
                FriendProfileSheet(
                    friend: friend,
                    profile: vm.friendProfiles[friend.userID],
                    onInvite: { inviteFriend = friend },
                    onRemove: { friendToRemove = friend }
                )
            }
            .alert(
                "Remove Friend?",
                isPresented: Binding(
                    get: { friendToRemove != nil },
                    set: { if !$0 { friendToRemove = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) { friendToRemove = nil }
                Button("Remove", role: .destructive) {
                    guard let friend = friendToRemove else { return }
                    selectedFriend = nil
                    friendToRemove = nil
                    Task { await vm.removeFriend(friend, currentUserID: user.id) }
                }
            } message: {
                Text("This removes them from your friends list and cancels pending invites between you.")
            }
            .sheet(isPresented: $showPartySetup) {
                PartySetupSheet { mode, difficulty, rounds in
                    let first = rounds?.first ?? PartyStageRoundConfiguration.quickStage[0]
                    partyLaunch = PartyLaunch(
                        mode: rounds == nil ? mode : first.mode,
                        difficulty: rounds == nil ? difficulty : first.difficulty,
                        autoCreate: true,
                        stageRounds: rounds
                    )
                }
            }
            .fullScreenCover(item: $vm.activeExhibitionSession, onDismiss: {
                Task { await vm.closeActiveExhibitionInvite() }
                vm.activeExhibitionSession = nil
            }) { session in
                NavigationStack {
                    MatchmakingView(exhibitionSession: session, user: user) {
                        Task { await auth.refreshUser() }
                    }
                }
            }
            .fullScreenCover(item: $partyLaunch, onDismiss: {
                #if PP_SOCIAL_SANDBOX
                Task { await auth.refreshUser() }
                #endif
            }) { launch in
                NavigationStack {
                    PartyRoomView(
                        user: user,
                        mode: launch.mode,
                        difficulty: launch.difficulty,
                        autoCreate: launch.autoCreate,
                        stageRoundConfigurations: launch.stageRounds
                    )
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.crownGold)
            Text("Friends")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text("Add friends and invite them to no-stakes exhibition matches.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            ShareLink(item: friendInviteShareText) {
                Label("Invite Outside App", systemImage: "square.and.arrow.up")
                    .font(.caption.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(AppTheme.controlBackground)
                    .foregroundStyle(AppTheme.textPrimary)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.controlBorder, lineWidth: 1))
            }
        }
        .padding(.horizontal)
    }

    private var friendInviteShareText: String {
        "Play Puzzle Party with me. Add my username: \(user.username)"
    }

    private var searchCard: some View {
        sectionCard(title: "Find Players") {
            HStack(spacing: 10) {
                TextField("", text: $vm.searchText, prompt: Text("Exact username").foregroundStyle(AppTheme.textMuted))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { Task { await vm.search(currentUserID: user.id) } }
                    .padding(12)
                    .background(AppTheme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.controlBorder, lineWidth: 1.25))
                    .foregroundStyle(AppTheme.textPrimary)
                    .tint(AppTheme.accentBright)
                Button {
                    Task { await vm.search(currentUserID: user.id) }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .frame(width: 42, height: 42)
                        .background(AppTheme.brandGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            ForEach(vm.searchResults) { result in
                HStack(spacing: 12) {
                    avatar(username: result.username)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.username).font(.headline).foregroundStyle(AppTheme.textPrimary)
                        Text("Tap Add to send a request").font(.caption).foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Button("Add") {
                        Task { await vm.sendRequest(from: user, to: result) }
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.teal.opacity(0.22))
                    .foregroundStyle(AppTheme.teal)
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var partySection: some View {
        sectionCard(title: "Party Mode") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Host up to 8 players with a join code. Choose one game or a 3-round party playlist with post-round scores.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    Button {
                        showPartySetup = true
                    } label: {
                        Label("Create Party", systemImage: "plus.circle.fill")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(AppTheme.brandGradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        partyLaunch = PartyLaunch(mode: .colorLink, difficulty: .expert, autoCreate: false)
                    } label: {
                        Label("Join Code", systemImage: "number.circle.fill")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(AppTheme.controlBackground)
                            .foregroundStyle(AppTheme.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1.25))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var invitesSection: some View {
        sectionCard(title: "Exhibition Invites") {
            if vm.incomingInvites.isEmpty && vm.outgoingInvites.isEmpty {
                emptyText("No active invites")
            }
            ForEach(vm.incomingInvites) { invite in
                inviteRow(invite, incoming: true)
            }
            ForEach(vm.outgoingInvites) { invite in
                inviteRow(invite, incoming: false)
            }
        }
    }

    private var requestsSection: some View {
        sectionCard(title: "Friend Requests") {
            if vm.incomingRequests.isEmpty && vm.outgoingRequests.isEmpty {
                emptyText("No pending requests")
            }
            ForEach(vm.incomingRequests) { request in
                requestRow(request, incoming: true)
            }
            ForEach(vm.outgoingRequests) { request in
                requestRow(request, incoming: false)
            }
        }
    }

    private var friendsSection: some View {
        sectionCard(title: "Your Friends") {
            if vm.friends.isEmpty {
                emptyText("Search a username to add your first friend")
            }
            ForEach(vm.friends) { friend in
                HStack(spacing: 10) {
                    avatar(friend)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(friend.username)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Tap for profile")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.textMuted)
                    Button {
                        inviteFriend = friend
                    } label: {
                        Label("Invite", systemImage: "gamecontroller.fill")
                            .font(.caption.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(minWidth: 76)
                            .background(AppTheme.crownGold.opacity(0.18))
                            .foregroundStyle(AppTheme.crownGold)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.crownGold.opacity(0.48), lineWidth: 1.2))
                            .shadow(color: AppTheme.crownGold.opacity(0.22), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Invite \(friend.username)")
                }
                .padding(10)
                .background(AppTheme.controlBackground.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1))
                .contentShape(Rectangle())
                .onTapGesture { selectedFriend = friend }
            }
        }
    }

    private func requestRow(_ request: FriendRequest, incoming: Bool) -> some View {
        HStack(spacing: 12) {
            avatar(username: request.otherUsername(currentUserID: user.id))
            VStack(alignment: .leading, spacing: 2) {
                Text(request.otherUsername(currentUserID: user.id))
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(incoming ? "Wants to be friends" : "Request sent")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            if incoming {
                Button("Decline") { Task { await vm.declineRequest(request, currentUserID: user.id) } }
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                Button("Accept") { Task { await vm.acceptRequest(request, currentUserID: user.id) } }
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.teal)
            } else {
                Button("Cancel") { Task { await vm.cancelRequest(request, currentUserID: user.id) } }
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private func inviteRow(_ invite: ExhibitionInvite, incoming: Bool) -> some View {
        let asyncState = playLaterState(for: invite)
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.modeGradient(invite.mode))
                .frame(width: 42, height: 42)
                .overlay(Image(systemName: invite.mode.icon).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 6) {
                Text(incoming ? "From \(invite.fromUsername)" : "To \(invite.toUsername)")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(invite.mode.displayName) · \(invite.mode.difficultyLabel(invite.difficulty)) · expires in \(remainingText(invite))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                if invite.isPlayLater {
                    playLaterStatusPill(asyncState)
                } else {
                    Text(statusText(for: invite, asyncState: asyncState, incoming: incoming))
                        .font(.caption.bold())
                        .foregroundStyle(statusColor(for: invite, asyncState: asyncState))
                }
            }
            Spacer()
            if invite.isPlayLater {
                playLaterAction(invite, state: asyncState, incoming: incoming)
            } else if incoming {
                Button("Decline") { Task { await vm.declineInvite(invite, currentUserID: user.id) } }
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                Button("Accept") { Task { await vm.playInvite(invite, currentUser: user) } }
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.teal)
            } else {
                Text(invite.status == .accepted ? "Accepted" : "Waiting")
                    .font(.caption.bold())
                    .foregroundStyle(invite.status == .accepted ? AppTheme.teal : AppTheme.crownGold)
            }
        }
    }

    @ViewBuilder
    private func playLaterAction(_ invite: ExhibitionInvite, state: PlayLaterInviteState, incoming: Bool) -> some View {
        switch state {
        case .waitingOnFriend:
            Text("Waiting")
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(AppTheme.controlBackground)
                .foregroundStyle(AppTheme.textSecondary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.controlBorder, lineWidth: 1))
        case .completed:
            Button("View Result") { Task { await vm.playInvite(invite, currentUser: user) } }
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(AppTheme.teal.opacity(0.16))
                .foregroundStyle(AppTheme.teal)
                .clipShape(Capsule())
        case .yourTurn:
            if incoming && invite.status == .pending {
                Button("Decline") { Task { await vm.declineInvite(invite, currentUserID: user.id) } }
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Button("Play Turn") { Task { await vm.playInvite(invite, currentUser: user) } }
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(AppTheme.hotPink)
                .foregroundStyle(AppTheme.textOnColor)
                .clipShape(Capsule())
        }
    }

    private func playLaterStatusPill(_ state: PlayLaterInviteState) -> some View {
        Text(statusPillText(for: state))
            .font(.system(size: 10, weight: .black, design: .rounded))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(statusColor(for: state).opacity(state == .yourTurn ? 0.18 : 0.13))
            .foregroundStyle(statusColor(for: state))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(statusColor(for: state).opacity(0.32), lineWidth: 1))
    }

    private func statusPillText(for state: PlayLaterInviteState) -> String {
        switch state {
        case .yourTurn: return "YOUR TURN"
        case .waitingOnFriend: return "WAITING ON FRIEND"
        case .completed: return "RESULT READY"
        }
    }

    private enum PlayLaterInviteState {
        case yourTurn
        case waitingOnFriend
        case completed
    }

    private func playLaterState(for invite: ExhibitionInvite) -> PlayLaterInviteState {
        guard let sessionID = invite.sessionID,
              let session = vm.inviteSessions[sessionID],
              let results = session.playerResults else {
            return .yourTurn
        }

        let myResult = results[user.id].flatMap { MatchResolver.isFinalResult($0) ? $0 : nil }
        let opponentID = invite.fromID == user.id ? invite.toID : invite.fromID
        let opponentResult = results[opponentID].flatMap { MatchResolver.isFinalResult($0) ? $0 : nil }

        if session.status == .finished || (myResult != nil && opponentResult != nil) {
            return .completed
        }
        if myResult != nil {
            return .waitingOnFriend
        }
        return .yourTurn
    }

    private func statusText(for invite: ExhibitionInvite, asyncState: PlayLaterInviteState, incoming: Bool) -> String {
        if invite.isPlayLater {
            switch asyncState {
            case .yourTurn:
                return "Play Later · Your Turn"
            case .waitingOnFriend:
                return "Play Later · Submitted · waiting on friend"
            case .completed:
                return "Completed · View Result"
            }
        }
        if incoming {
            return invite.status == .accepted ? "Play Now · Ready Up" : "Play Now · Waiting"
        }
        return invite.status == .accepted ? "Play Now · Ready Up" : "Play Now · Waiting"
    }

    private func statusColor(for invite: ExhibitionInvite, asyncState: PlayLaterInviteState) -> Color {
        if invite.isPlayLater {
            return statusColor(for: asyncState)
        }
        return invite.status == .accepted ? AppTheme.teal : AppTheme.crownGold
    }

    private func statusColor(for state: PlayLaterInviteState) -> Color {
        switch state {
        case .yourTurn:
            return AppTheme.hotPink
        case .waitingOnFriend:
            return AppTheme.textSecondary
        case .completed:
            return AppTheme.teal
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.bold())
                .foregroundStyle(AppTheme.accentBright)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1.2))
        .shadow(color: AppTheme.softShadow.opacity(0.45), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }

    private func friendStatsLine(_ profile: AppUser) -> String {
        let wins = profile.ranks.values.reduce(0) { $0 + $1.wins }
        let losses = profile.ranks.values.reduce(0) { $0 + $1.losses }
        let bestRank = profile.ranks.values.max { lhs, rhs in
            if lhs.displayTier.rawValue == rhs.displayTier.rawValue {
                return lhs.points < rhs.points
            }
            return lhs.displayTier.rawValue < rhs.displayTier.rawValue
        }?.fullDisplayName ?? "Bronze III"
        return "\(wins)-\(losses) · \(bestRank)"
    }

    private func avatar(username: String) -> some View {
        StickDuelerAvatarView(style: .default, size: 44, initials: String(username.prefix(1)))
    }

    private func avatar(_ friend: FriendSummary) -> some View {
        StickDuelerAvatarView(style: friend.avatarStyle, size: 44, initials: String(friend.username.prefix(1)))
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(AppTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func remainingText(_ invite: ExhibitionInvite) -> String {
        let seconds = max(0, Int(invite.expiresAt.timeIntervalSinceNow))
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

private struct FriendProfileSheet: View {
    let friend: FriendSummary
    let profile: AppUser?
    let onInvite: () -> Void
    let onRemove: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.arenaBackground.ignoresSafeArea()
                ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 10) {
                        EarnedAvatarView(style: profile?.cosmetics.avatarStyle ?? friend.avatarStyle,
                                         frame: profile?.equippedEarnedReward(in: .frame), size: 96)
                        Text(friend.username)
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(profile?.displayedTitle ?? "Loading profile stats...")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.textSecondary)
                        if let badge = profile?.equippedEarnedReward(in: .badge) { EarnedBadgeLabel(reward: badge) }
                    }

                    if let profile {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Earned Collection").font(.headline).foregroundStyle(AppTheme.hotPink)
                            EarnedTrophyShelf(user: profile)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            statTile("W/L", totalRecordText, "chart.bar.fill")
                            statTile("Best Rank", bestRankText, "medal.fill")
                        }
                        HStack(spacing: 10) {
                            statTile("Rank Points", totalPointsText, "sparkles")
                            statTile("Top Mode", topModeText, "gamecontroller.fill")
                        }
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1.2))

                    VStack(spacing: 10) {
                        Button {
                            dismiss()
                            onInvite()
                        } label: {
                            Label("Invite to Play", systemImage: "gamecontroller.fill")
                                .font(.headline.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.crownGold.opacity(0.18))
                                .foregroundStyle(AppTheme.crownGold)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.crownGold.opacity(0.52), lineWidth: 1.3))
                                .shadow(color: AppTheme.crownGold.opacity(0.22), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)

                        Button(role: .destructive) {
                            dismiss()
                            onRemove()
                        } label: {
                            Label("Remove Friend", systemImage: "person.fill.xmark")
                                .font(.headline.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.danger.opacity(0.16))
                                .foregroundStyle(AppTheme.danger)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.danger.opacity(0.28), lineWidth: 1))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.accentBright)
                }
            }
        }
    }

    private var totalRecordText: String {
        guard let profile else { return "--" }
        let wins = profile.ranks.values.reduce(0) { $0 + $1.wins }
        let losses = profile.ranks.values.reduce(0) { $0 + $1.losses }
        return "\(wins)-\(losses)"
    }

    private var bestRankText: String {
        guard let best = profile?.ranks.values.max(by: { lhs, rhs in
            if lhs.displayTier.rawValue == rhs.displayTier.rawValue {
                return lhs.points < rhs.points
            }
            return lhs.displayTier.rawValue < rhs.displayTier.rawValue
        }) else { return "--" }
        return best.fullDisplayName
    }

    private var totalPointsText: String {
        guard let profile else { return "--" }
        return "\(profile.totalRankPoints)"
    }

    private var topModeText: String {
        guard let item = profile?.ranks.max(by: { lhs, rhs in lhs.value.points < rhs.value.points }) else { return "--" }
        return item.key.displayName
    }

    private func statTile(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.accentBright)
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1))
    }
}

private struct PartyLaunch: Identifiable {
    let id = UUID()
    let mode: GameMode
    let difficulty: Difficulty
    let autoCreate: Bool
    var stageRounds: [PartyStageRoundConfiguration]? = nil
}

private struct PartySetupSheet: View {
    let onCreate: (GameMode, Difficulty, [PartyStageRoundConfiguration]?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var mode: GameMode = .colorLink
    @State private var difficulty: Difficulty = .expert
    @State private var format: PartySetupFormat = .single
    @State private var rounds = PartyStageRoundConfiguration.quickStage

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.arenaBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 8) {
                            Text("Create Party")
                                .font(.title.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Pick one shared puzzle or build a 3-round playlist with post-round scores.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 18)

                        pickerSection(title: "Party Format") {
                            HStack(spacing: 10) {
                                setupFormatButton(.single)
                                setupFormatButton(.playlist)
                            }
                        }

                        if format == .single {
                            pickerSection(title: "Mode") {
                                ForEach(GameMode.allCases) { candidate in
                                    setupRow(
                                        title: candidate.displayName,
                                        subtitle: candidate.description,
                                        icon: candidate.icon,
                                        selected: mode == candidate
                                    ) {
                                        mode = candidate
                                        difficulty = candidate.defaultDifficulty
                                    }
                                }
                            }

                            pickerSection(title: mode == .anagram || mode == .hangman ? "Word Length" : "Difficulty") {
                                ForEach(Difficulty.allCases, id: \.self) { candidate in
                                    setupRow(
                                        title: mode.difficultyLabel(candidate),
                                        subtitle: candidate.displayName,
                                        icon: "slider.horizontal.3",
                                        selected: difficulty == candidate
                                    ) {
                                        difficulty = candidate
                                    }
                                }
                            }
                        } else {
                            pickerSection(title: "Playlist") {
                                Text("Choose 3 different games. Scores are awarded after each round, then combined for the final party winner.")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)

                                Button {
                                    rounds = PartyStageRoundConfiguration.quickStage
                                } label: {
                                    Label("Quick Playlist", systemImage: "sparkles")
                                        .font(.caption.bold())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(AppTheme.hotPink.opacity(0.18))
                                        .foregroundStyle(AppTheme.hotPink)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.hotPink.opacity(0.36), lineWidth: 1.25))
                                }
                                .buttonStyle(.plain)

                                ForEach(rounds.indices, id: \.self) { index in
                                    playlistRoundCard(index: index)
                                }
                            }
                        }

                        Button {
                            if format == .playlist {
                                onCreate(mode, difficulty, normalizedRounds)
                            } else {
                                onCreate(mode, difficulty, nil)
                            }
                            dismiss()
                        } label: {
                            Label(format == .playlist ? "Create Playlist Party" : "Create Room", systemImage: "person.3.fill")
                                .font(.headline.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(canCreate ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(AppTheme.controlBackground))
                                .foregroundStyle(canCreate ? .white : AppTheme.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(canCreate ? Color.clear : AppTheme.controlBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canCreate)
                    }
                    .padding()
                }
            }
            .navigationTitle("Party Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.accentBright)
                }
            }
        }
    }

    private var normalizedRounds: [PartyStageRoundConfiguration] {
        rounds.enumerated().map { offset, round in
            PartyStageRoundConfiguration(index: offset, mode: round.mode, difficulty: round.difficulty)
        }
    }

    private var canCreate: Bool {
        format == .single || Set(rounds.map(\.mode)).count == 3
    }

    private func setupFormatButton(_ candidate: PartySetupFormat) -> some View {
        Button {
            format = candidate
        } label: {
            VStack(spacing: 6) {
                Image(systemName: candidate.icon)
                    .font(.headline.bold())
                Text(candidate.title)
                    .font(.caption.bold())
                Text(candidate.subtitle)
                    .font(.system(size: 10, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .padding(10)
            .background(format == candidate ? AnyShapeStyle(AppTheme.selectedControlBackground) : AnyShapeStyle(AppTheme.controlBackground))
            .foregroundStyle(format == candidate ? AppTheme.accentBright : AppTheme.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(format == candidate ? AppTheme.accentBright.opacity(0.55) : AppTheme.controlBorder, lineWidth: format == candidate ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func pickerSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.bold())
                .foregroundStyle(AppTheme.accentBright)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private func setupRow(title: String, subtitle: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(AppTheme.controlBackground))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: icon)
                            .font(.headline.bold())
                            .foregroundStyle(selected ? AppTheme.textOnColor : AppTheme.accentBright)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(selected ? Color.white.opacity(0.55) : AppTheme.controlBorder, lineWidth: 1)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.teal)
                }
            }
            .padding(10)
            .background(selected ? AppTheme.selectedControlBackground : AppTheme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? AppTheme.accentBright.opacity(0.55) : AppTheme.controlBorder, lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func playlistRoundCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Round \(index + 1)")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.accentBright)

            Menu {
                ForEach(GameMode.allCases.filter { candidate in
                    candidate == rounds[index].mode || !rounds.contains(where: { $0.mode == candidate })
                }) { candidate in
                    Button(candidate.displayName) {
                        rounds[index].mode = candidate
                        rounds[index].difficulty = candidate.defaultDifficulty
                    }
                }
            } label: {
                setupSummaryRow(
                    title: rounds[index].mode.displayName,
                    subtitle: rounds[index].mode.description,
                    icon: rounds[index].mode.icon
                )
            }

            Menu {
                ForEach(Difficulty.allCases, id: \.self) { candidate in
                    Button(rounds[index].mode.difficultyLabel(candidate)) {
                        rounds[index].difficulty = candidate
                    }
                }
            } label: {
                setupSummaryRow(
                    title: rounds[index].mode.difficultyLabel(rounds[index].difficulty),
                    subtitle: rounds[index].difficulty.displayName,
                    icon: "slider.horizontal.3"
                )
            }
        }
        .padding()
        .background(AppTheme.controlBackground.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1))
    }

    private func setupSummaryRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.controlBackground)
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: icon)
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.accentBright)
                )
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.down")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private enum PartySetupFormat: Hashable {
    case single
    case playlist

    var title: String {
        switch self {
        case .single: return "Single Game"
        case .playlist: return "3 Rounds"
        }
    }

    var subtitle: String {
        switch self {
        case .single: return "One shared puzzle"
        case .playlist: return "Playlist and scores"
        }
    }

    var icon: String {
        switch self {
        case .single: return "gamecontroller.fill"
        case .playlist: return "list.number"
        }
    }
}

private struct InviteFriendSheet: View {
    let friend: FriendSummary
    let onInvite: (GameMode, Difficulty, ExhibitionInviteType) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var mode: GameMode = .colorLink
    @State private var difficulty: Difficulty = .medium

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.arenaBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 8) {
                            StickDuelerAvatarView(style: friend.avatarStyle, size: 64, initials: String(friend.username.prefix(1)))
                            Text("Invite \(friend.username)")
                                .font(.title.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Exhibition Match · No rank or coins at stake")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.top, 18)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Mode")
                                .font(.headline)
                                .foregroundStyle(AppTheme.accentBright)
                            ForEach(GameMode.allCases) { candidate in
                                selectionRow(
                                    title: candidate.displayName,
                                    subtitle: candidate.description,
                                    icon: candidate.icon,
                                    selected: mode == candidate
                                ) {
                                    mode = candidate
                                    difficulty = candidate.defaultDifficulty
                                }
                            }
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        VStack(alignment: .leading, spacing: 10) {
                            Text(mode == .anagram ? "Word Length" : "Difficulty")
                                .font(.headline)
                                .foregroundStyle(AppTheme.accentBright)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(Difficulty.allCases, id: \.self) { candidate in
                                    Button {
                                        difficulty = candidate
                                    } label: {
                                        Text(mode.difficultyLabel(candidate))
                                            .font(.caption.bold())
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(difficulty == candidate ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(AppTheme.controlBackground))
                                            .foregroundStyle(difficulty == candidate ? AppTheme.textOnColor : AppTheme.textPrimary)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(difficulty == candidate ? AppTheme.accentBright.opacity(0.6) : AppTheme.controlBorder, lineWidth: difficulty == candidate ? 1.5 : 1)
                                            )
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        VStack(spacing: 10) {
                            Button {
                                onInvite(mode, difficulty, .playNow)
                                dismiss()
                            } label: {
                                Label("Play Now", systemImage: "bolt.fill")
                                    .font(.headline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppTheme.modeGradient(mode))
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            Button {
                                onInvite(mode, difficulty, .playLater)
                                dismiss()
                            } label: {
                                Label("Play Later", systemImage: "tray.full.fill")
                                    .font(.headline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppTheme.cardBackground)
                                    .foregroundStyle(AppTheme.crownGold)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.crownGold.opacity(0.45), lineWidth: 1))
                            }
                            Text("Play Later challenges stay open for 48 hours and use the same puzzle for both players.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Exhibition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func selectionRow(title: String, subtitle: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline.bold())
                    .frame(width: 38, height: 38)
                    .background(selected ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(AppTheme.controlBackground))
                    .foregroundStyle(selected ? AppTheme.textOnColor : AppTheme.accentBright)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selected ? Color.white.opacity(0.55) : AppTheme.controlBorder, lineWidth: 1)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.bold()).foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle).font(.caption).foregroundStyle(AppTheme.textSecondary).lineLimit(1)
                }
                Spacer()
                if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.teal) }
            }
            .padding(10)
            .background(selected ? AppTheme.selectedControlBackground : AppTheme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? AppTheme.accentBright.opacity(0.55) : AppTheme.controlBorder, lineWidth: selected ? 1.5 : 1)
            )
        }
    }
}
