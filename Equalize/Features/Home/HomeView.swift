import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Course.name) private var courses: [Course]
    @State private var showAddCourse = false

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        if h < 12 { return "Good morning" }
        if h < 17 { return "Good afternoon" }
        return "Good evening"
    }

    @State private var showDevMenu = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        
                        // 1. Hero Header
                        ZStack(alignment: .topLeading) {
                            Image("Design 1")
                                .resizable()
                                .scaledToFill()
                                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 0.42, alignment: .bottom)
                                .clipped()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(greeting)
                                    .font(.system(size: 34, weight: .bold))
                                
                                Text("Every lecture.\nA more accessible\ntomorrow.")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .lineSpacing(4)
                            }
                            .foregroundStyle(Color(red: 0.12, green: 0.22, blue: 0.20))
                            .padding(.horizontal, 24)
                            .padding(.top, 110)
                        }
                        
                        VStack(alignment: .leading, spacing: 36) {
                            
                            // 2. Continue Learning
                            ContinueLearningSection(courses: courses)
                            
                            // 3. Your Courses
                            YourCoursesSection(courses: courses)
                            
                            // 4. Waiting for Transcription
                            TranscriptionSection()
                            
                            // 5. Recent Activity
                            RecentActivitySection()
                            
                        }
                        .padding(.top, 32)
                        .padding(.bottom, 80)
                        .frame(width: UIScreen.main.bounds.width)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color(red: 0.97, green: 0.96, blue: 0.94).ignoresSafeArea())
            .toolbar {

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Color(red: 0.12, green: 0.22, blue: 0.20))
                    }
                }
            }
            .sheet(isPresented: $showDevMenu) {
                DevMenu()
            }
        }
    }
}

// MARK: - Section Components

struct SectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    var body: some View {
        HStack(alignment: .bottom) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color(red: 0.15, green: 0.18, blue: 0.22))
            
            Spacer()
            
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 2) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .offset(y: 1)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}

// MARK: - Continue Learning

struct ContinueLearningSection: View {
    let courses: [Course]
    @State private var showAll = false
    
    var activeCourses: [Course] {
        let interacted = courses.filter { $0.lastInteractedAt != nil }
        let sorted = interacted.sorted { ($0.lastInteractedAt ?? Date.distantPast) > ($1.lastInteractedAt ?? Date.distantPast) }
        return Array(sorted.prefix(3))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Continue Learning", actionTitle: activeCourses.isEmpty ? nil : "See all") {
                showAll = true
            }
            
            if activeCourses.isEmpty {
                ContinueLearningEmptyState()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(activeCourses.enumerated()), id: \.element.id) { index, course in
                            let assetName = "CL\((index % 4) + 1)"
                            NavigationLink(destination: CourseDetailView(course: course)) {
                                ContinueLearningCard(course: course, assetName: assetName)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    // Optional: .scrollTargetLayout() could be used here if running iOS 17+,
                    // but keeping it simple for maximum compatibility
                }
            }
        }
        .navigationDestination(isPresented: $showAll) {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Array(courses.filter { $0.lastInteractedAt != nil }.sorted { ($0.lastInteractedAt ?? Date.distantPast) > ($1.lastInteractedAt ?? Date.distantPast) }.enumerated()), id: \.element.id) { index, course in
                        let assetName = "CL\((index % 4) + 1)"
                        NavigationLink(destination: CourseDetailView(course: course)) {
                            ContinueLearningCard(course: course, assetName: assetName)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 24)
            }
            .navigationTitle("Continue Learning")
            .background(Color(red: 0.97, green: 0.96, blue: 0.95).ignoresSafeArea())
        }
    }
}

struct ContinueLearningEmptyState: View {
    var body: some View {
        HStack(spacing: 16) {
            Image("CL1")
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
            VStack(alignment: .leading, spacing: 4) {
                Text("Nothing to continue yet.")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(red: 0.15, green: 0.18, blue: 0.22))
                Text("Start a lecture and your progress\nwill appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
        .padding(.horizontal, 24)
    }
}

struct ContinueLearningCard: View {
    let course: Course
    let assetName: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Left Asset
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
            
            // Middle Content
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(course.name)
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.15, green: 0.18, blue: 0.22))
                    
