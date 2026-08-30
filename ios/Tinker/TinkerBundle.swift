//
//  TinkerBundle.swift
//  Tinker
//
//  Created by Perol Notsf on 2024/7/8.
//

import WidgetKit
import SwiftUI

@main
struct TinkerBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        Tinker()
        if #available(iOSApplicationExtension 16.1, *) {
            NovelTtsLiveActivityWidget()
        }
    }
}
