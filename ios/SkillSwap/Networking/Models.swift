import Foundation

// These structs mirror the JSON the Flask API sends (backend/app/api/views.py).
// The decoder turns snake_case into camelCase, e.g. avatar_url -> avatarUrl.

struct Skill: Decodable, Hashable {
    let name: String
    let level: String
    let projects: Int
}

struct ProjectEntry: Decodable, Hashable {
    let title: String
    let tech: [String]
    let summary: String
}

struct Standing: Decodable, Hashable, Identifiable {
    let domain: String
    let points: Int
    let counted: Int
    let reliability: Double?
    let level: String
    let label: String
    var id: String { domain }
}

struct UserProfile: Decodable, Identifiable {
    let uid: String
    let name: String
    let gender: String
    let avatarUrl: String
    let available: Bool
    let headline: String
    let education: String
    let domains: [String]
    let skills: [Skill]
    let projects: [ProjectEntry]
    let hasResume: Bool
    let warnings: [String]
    let leaderTags: [String]
    let leadHistory: [String]
    let standings: [Standing]
    let overall: Standing
    let email: String?
    var id: String { uid }
}

struct MatchItem: Decodable, Identifiable {
    let uid: String
    let name: String
    let percent: Int
    let domain: String?
    let why: String
    let matchedSkills: [String]
    let missingSkills: [String]
    let complements: [String]
    let needRole: String
    let projectId: String?
    let avatarUrl: String
    let standing: Standing?
    let leaderTags: [String]
    var id: String { uid + "|" + (projectId ?? "") + "|" + needRole }
}

struct MatchResponse: Decodable {
    let results: [MatchItem]
}

struct CandidatesResponse: Decodable {
    let role: String
    let results: [MatchItem]
}

struct ProjectSummary: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String
    let status: String
    let leaderName: String
    let members: Int
    let openNeeds: [String]
    let milestonesDone: Int
    let milestonesTotal: Int
    let isMember: Bool
    let deadline: String?
}

struct ProjectsResponse: Decodable {
    let projects: [ProjectSummary]
}

struct MemberItem: Decodable, Identifiable {
    let uid: String
    let role: String
    let name: String
    let avatarUrl: String
    let isLeader: Bool
    let isOwner: Bool
    var id: String { uid }
}

struct NeedItem: Decodable, Identifiable {
    let index: Int
    let role: String
    let domain: String?
    let skills: [String]
    let description: String
    let filledBy: String?
    let filledByName: String?
    var id: Int { index }
}

struct MilestoneItem: Decodable, Identifiable {
    let id: String
    let title: String
    let domain: String
    let weight: Int
    let status: String
    let assigneeUid: String
    let assigneeName: String
    let due: String
    let completedAt: String?
    let overdue: Bool
    let canMark: Bool
    let canMarkMissed: Bool
    let canReport: Bool
    let reports: Int
    let reportsNeeded: Int
    let canHandOver: Bool
}

struct ViewerInfo: Decodable {
    let isMember: Bool
    let isLeader: Bool
    let isOwner: Bool
    let hasApplied: Bool
}

struct ReportResult: Decodable {
    let applied: Bool
    let reports: Int
    let needed: Int
}

struct ProjectDetail: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String
    let status: String
    let ownerUid: String
    let leaderUid: String
    let leaderName: String
    let deadline: String?
    let members: [MemberItem]
    let needs: [NeedItem]
    let milestones: [MilestoneItem]
    let viewer: ViewerInfo
    let reportResult: ReportResult?
}

struct DraftMilestone: Decodable, Identifiable {
    let id: String
    let title: String
    let domain: String
    let weight: Int
    let assigneeUid: String
    let assigneeName: String
    let due: String
}

struct DraftGap: Decodable, Identifiable {
    let role: String
    let domain: String?
    var id: String { role + (domain ?? "") }
}

struct PlanDraft: Decodable {
    let sessionId: String
    let status: String
    let notes: String
    let changed: Bool?
    let warnings: [String]
    let errors: [String]
    let revisions: Int
    let revisionsLeft: Int
    let end: String?
    let extended: Bool
    let milestones: [DraftMilestone]
    let gaps: [DraftGap]
}

struct JoinRequest: Decodable, Identifiable {
    let user: UserProfile
    let needIndex: Int?
    let role: String
    let message: String
    var id: String { user.uid }
}

struct RequestsResponse: Decodable {
    let requests: [JoinRequest]
}

struct OkResponse: Decodable {
    let ok: Bool
}

/// The 14 domains used everywhere (same list as backend/app/resume/taxonomy.py).
enum Domains {
    static let all = [
        "Backend", "Frontend", "Mobile (iOS)", "Mobile (Android)", "Cross-platform Mobile", "UI/UX Design",
        "Machine Learning", "Data Science & Analytics", "DevOps & Cloud", "Cybersecurity", "Embedded & IoT",
        "Game Development", "Product & Management", "Content & Marketing",
    ]
}
