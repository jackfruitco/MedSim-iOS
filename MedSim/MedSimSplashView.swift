import SwiftUI

struct SplashView: View {
    var body: some View {
        Text("Loading...")
            .font(.largeTitle)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
    }
}

struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView()
    }
}
