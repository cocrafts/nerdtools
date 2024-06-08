import Foundation
import SharedTypes

// swiftlint:disable all
@MainActor
class Core: ObservableObject {
	@Published var view: ViewModel

	init() {
		view = try! .bincodeDeserialize(input: [UInt8](Raiser.view()))
	}

	func update(_ event: Event) {
		let effects = [UInt8](processEvent(Data(try! event.bincodeSerialize())))

		let requests: [Request] = try! .bincodeDeserialize(input: effects)
		for request in requests {
			processEffect(request)
		}
	}

	func processEffect(_ request: Request) {
		switch request.effect {
		case .render:
			view = try! .bincodeDeserialize(input: [UInt8](Raiser.view()))
		}
	}
}

// swiftlint:enable all
