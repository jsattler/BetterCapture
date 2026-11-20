//
//  TextTable.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

/// Renders rows as left-aligned columns separated by two spaces
enum TextTable {
    static func render(header: [String], rows: [[String]]) -> String {
        let allRows = [header] + rows
        let widths = header.indices.map { column in
            allRows.map { $0[column].count }.max() ?? 0
        }

        return allRows.map { row in
            row.enumerated().map { column, cell in
                column == row.count - 1 ? cell : cell + String(repeating: " ", count: widths[column] - cell.count)
            }
            .joined(separator: "  ")
        }
        .joined(separator: "\n")
    }
}
