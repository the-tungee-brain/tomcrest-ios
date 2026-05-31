import Foundation

struct SecFilingsResponse: Decodable {
    let symbol: String
    let cik: String
    let filings: [SecFilingSummary]
}

struct SecFilingSummary: Decodable, Identifiable {
    var id: String { accessionNumber }
    let accessionNumber: String
    let filingDate: String
    let reportDate: String
    let form: String
    let primaryDocument: String?

    enum CodingKeys: String, CodingKey {
        case accessionNumber = "accession_number"
        case filingDate = "filing_date"
        case reportDate = "report_date"
        case form
        case primaryDocument = "primary_document"
    }
}

struct SecFinancialsResponse: Decodable {
    let symbol: String
    let cik: String
    let entityName: String
    let period: String
    let currency: String
    let incomeStatement: [SecFinancialLineItem]
    let balanceSheet: [SecFinancialLineItem]
    let cashFlow: [SecFinancialLineItem]

    enum CodingKeys: String, CodingKey {
        case symbol, cik, period, currency
        case entityName = "entity_name"
        case incomeStatement = "income_statement"
        case balanceSheet = "balance_sheet"
        case cashFlow = "cash_flow"
    }
}

struct SecFinancialLineItem: Decodable, Identifiable {
    var id: String { tag }
    let tag: String
    let label: String
    let unit: String
    let observations: [SecFinancialObservation]
}

struct SecFinancialObservation: Decodable, Identifiable {
    var id: String { "\(end)-\(fiscalPeriod)" }
    let end: String
    let start: String?
    let value: Double
    let fiscalYear: Int?
    let fiscalPeriod: String
    let form: String
    let filed: String

    enum CodingKeys: String, CodingKey {
        case end, start, value, form, filed
        case fiscalYear = "fiscal_year"
        case fiscalPeriod = "fiscal_period"
    }
}

struct SecRatiosResponse: Decodable {
    let symbol: String
    let cik: String
    let entityName: String
    let period: String
    let snapshots: [SecRatioSnapshot]

    enum CodingKeys: String, CodingKey {
        case symbol, cik, period, snapshots
        case entityName = "entity_name"
    }
}

struct SecRatioSnapshot: Decodable, Identifiable {
    var id: String { end }
    let end: String
    let fiscalPeriod: String
    let fiscalYear: Int?
    let grossMargin: Double?
    let operatingMargin: Double?
    let netMargin: Double?
    let roe: Double?
    let roa: Double?
    let debtToEquity: Double?
    let freeCashFlow: Double?
    let fcfMargin: Double?
    let revenueGrowthYoy: Double?
    let netIncomeGrowthYoy: Double?

    enum CodingKeys: String, CodingKey {
        case end
        case fiscalPeriod = "fiscal_period"
        case fiscalYear = "fiscal_year"
        case grossMargin = "gross_margin"
        case operatingMargin = "operating_margin"
        case netMargin = "net_margin"
        case roe, roa
        case debtToEquity = "debt_to_equity"
        case freeCashFlow = "free_cash_flow"
        case fcfMargin = "fcf_margin"
        case revenueGrowthYoy = "revenue_growth_yoy"
        case netIncomeGrowthYoy = "net_income_growth_yoy"
    }
}
