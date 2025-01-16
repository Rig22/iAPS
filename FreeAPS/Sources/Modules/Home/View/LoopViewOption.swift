//
//  LoopViewOption.swift
//  FreeAPS
//
//  Created by Richard on 03.01.25.
//
//
//  DanaBarOption.swift
//  FreeAPS
//
//  Created by Richard on 05.12.24.
//
enum LoopViewOption: String, CaseIterable, Identifiable {
    case view1 = "View 1"
    case view2 = "View 2"

    var id: String { rawValue }
}
