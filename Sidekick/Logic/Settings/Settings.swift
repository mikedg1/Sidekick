//
//  Settings.swift
//  Sidekick
//
//  Created by Bean John on 9/23/24.
//

import Foundation
import AppKit
import FSKit_macOS
import UniformTypeIdentifiers

public class Settings {
	
	/// Static constant for the `gguf` UniformTypeIdentifier
	static let ggufType: UTType = UTType("com.npc-pet.Chats.gguf") ?? .data
	
	/// A `String` representing the user's name
	public static var username: String {
		get {
			guard let username = UserDefaults.standard.string(
				forKey: "username"
			) else {
				print("Failed to get username, using default")
				return NSFullUserName()
			}
			return username
		}
		set {
			// Save
			UserDefaults.standard.set(newValue, forKey: "username")
		}
	}
	
	/// A `Bool` representing whether the app's setup was completed
	static var setupComplete: Bool {
		get {
			return UserDefaults.standard.bool(
				forKey: "setupComplete"
			)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "setupComplete")
		}
	}
	
	/// Static constant for the application's container directory
	static let containerUrl: URL = URL
		.applicationSupportDirectory
		.appendingPathComponent("com.pattonium.Sidekick")
	
	/// Static constant for the application's cache directory
	static var cacheUrl: URL {
		// Check existence
		let url: URL = URL
			.applicationSupportDirectory
			.appendingPathComponent("com.pattonium.Sidekick")
			.appendingPathComponent("Cache")
		if !url.fileExists {
			// Create directory if missing
			try? FileManager.default.createDirectory(
				at: url,
				withIntermediateDirectories: true
			)
		}
		return url
	}
	
	/// Static constant for the LLM directory
	static let dirUrl: URL = Settings
		.containerUrl
		.appendingPathComponent("Models")
	
	/// Computed property for the LLM's location
	static var modelUrl: URL? {
		get {
			let result: URL
			if let url = UserDefaults.standard.url(forKey: "modelUrl") {
				result = url
			} else {
				// Get default
				if let modelUrl: URL = Self.dirUrl.contents?.compactMap({
					$0
				}).filter({
					$0.pathExtension == "gguf"
				}).first {
					result = modelUrl
				} else {
					// If no model, return nil
					return nil
				}
			}
			return result
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "modelUrl")
		}
	}
	
	/// A `Bool` representing  if an model exists for use, whether it is local or on a server
	static var hasModel: Bool {
		// Check for local model & remote model
		let hasLocalModel: Bool = Self.modelUrl?.fileExists ?? false
		let hasServerModel: Bool = InferenceSettings.serverModelSetupComplete && InferenceSettings.useServer
		return hasLocalModel || hasServerModel
	}
	
	/// A `Bool` representing whether code interpreter is enabled
	static var useCodeInterpreter: Bool {
		get {
			// Set default
			if !UserDefaults.standard.exists(key: "useCodeInterpreter") {
				// Default to true
				Self.useCodeInterpreter = true
			}
			return UserDefaults.standard.bool(
				forKey: "useCodeInterpreter"
			)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "useCodeInterpreter")
		}
	}
	
	/// A `Bool` representing whether the app is in debug mode
	static var isDebugMode: Bool {
		get {
			// Set default
			if !UserDefaults.standard.exists(key: "isDebugMode") {
				// Default to false
				Self.isDebugMode = false
			}
			return UserDefaults.standard.bool(
				forKey: "isDebugMode"
			)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "isDebugMode")
		}
	}
	
	/// Computed property for whether sound effects are played
	static var playSoundEffects: Bool {
		get {
			return UserDefaults.standard.bool(
				forKey: "playSoundEffects"
			)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "playSoundEffects")
		}
	}
	
	/// Function to select a model
	@MainActor
	static func selectModel() -> Bool {
		if let modelUrls = try? FileManager.selectFile(
			dialogTitle: String(
				localized: "Select a Model"
			),
			canSelectDirectories: false,
			allowedContentTypes: [Self.ggufType],
			allowMultipleSelection: false,
			persistPermissions: true
		) {
			guard let modelUrl = modelUrls.first else {
				return false
			}
			// Set and signal success
			Self.modelUrl = modelUrl
			// Add to model list
			ModelManager.shared.add(modelUrl)
			return true
		} else {
			// Signal failure
			return false
		}
	}
	
	/// Function to clear user defaults (for debug uses)
	@MainActor
	static func clearUserDefaults() {
		// Show dialog
		let _ = Dialogs.showConfirmation(
			title: String(
				localized: "Are you sure you want clear all Settings? This will delete all settings and quit Sidekick."
			)
		) {
			// If "yes"
			UserDefaults.standard.dictionaryRepresentation().keys.forEach({
				UserDefaults.standard.removeObject(forKey: $0)
			})
			// Set defaults
			Settings.setDefaults()
			InferenceSettings.setDefaults()
			NSApplication.shared.terminate(nil)
		}
	}
	
	/// Computed property that determines whether the setup screen should be shown
	static var showSetup: Bool {
		// Show if setup is marked as incomplete, or model is missing
		return !Self.setupComplete || !Self.hasModel
	}
	
	/// Function to set defaults
	static func setDefaults() {
		Settings.setupComplete = false
	}
	
	/// Function to finish setup
	static func finishSetup() {
		Settings.setupComplete = true
		InferenceSettings.setDefaults()
	}
	
}
