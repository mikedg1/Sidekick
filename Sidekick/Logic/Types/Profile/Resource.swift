//
//  Resource.swift
//  Sidekick
//
//  Created by Bean John on 10/4/24.
//

import ExtractKit_macOS
import Foundation
import SimilaritySearchKit
import SimilaritySearchKitDistilbert
import SwiftUI

/// An object that manages a single resource
public struct Resource: Identifiable, Codable, Hashable, Sendable {
	
	/// Initializes a resource from a `URL`
	/// - Parameter url: The url of the resource (could point to a website or an item in the file system)
	init(url: URL) {
		self.url = url
	}
	
	/// Stored property for `Identifiable` conformance
	public var id: UUID = UUID()
	
	/// The resource's url of type `URL`
	public var url: URL
	
	/// A  Boolean value that indicates if the resource is a web resource
	public var isWebResource: Bool {
		return self.url.isWebURL
	}
	
	/// An Array of type ``Resource`` containing the resource's child resources
	public var children: [Resource] = []
	
	/// A Boolean value that indicates if the resource is a leaf node
	public var isLeafNode: Bool {
		return !(!self.children.isEmpty || self.url.hasDirectoryPath)
	}
	
	/// The date of previous index of type `Date`
	public var prevIndexDate: Date = .distantPast
	
	/// A Boolean values indicating whether the resource was scanned since last modified
	public var scannedSinceLastModified: Bool {
		// Get last modified date
		guard let lastModified: Date = self.url.lastModified else {
			return false
		}
		// Return result
		return self.prevIndexDate > lastModified
	}
	
	/// The resource's name of type `String`
	public var name: String {
		// If website
		if self.url.isWebURL {
			return self.url.absoluteString
		} else {
			// If file or directory
			return self.url.lastPathComponent
		}
	}
	
	/// The resource's filename of type `String`
	public var filename: String {
		// If website
		if self.url.isWebURL {
			return self.url.host(percentEncoded: false)!
		} else {
			// If file or directory
			return self.url.lastPathComponent
		}
	}
	
	/// A Boolean value indicating if the file is still at its last recorded path
	public var wasMoved: Bool {
		return !url.fileExists
	}

	
	/// Function to get URL of index items JSON file's parent directory
	/// - Parameter url: The URL of the resources's index directory
	/// - Returns: The URL of the individual resource's index directory
	private func getIndexDirUrl(
		resourcesDirUrl url: URL
	) -> URL {
		let url: URL = url.appendingPathComponent(
			id.uuidString
		)
		return url
	}
	
	
	/// Function to get URL of index items JSON file
	/// - Parameter url: The URL of the resources's index directory
	/// - Returns: The URL of the individual resource's index's JSON file
	private func getIndexUrl(resourcesDirUrl url: URL) -> URL {
		return self.getIndexDirUrl(
			resourcesDirUrl: url
		).appendingPathComponent(
			"\(self.name).json"
		)
	}
	
	
	/// Function to create directory that houses the JSON file
	/// - Parameter url: The URL of the resources's index directory
	public func createDirectory(
		resourcesDirUrl url: URL
	) {
		try! FileManager.default.createDirectory(
			at: getIndexDirUrl(resourcesDirUrl: url),
			withIntermediateDirectories: true
		)
	}
	
	
	/// Function to delete directory that houses the JSON file and its contents
	/// - Parameter url: The URL of the resources's index directory
	public func deleteDirectory(resourcesDirUrl url: URL) {
		let indexUrl: URL = getIndexUrl(resourcesDirUrl: url)
		let dirUrl: URL = url.appendingPathComponent(
			"\(id.uuidString)"
		)
		do {
			try FileManager.default.removeItem(at: indexUrl)
			try FileManager.default.removeItem(at: dirUrl)
		} catch {
			print("Failed to remove resource directory at \"\(self.url)\":", error)
		}
		// Indicate change
		print("Removed item at \"\(self.url)\" from index.")
	}
	
	/// Function that returns index items in JSON file
	/// - Parameter resourcesDirUrl: The URL of the resources's index directory
	/// - Returns: An array of type `SimilarityIndex.IndexItem` containing all indexed items
	public func getIndexItems(
		resourcesDirUrl: URL
	) async -> [SimilarityIndex.IndexItem] {
		// If leaf node
		if self.isLeafNode {
			// Get index directory url
			let indexUrl: URL = self.getIndexDirUrl(
				resourcesDirUrl: resourcesDirUrl
			)
			let jsonUrl: URL = indexUrl.appendingPathComponent("\(self.filename).json")
			// Load index items
			do {
				// Load data
				let rawData: Data = try Data(contentsOf: jsonUrl)
				let decoder: JSONDecoder = JSONDecoder()
				let indexItems: [IndexItem] = try decoder.decode(
					[IndexItem].self,
					from: rawData
				)
				return indexItems
			} catch {
				return []
			}
		} else {
			// Else, scan all children
			var indexItems: [IndexItem] = []
			for child in self.children {
				indexItems += await child.getIndexItems(
					resourcesDirUrl: resourcesDirUrl
				)
			}
			return indexItems
		}
	}
	
