import SwiftUI

struct FriendsView: View {
    let user: AppUser
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = FriendsViewModel()
    @State private var inviteFriend: FriendSummary?
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
                        searchCard
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
            .sheet(isPresented: $showPartySetup) {
                PartySetupSheet { mode, difficulty in
                    partyLaunch = PartyLaunch(mode: mode, difficulty: difficulty, autoCreate: true)
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
            .fullScreenCover(item: $partyLaunch) { launch in
                NavigationStack {
                    PartyRoomView(
                        user: user,
                        mode: launch.mode,
                        difficulty: launch.difficulty,
                        autoCreate: launch.autoCreate
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
        }
        .padding(.horizontal)
    }

    private var searchCard: some View {
        sectionCard(title: "Find Players") {
            HStack(spacing: 10) {
                TextField("Exact username", text: $vm.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(AppTheme.textPrimary)
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
                Text("Host up to 8 players with a join code. Everyone gets the same puzzle, with no rank or coins at stake.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
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
                            .background(Color.white.opacity(0.10))
                            .foregroundStyle(AppTheme.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
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
                HStack(spacing: 12) {
                    avatar(friend)
                    Text(friend.username)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Button {
                        inviteFriend = friend
                    } label: {
                        Label("Invite", systemImage: "gamecontroller.fill")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.crownGold.opacity(0.20))
                    .foregroundStyle(AppTheme.crownGold)
                    .clipShape(Capsule())
                }
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
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.modeGradient(invite.mode))
                .frame(width: 42, height: 42)
                .overlay(Image(systemName: invite.mode.icon).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 2) {
                Text(incoming ? "From \(invite.fromUsername)" : "To \(invite.toUsername)")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(invite.mode.displayName) · \(invite.mode.difficultyLabel(invite.difficulty)) · \(invite.isPlayLater ? "Play Later" : "Play Now") · expires in \(remainingText(invite))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            if incoming {
                Button("Decline") { Task { await vm.declineInvite(invite, currentUserID: user.id) } }
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                Button(invite.isPlayLater ? "Play" : "Accept") { Task { await vm.playInvite(invite, currentUser: user) } }
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.teal)
            } else if invite.isPlayLater {
                Button("Play") { Task { await vm.playInvite(invite, currentUser: user) } }
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.teal)
            } else {
                Text(invite.status == .accepted ? "Accepted" : "Waiting")
                    .font(.caption.bold())
                    .foregroundStyle(invite.status == .accepted ? AppTheme.teal : AppTheme.crownGold)
            }
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
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
        .padding(.horizontal)
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

private struct PartyLaunch: Identifiable {
    let id = UUID()
    let mode: GameMode
    let difficulty: Difficulty
    let autoCreate: Bool
}

private struct PartySetupSheet: View {
    let onCreate: (GameMode, Difficulty) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var mode: GameMode = .colorLink
    @State private var difficulty: Difficulty = .expert

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
                            Text("Pick a shared puzzle. Friends can join with the room code.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 18)

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

                        Button {
                            onCreate(mode, difficulty)
                            dismiss()
                        } label: {
                            Label("Create Room", systemImage: "person.3.fill")
                                .font(.headline.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.brandGradient)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
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
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? AppTheme.brandGradient : LinearGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                    .overlay(Image(systemName: icon).foregroundStyle(.white))
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
            .background(selected ? AppTheme.crownGold.opacity(0.10) : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
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
                                            .background(difficulty == candidate ? AnyShapeStyle(AppTheme.modeGradient(mode)) : AnyShapeStyle(AppTheme.cardBackground))
                                            .foregroundStyle(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 1))
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
                    .frame(width: 34, height: 34)
                    .background(selected ? AnyShapeStyle(AppTheme.modeGradient(mode)) : AnyShapeStyle(Color.white.opacity(0.12)))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.bold()).foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle).font(.caption).foregroundStyle(AppTheme.textSecondary).lineLimit(1)
                }
                Spacer()
                if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.teal) }
            }
            .padding(10)
            .background(selected ? AppTheme.teal.opacity(0.14) : Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
