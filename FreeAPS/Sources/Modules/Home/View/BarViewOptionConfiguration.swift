//
//  BarConfiguration.swift
//  FreeAPS
//
//  Created by Richard on 03.02.25.
//
/* enum BarViewOptionConfiguration: String, CaseIterable {
     case none = "bars_none"
     case top = "bars_top"
     case dana = "bars_dana"
     case legend = "bars_legend"
     case tt = "bars_tt"
     case bottom = "bars_bottom"
     case topDana = "bars_top_dana"
     case topLegend = "bars_top_legend"
     case topTT = "bars_top_tt"
     case topBottom = "bars_top_bottom"
     case danaLegend = "bars_dana_legend"
     case danaTT = "bars_dana_tt"
     case danaBottom = "bars_dana_bottom"
     case legendTT = "bars_legend_tt"
     case legendBottom = "bars_legend_bottom"
     case ttBottom = "bars_tt_bottom"
     case topDanaLegend = "bars_top_dana_legend"
     case topDanaTT = "bars_top_dana_tt"
     case topDanaBottom = "bars_top_dana_bottom"
     case topLegendTT = "bars_top_legend_tt"
     case topLegendBottom = "bars_top_legend_bottom"
     case topTTBottom = "bars_top_tt_bottom"
     case danaLegendTT = "bars_dana_legend_tt"
     case danaLegendBottom = "bars_dana_legend_bottom"
     case danaTTBottom = "bars_dana_tt_bottom"
     case legendTTBottom = "bars_legend_tt_bottom"
     case topDanaLegendTT = "bars_top_dana_legend_tt"
     case topDanaLegendBottom = "bars_top_dana_legend_bottom"
     case topDanaTTBottom = "bars_top_dana_tt_bottom"
     case topLegendTTBottom = "bars_top_legend_tt_bottom"
     case danaLegendTTBottom = "bars_dana_legend_tt_bottom"
     case all = "bars_top_dana_legend_tt_bottom"

     var imageName: String { rawValue }
 } */

enum BarViewOptionConfiguration: String, CaseIterable {
    case none = "bars_none"
    case top = "bars_top"
    case dana = "bars_dana"
    case tt = "bars_tt"
    case bottom = "bars_bottom"
    case topDana = "bars_top_dana"
    case topTT = "bars_top_tt"
    case topBottom = "bars_top_bottom"
    case danaTT = "bars_dana_tt"
    case danaBottom = "bars_dana_bottom"
    case ttBottom = "bars_tt_bottom"
    case topDanaTT = "bars_top_dana_tt"
    case topDanaBottom = "bars_top_dana_bottom"
    case topTTBottom = "bars_top_tt_bottom"
    case danaTTBottom = "bars_dana_tt_bottom"
    case all = "bars_top_dana_tt_bottom"

    var imageName: String { rawValue }
}
