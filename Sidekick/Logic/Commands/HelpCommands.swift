//
//  HelpCommands.swift
//  Sidekick
//
//  Created by John Bean on 3/13/25.
//

import AppKit
import Foundation
import SwiftUI

@MainActor
public class HelpCommands {
	
	static var commands: some Commands {
		CommandGroup(
			before: .help
		) {
			Button {
				Self.fileAnIssue()
			} label: {
				Text("Report an Issue")
			}
		}
	}
	
	/// Function to open page to file an issue on Github
	private static func fileAnIssue() {
		let url: URL = URL(string: "https://github.com/johnbean393/Sidekick/issues/new")!
		let _ = NSWorkspace.shared.open(url)
	}
	
}