                    let lectureStr = course.activeLesson != nil ? "Lecture \(course.activeLesson!.lectureNumber) · \(course.activeLesson!.title)" : "Ready to start"
                    Text(lectureStr)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                // Progress
                VStack(alignment: .leading, spacing: 4) {
                    let progress = course.activeLesson?.progress ?? 0.0
                    let duration = Double(course.activeLesson?.durationMinutes ?? 45) * 60
                    let elapsed = duration * progress
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.systemGray5)).frame(height: 6)
                            Capsule().fill(Color(red: 0.25, green: 0.4, blue: 0.3)) // Dark green
                                .frame(width: max(0, geo.size.width * progress), height: 6)
                        }
                    }
                    .frame(height: 6)
                    
                    Text("\(formatTime(elapsed)) / \(formatTime(duration))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer(minLength: 8)
            
            // Right Play Button
            Button {} label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color(red: 0.25, green: 0.4, blue: 0.3))) // Dark green
            }
        }
        .padding(16)
        .frame(width: UIScreen.main.bounds.width - 48)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Your Courses

struct YourCoursesSection: View {
    let courses: [Course]
    let columns = Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: 3)
    @State private var showAll = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Your Courses", actionTitle: courses.isEmpty ? nil : "See all") {
                showAll = true
            }
            
            if courses.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundStyle(Color(.systemGray3))
                    Text("No courses yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
            } else {
                LazyVGrid(columns: columns, spacing: 32) {
                    ForEach(courses.prefix(6)) { course in
                        NavigationLink(destination: CourseDetailView(course: course)) {
                            CourseFolderCard(course: course)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationDestination(isPresented: $showAll) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 32) {
                    ForEach(courses) { course in
                        NavigationLink(destination: CourseDetailView(course: course)) {
                            CourseFolderCard(course: course)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Your Courses")
            .background(Color(red: 0.97, green: 0.96, blue: 0.95).ignoresSafeArea())
        }
    }
}

struct CourseFolderCard: View {
    let course: Course

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Image("Folder \(course.thumbnailIndex)")
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76) 
                .shadow(color: .black.opacity(0.08), radius: 6, y: 4)

            Text(course.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color(red: 0.15, green: 0.18, blue: 0.22))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 34, alignment: .top)
        }
    }
}

// MARK: - Waiting for Transcription

struct TranscriptionSection: View {
    @Environment(SyncManager.self) private var syncManager
    @Query(filter: #Predicate<Lesson> { $0.statusRaw != "COMPLETE" }, sort: \.date, order: .reverse) private var processingLessons: [Lesson]
    @State private var showAll = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Waiting for transcription", actionTitle: processingLessons.isEmpty ? nil : "See all") {
                showAll = true
            }
            
            if processingLessons.isEmpty {
                TranscriptionEmptyState()
            } else {
                List {
                    ForEach(processingLessons.prefix(3)) { lesson in
                        TranscriptionTaskRow(lesson: lesson)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 8)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    lesson.statusRaw = "FAILED"
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .frame(height: CGFloat(min(processingLessons.count, 3) * 110))
                .scrollDisabled(true)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
                .padding(.horizontal, 24)
            }
        }
        .navigationDestination(isPresented: $showAll) {
            List {
                ForEach(processingLessons) { lesson in
                    TranscriptionTaskRow(lesson: lesson)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 8)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                lesson.statusRaw = "FAILED"
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Transcription Queue")
        }
    }
}

struct TranscriptionEmptyState: View {
    var body: some View {
        ContentUnavailableView {
            Label("You're all caught up", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
        } description: {
            Text("New offline recordings will appear here\nwhen they're ready to sync.")
                .font(.caption)
        }
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 24)
    }
}