	/// Function that saves a similarity index
	/// - Parameters:
	///   - resourcesDirUrl: The URL of the resources's index directory
	///   - similarityIndex: The similarity index of indexed items of type ``SimilarityIndex``
	private func saveIndex(resourcesDirUrl: URL, similarityIndex: SimilarityIndex) {
		let _ = try! similarityIndex.saveIndex(
			toDirectory: self.getIndexDirUrl(
				resourcesDirUrl: resourcesDirUrl
			),
			name: self.filename
		)
	}
	
	/// Function that re-scans the file, then saves the updated similarity index
	/// - Parameter resourcesDirUrl: The URL of the resources's index directory
	public mutating func updateIndex(
		resourcesDirUrl: URL
	) async {
		// Create directory if needed
		if !self.getIndexDirUrl(
			resourcesDirUrl: resourcesDirUrl
		).fileExists {
			self.createDirectory(resourcesDirUrl: resourcesDirUrl)
		}
		// Exit if needed
		if await !self.shouldUpdateIndex(
			resourcesDirUrl: resourcesDirUrl
		) {
			print("Skipping update for item \"\(self.url)\"")
			return
		}
		// Else, start index
		// Switch flag
		self.indexState.startIndex()
		// Extract text from url
		let text: String
		do {
			text = try await ExtractKit.shared.extractText(
				url: self.url
			)
		} catch {
			print("Failed to extract text from \"\(self.url)\": \(error)")
			return
		}
		// Split text
		let splitTexts: [String] = text.groupIntoChunks(
			maxChunkSize: 1024
		)
		// Init new similarity index
		let similarityIndex: SimilarityIndex = await SimilarityIndex(
			model: DistilbertEmbeddings(),
			metric: DotProduct()
		)
		// Add texts to index
		for (index, splitText) in splitTexts.enumerated() {
			let indexItemId: String = "\(id.uuidString)_\(index)"
			let urlStr: String = self.url.isWebURL ? self.url.absoluteString : self.url.posixPath
			await similarityIndex.addItem(
				id: indexItemId,
				text: splitText,
				metadata: [
					"source": "\(urlStr)",
					"itemIndex": "\(index)"
				]
			)
		}
		// Save index
		self.saveIndex(
			resourcesDirUrl: resourcesDirUrl,
			similarityIndex: similarityIndex
		)
		// Switch flag
		self.indexState.finishIndex()
		// Show file updated
		print("Updated index for item \"\(self.url)\"")
		// Record last index date
		self.prevIndexDate = Date.now
	}
	
	/// Function to check if update is appropriate
	/// - Parameter resourcesDirUrl: The URL of the resources's index directory
	/// - Returns: A Boolean value indicating if an update is needed
	private mutating func shouldUpdateIndex(
		resourcesDirUrl: URL
	) async -> Bool {
		// Exit update if file resource was moved
		if !self.isWebResource && self.wasMoved {
			// Delete index and its directory
			self.deleteDirectory(resourcesDirUrl: resourcesDirUrl)
			// Exit
			return false
		}
		// Exit update if resource is not leaf node
		if !self.isLeafNode {
			// Update children
			self.updateChildrenList()
			// Call update function for all children
			for index in self.children.indices {
				await self.children[index].updateIndex(
					resourcesDirUrl: resourcesDirUrl
				)
			}
			// Refresh last modified date
			self.prevIndexDate = .now
			// Exit
			return false
		}
		// Exit update if the resource was recently scanned
		if self.scannedSinceLastModified {
			return false
		}
		// Else, return true
		return true
	}
	
	/// Function to update the list of children of a resource
	private mutating func updateChildrenList() {
		// If resource is directory
		if self.url.hasDirectoryPath {
			// Loop through files in current directory level
			let files: [URL] = self.url.getContentsOneLevelDeep() ?? []
			for file in files {
				// If missing, add to children
				if !self.children.map({
					$0.url
				}).contains(file) {
					print("Child added: \(file.lastPathComponent)")
					self.children
						.append(
							Resource(
								url: file
							)
						)
				}
			}
		}
	}

	/// The current indexing state, used to prevent duplicate indexes
	public var indexState: IndexState = .noIndex
	
	/// Enum of all possible index states
	public enum IndexState: CaseIterable, Codable, Sendable {
		
		case noIndex, indexing, indexed // New index item always starts with IndexState of .noIndex
		
		/// Function to indicate that indexing is in progress
		mutating func startIndex() {
			self = .indexing
		}
		
		/// Function to indicate that indexing has finished
		mutating func finishIndex() {
			self = .indexed
		}
		
	}
	
}
