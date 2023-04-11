//
//  StageName.swift
//  CheatingJanken
//
//  Created by トム・クルーズ on 2023/04/07.
//

import Foundation

struct StageSituation: Identifiable, Hashable {
    let id: UUID = UUID()
    let imageName: String
    let winRate: CGFloat
}