struct TranscriptionTaskRow: View {
    @Environment(SyncManager.self) private var syncManager
    let lesson: Lesson
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            statusIcon
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lesson.title.isEmpty ? "Untitled Lecture" : lesson.title)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color(red: 0.15, green: 0.18, blue: 0.22))
                        Text(lesson.statusRaw)
                            .font(.subheadline)
                            .foregroundStyle(lesson.statusRaw == "FAILED" ? .red : .secondary)
                    }
                    Spacer()
                    if lesson.statusRaw == "FAILED" {
                        Button {
                            lesson.statusRaw = "QUEUED"
                            Task {
                                await syncManager.retryUpload(lesson: lesson)
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                        }
                    } else {
                        Image(systemName: "ellipsis")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                statusDetails
            }
        }
        .padding(16)
    }
    
    var statusIconName: String {
        switch lesson.statusRaw {
        case "UPLOADING", "QUEUED": return "WRWifi"
        case "TRANSCRIBING LOCALLY": return "WRTranscribing"
        case "FAILED": return "WRWifi Not Connected"
        case "PROCESSING":
            let p = Int(lesson.uploadProgress * 100)
            if p < 50 { return "WRWait" }
            else if p < 85 { return "WRTranscribing" }
            else { return "WRNotesWriting" }
        default: return "WRTranscribing"
        }
    }
    
    @ViewBuilder
    var statusIcon: some View {
        Image(statusIconName)
            .resizable()
            .scaledToFit()
            .frame(width: 44, height: 44)
    }
    
    @ViewBuilder
    var statusDetails: some View {
        let barColor = lesson.statusRaw == "UPLOADING" ? Color.blue : (lesson.statusRaw == "FAILED" ? Color.red : Color(red: 0.25, green: 0.4, blue: 0.3))
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if lesson.uploadProgress == 0 && lesson.statusRaw != "FAILED" {
                    ProgressView()
                        .controlSize(.small)
                        .tint(barColor)
                }
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(lesson.statusRaw == "FAILED" ? .red : .secondary)
            }

            if lesson.uploadProgress > 0 && lesson.statusRaw != "FAILED" {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.systemGray5)).frame(maxWidth: .infinity, maxHeight: .infinity)
                        Capsule().fill(barColor)
                            .frame(width: geo.size.width * max(0.0, min(1.0, lesson.uploadProgress)))
                            .animation(.easeInOut(duration: 0.4), value: lesson.uploadProgress)
                    }
                }
                .frame(height: 6)
            }
        }
    }
    
    var statusText: String {
        switch lesson.statusRaw {
        case "UPLOADING": return "Uploading..."
        case "QUEUED": return "Queued..."
        case "TRANSCRIBING LOCALLY": return "Transcribing locally..."
        case "FAILED": return "Failed"
        case "PROCESSING":
            let p = Int(lesson.uploadProgress * 100)
            if p < 25 { return "Extracting audio..." }
            else if p < 40 { return "Analyzing slides..." }
            else if p < 60 { return "Processing transcript..." }
            else if p < 85 { return "Building AI index..." }
            else { return "Generating notes..." }
        default: return "Processing..."
        }
    }
}


// MARK: - Recent Activity

struct RecentActivitySection: View {
    @Query(sort: \Lesson.date, order: .reverse) private var lessons: [Lesson]
    @State private var showAll = false
    
    var allActivities: [RecentActivityItem] {
        let completed = lessons.filter { $0.statusRaw == "COMPLETE" }
        return completed.map { lesson in
            RecentActivityItem(
                courseName: lesson.course?.name ?? "Unknown Course",
                actionText: "Completed \(lesson.title)",
                timeAgo: lesson.formattedDate,
                assetName: "Folder \(lesson.course?.thumbnailIndex ?? 1)"
            )
        }
    }
    
    var activities: [RecentActivityItem] {
        Array(allActivities.prefix(3))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Recent activity", actionTitle: activities.isEmpty ? nil : "See all") {
                showAll = true
            }
            
            if activities.isEmpty {
                ContentUnavailableView("No recent activity.", systemImage: "clock.badge.xmark")
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
                        RecentActivityRow(activity: activity)
                        if index < activities.count - 1 {
                            Divider().padding(.leading, 76)
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
                .padding(.horizontal, 24)
            }
        }
        .navigationDestination(isPresented: $showAll) {
            List {
                ForEach(allActivities) { activity in
                    RecentActivityRow(activity: activity)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 8)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Recent Activity")
        }
    }
}

struct RecentActivityItem: Identifiable {
    let id = UUID()
    let courseName: String
    let actionText: String
    let timeAgo: String
    let assetName: String
}



struct RecentActivityRow: View {
    let activity: RecentActivityItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(activity.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.courseName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color(red: 0.15, green: 0.18, blue: 0.22))
                Text(activity.actionText)
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.15, green: 0.18, blue: 0.22).opacity(0.9))
                Text(activity.timeAgo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            Spacer()
        }
        .padding(16)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Course.self, Lesson.self], inMemory: true)
}
