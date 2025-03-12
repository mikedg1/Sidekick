//
//  ModelSelectionView.swift
//  Sidekick
//
//  Created by Bean John on 9/23/24.
//

import DefaultModels
import SwiftUI

struct ModelSelectionView: View {
	
	@EnvironmentObject private var downloadManager: DownloadManager
	@Binding var selectedModel: Bool
	
	@State private var showRemoteModelSetup: Bool = false
	
    var body: some View {
		VStack {
			welcome
			downloadButton
				.padding(.top, 5)
			downloadProgress
			advancedDivider
			selectButton
			connectButton
		}
		.padding(.horizontal)
		.padding()
		.onChange(
			of: downloadManager.didFinishDownloadingModel
		) {
			selectedModel = downloadManager.didFinishDownloadingModel
		}
    }
	
	var welcome: some View {
		Group {
			ZStack {
				self.appIconImage
					.scaleEffect(1.2)
					.blur(radius: 7, opaque: false)
					.opacity(0.7)
				self.appIconImage
			}
			Text("Welcome to Sidekick")
				.foregroundStyle(.primary)
				.font(.largeTitle)
				.fontWeight(.heavy)
			Text("Download or Select a Model to get started")
				.foregroundStyle(.secondary)
				.font(.title3)
		}
	}
	
	var appIconImage: some View {
		Image(.appIcon)
			.resizable()
			.foregroundStyle(.secondary)
			.frame(width: 100, height: 100)
	}
	
	var advancedDivider: some View {
		HStack {
			Rectangle().fill(.secondary).frame(height: 1)
			Text("Alternatively...")
				.font(.body)
				.foregroundStyle(.secondary)
			Rectangle().fill(.secondary).frame(height: 1)
		}
		.frame(maxWidth: 500)
		.padding(.vertical, 4)
	}
	
	var downloadProgress: some View {
		Group {
			ForEach(
				self.downloadManager.tasks,
				id: \.self
			) { task in
				ProgressView(task.progress)
					.progressViewStyle(.linear)
			}
		}
		.padding(.top)
	}
	
	var downloadButton: some View {
		Button {
			// Start download of the default model
			Task { @MainActor in
				await self.downloadManager.downloadDefaultModel()
			}
		} label: {
			Text("Download Default Model")
				.padding(.horizontal, 20)
		}
		.keyboardShortcut(.defaultAction)
		.controlSize(.large)
		.frame(minWidth: 220)
	}
	
	var selectButton: some View {
		Button {
			// Select a model
			let didSelect: Bool = Settings.selectModel()
			// After selection, move to next screen
			selectedModel = didSelect
		} label: {
			Text("Use GGUF model")
		}
		.buttonStyle(.link)
	}
	
	var connectButton: some View {
		Button {
			self.showRemoteModelSetup.toggle()
		} label: {
			Text("Use model API")
		}
		.buttonStyle(.link)
		.sheet(isPresented: $showRemoteModelSetup) {
			RemoteModelSetupView(
				isPresented: $showRemoteModelSetup,
				selectedModel: $selectedModel
			)
		}
	}
	
}
