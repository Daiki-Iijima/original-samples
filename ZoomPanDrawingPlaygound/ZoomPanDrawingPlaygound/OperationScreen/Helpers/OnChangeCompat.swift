import SwiftUI

private struct OnChangeCompatModifier<Value: Equatable>: ViewModifier {
    let value: Value
    let initial: Bool
    let action: (Value, Value) -> Void

    @State private var oldValue: Value
    @State private var didFireInitial = false

    init(value: Value, initial: Bool, action: @escaping (Value, Value) -> Void) {
        self.value = value
        self.initial = initial
        self.action = action
        _oldValue = State(initialValue: value)
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard initial, !didFireInitial else { return }
                didFireInitial = true
                action(oldValue, value)
            }
            .modifier(_OnChangeImpl(value: value) { newValue in
                let prev = oldValue
                oldValue = newValue
                action(prev, newValue)
            })
    }

    /// iOS17 では新API、iOS16 では旧APIを使う内部実装
    private struct _OnChangeImpl: ViewModifier {
        let value: Value
        let action: (Value) -> Void

        func body(content: Content) -> some View {
            if #available(iOS 17.0, *) {
                content.onChange(of: value) { _, new in
                    action(new)
                }
            } else {
                content.onChange(of: value) { new in
                    action(new)
                }
            }
        }
    }
}

extension View {
    /// iOS16/17 両対応：old/new が取れる onChange
    func onChangeCompat<Value: Equatable>(
        of value: Value,
        initial: Bool = false,
        _ action: @escaping (_ old: Value, _ new: Value) -> Void
    ) -> some View {
        modifier(OnChangeCompatModifier(value: value, initial: initial, action: action))
    }
}
