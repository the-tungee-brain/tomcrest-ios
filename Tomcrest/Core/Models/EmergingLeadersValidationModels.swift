import Foundation

struct ValidationBucketMetrics: Decodable, Identifiable {
    let bucket: String
    let count: Int
    let avgRet5D: Double?
    let avgRet10D: Double?
    let avgRet20D: Double?
    let avgExcess5D: Double?
    let avgExcess10D: Double?
    let avgExcess20D: Double?
    let hitRate5D: Double?
    let hitRate10D: Double?
    let hitRate20D: Double?

    var id: String { bucket }
}

struct EmergingLeadersValidationResponse: Decodable {
    let snapshotDates: Int
    let snapshotRows: Int
    let labeledRows: Int
    let setupScoreBuckets: [ValidationBucketMetrics]
    let compressionVelocityBuckets: [ValidationBucketMetrics]
    let stageBuckets: [ValidationBucketMetrics]
    let topDecile: ValidationBucketMetrics
    let methodology: String
}
