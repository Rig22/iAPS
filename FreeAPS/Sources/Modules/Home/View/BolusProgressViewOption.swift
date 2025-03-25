//
//  BolusProgressViewOption.swift
//  FreeAPS
//
//  Created by Richard on 15.03.25.
//
enum BolusProgressViewOption: String, CaseIterable, Identifiable {
    case bolusview1 = "View 1"
    case bolusview2 = "View 2"

    var id: String { rawValue }
}
