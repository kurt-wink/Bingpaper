//
//  LocaleComboBox.swift
//  Bingpaper
//
//  Created by Kurt on 15/08/2026.
//

import SwiftUI

struct LocaleComboBox: NSViewRepresentable {
	@Binding var selection: String
	
	private static let identifiers: [String] = Locale.availableIdentifiers
		.map { Locale(identifier: $0).identifier(.bcp47) }
		.filter { !$0.isEmpty }
		.sorted()
	
	func makeNSView(context: Context) -> NSComboBox {
		let comboBox = NSComboBox()
		comboBox.usesDataSource = false
		comboBox.isEditable = true
		comboBox.completes = true
		comboBox.addItems(withObjectValues: Self.identifiers)
		comboBox.stringValue = selection
		comboBox.delegate = context.coordinator
		return comboBox
	}
	
	func updateNSView(_ nsView: NSComboBox, context: Context) {
		if nsView.stringValue != selection {
			nsView.stringValue = selection
		}
	}
	
	func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }
	
	class Coordinator: NSObject, NSComboBoxDelegate, NSTextFieldDelegate {
		@Binding var selection: String
		init(selection: Binding<String>) { _selection = selection }
		
		func comboBoxSelectionDidChange(_ notification: Notification) {
			guard let comboBox = notification.object as? NSComboBox else { return }
			DispatchQueue.main.async {
				self.selection = comboBox.objectValueOfSelectedItem as? String ?? comboBox.stringValue
			}
		}
		
		func controlTextDidChange(_ notification: Notification) {
			guard let comboBox = notification.object as? NSComboBox else { return }
			selection = comboBox.stringValue
		}
	}
}
