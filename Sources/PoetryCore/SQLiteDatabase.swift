import Foundation
import CSQLite

public enum SQLiteValue: Equatable {
    case text(String), integer(Int64), real(Double), null
    public var string: String? { if case .text(let value) = self { return value }; return nil }
    public var integer: Int64? { if case .integer(let value) = self { return value }; return nil }
}

public struct DatabaseError: Error, LocalizedError {
    public let message: String
    public var errorDescription: String? { message }
}

/// Confined to the calling application actor; transactions never cross an await.
public final class SQLiteDatabase {
    private var handle: OpaquePointer?
    public init(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open(url.path, &handle) == SQLITE_OK else { throw failure() }
        sqlite3_busy_timeout(handle, 5000)
        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA journal_mode = WAL")
    }
    deinit { sqlite3_close(handle) }
    private func failure() -> DatabaseError { DatabaseError(message: handle.map { String(cString: sqlite3_errmsg($0)) } ?? "Cannot open SQLite") }
    private func prepare(_ sql: String, _ values: [SQLiteValue]) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch value {
            case .text(let text): result = sqlite3_bind_text(statement, index, text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case .integer(let number): result = sqlite3_bind_int64(statement, index, number)
            case .real(let number): result = sqlite3_bind_double(statement, index, number)
            case .null: result = sqlite3_bind_null(statement, index)
            }
            guard result == SQLITE_OK else { sqlite3_finalize(statement); throw failure() }
        }
        return statement
    }
    public func execute(_ sql: String, _ values: [SQLiteValue] = []) throws {
        let statement = try prepare(sql, values)
        defer { sqlite3_finalize(statement) }
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW { result = sqlite3_step(statement) }
        guard result == SQLITE_DONE else { throw failure() }
    }
    public func query(_ sql: String, _ values: [SQLiteValue] = []) throws -> [[String: SQLiteValue]] {
        let statement = try prepare(sql, values)
        defer { sqlite3_finalize(statement) }
        var rows: [[String: SQLiteValue]] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { return rows }
            guard result == SQLITE_ROW else { throw failure() }
            var row: [String: SQLiteValue] = [:]
            for index in 0..<sqlite3_column_count(statement) {
                let name = String(cString: sqlite3_column_name(statement, index))
                switch sqlite3_column_type(statement, index) {
                case SQLITE_INTEGER: row[name] = .integer(sqlite3_column_int64(statement, index))
                case SQLITE_FLOAT: row[name] = .real(sqlite3_column_double(statement, index))
                case SQLITE_TEXT: row[name] = .text(String(cString: sqlite3_column_text(statement, index)))
                default: row[name] = .null
                }
            }
            rows.append(row)
        }
    }
    public func transaction<T>(_ operation: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE")
        do { let value = try operation(); try execute("COMMIT"); return value }
        catch { try? execute("ROLLBACK"); throw error }
    }
}
