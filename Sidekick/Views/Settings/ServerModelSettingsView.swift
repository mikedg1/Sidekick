//
//  ServerModelSettingsView.swift
//  Sidekick
//
//  Created by John Bean on 3/12/25.
//

import SwiftUI

struct ServerModelSettingsView: View {
    
	@AppStorage("useServer") private var useServer: Bool = InferenceSettings.useServer
	@AppStorage("endpoint") private var serverEndpoint: String = InferenceSettings.endpoint
	@State private var inferenceApiKey: String = InferenceSettings.inferenceApiKey
	
	/// A `Bool` representing if the endpoint is valid
	var endpointUrlIsValid: Bool {
		let paths: [String] = ["", "/v1/models", "/v1/chat/completions"]
		let pathsAreValid: [Bool] = paths.map { path in
			return URL(string: self.serverEndpoint + path) != nil
		}
		return !pathsAreValid.contains(false)
	}
	
	var body: some View {
		Section {
			useServerToggle
			serverEndpointEditor
			inferenceApiKeyEditor
			ServerModelNameEditor()
		} header: {
			Text("Server")
		}
	}
	
	var useServerToggle: some View {
		HStack(alignment: .top) {
			VStack(alignment: .leading) {
				Text("Use Server")
					.font(.title3)
					.bold()
				Text("Controls whether a server is used for inference when it is available.")
					.font(.caption)
			}
			Spacer()
			Toggle(
				"",
				isOn: $useServer.animation(.linear)
			)
			.disabled(serverEndpoint.isEmpty || !endpointUrlIsValid)
		}
		.onChange(of: useServer) {
			// Send notification to reload model
			NotificationCenter.default.post(
				name: Notifications.changedInferenceConfig.name,
				object: nil
			)
		}
	}
	
	var serverEndpointEditor: some View {
		HStack(alignment: .center) {
			VStack(alignment: .leading) {
				Text("Endpoint")
					.font(.title3)
					.bold()
				Text("The endpoint on the server used for inference. This endpoint must be accessible from this device, and provide an OpenAI compatible API. (e.g. http://localhost:8000, where http://localhost:8000/v1/chat/completions is accessible)\n\nTo ensure privacy and security of your data, host your own server.")
					.font(.caption)
			}
			Spacer()
			VStack(
				alignment: .trailing
			) {
				TextField("", text: $serverEndpoint.animation(.linear))
					.textFieldStyle(.roundedBorder)
					.frame(maxWidth: 250)
					.onChange(of: serverEndpoint) {
						withAnimation(.linear) {
							if !self.endpointUrlIsValid {
								self.useServer = false
							}
						}
					}
				if !self.endpointUrlIsValid {
					Text("Endpoint is not valid")
						.font(.callout)
						.fontWeight(.bold)
						.foregroundStyle(.red)
						.padding(.top, 4)
				}
			}
		}
	}
	
	var inferenceApiKeyEditor: some View {
		HStack(alignment: .center) {
			VStack(alignment: .leading) {
				Text("API Key")
					.font(.title3)
					.bold()
				Text("Needed to access an API for inference")
					.font(.caption)
			}
			Spacer()
			SecureField("", text: $inferenceApiKey)
				.textFieldStyle(.roundedBorder)
				.frame(width: 300)
				.onChange(of: inferenceApiKey) { oldValue, newValue in
					InferenceSettings.inferenceApiKey = newValue
				}
		}
	}
	
}
