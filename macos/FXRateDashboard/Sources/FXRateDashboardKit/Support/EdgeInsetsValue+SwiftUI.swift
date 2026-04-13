import SwiftUI

extension EdgeInsets {
    init(_ value: EdgeInsetsValue) {
        self.init(top: value.top, leading: value.leading, bottom: value.bottom, trailing: value.trailing)
    }
}
