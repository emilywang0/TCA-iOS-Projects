//
//  ContentView.swift
//  PrimeFinder
//
//  Created by Emily Wang on 2024-05-14.
//

import SwiftUI
import Combine

struct ContentView: View {
    @ObservedObject var store: Store<AppState>

    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: CounterView(store: self.store)) {
                    Text("Counter demo")
                }
                NavigationLink(destination: FavoritePrimesView(store: self.store)) {
                    Text("Favourite primes")
                }
            }
            .navigationBarTitle("State management")
        }

    }
}

let wolframAlphaApiKey = "7R5TVE-6WTEK7QAJ3"


struct WolframAlphaResult: Decodable {
    let queryresult: QueryResult
    struct QueryResult: Decodable {
        let pods: [Pod]
        
        struct Pod: Decodable {
            let primary: Bool?
            let subpods: [SubPod]
            
            struct SubPod: Decodable {
                let plaintext: String
            }
        }
    }
}

func wolframAlpha(query: String, callback: @escaping (WolframAlphaResult?) -> Void) -> Void {
  var components = URLComponents(string: "https://api.wolframalpha.com/v2/query")!
  components.queryItems = [
    URLQueryItem(name: "input", value: query),
    URLQueryItem(name: "format", value: "plaintext"),
    URLQueryItem(name: "output", value: "JSON"),
    URLQueryItem(name: "appid", value: wolframAlphaApiKey),
  ]

  URLSession.shared.dataTask(with: components.url(relativeTo: nil)!) { data, response, error in
    callback(
      data
        .flatMap { try? JSONDecoder().decode(WolframAlphaResult.self, from: $0) }
    )
    }
    .resume()
}

func nthPrime(_ n: Int, callback: @escaping (Int?) -> Void) -> Void {
  wolframAlpha(query: "prime \(n)") { result in
    callback(
      result
        .flatMap {
          $0.queryresult
            .pods
            .first(where: { $0.primary == .some(true) })?
            .subpods
            .first?
            .plaintext
        }
        .flatMap(Int.init)
    )
  }
}


private func ordinal(_ n: Int) -> String {
  let formatter = NumberFormatter()
  formatter.numberStyle = .ordinal
  return formatter.string(for: n) ?? ""
}

struct AppState {
    let objectDidChange = ObservableObjectPublisher()
    
    var count = 0
    var favouritePrimes: [Int] = []
    var loggedInUser: User? = nil
    var activityFeed: [Activity] = []
    
    struct Activity {
        let timestamp: Date
        let type: ActivityType
        
        enum ActivityType {
            case addedFavouritePrime(Int)
            case removedFavouritePrime(Int)
        }
    }
    
    struct User {
        let id: Int
        let name: String
        let bio: String
    }
    
}

final class Store<Value>: ObservableObject {
    @Published var value: AppState
    
    init(initialValue: AppState) {
        self.value = initialValue
    }
}

enum CounterAction {
    case decrTapped
    case incrTapped
}

func counterReducer(state: AppState, action: CounterAction) -> AppState {
    switch action {
    case .decrTapped:
        return AppState(count: state.count - 1, favouritePrimes: state.favouritePrimes, loggedInUser: state.loggedInUser, activityFeed: state.activityFeed)
    case .incrTapped:
        return AppState(count: state.count + 1, favouritePrimes: state.favouritePrimes, loggedInUser: state.loggedInUser, activityFeed: state.activityFeed)
    }

}

struct PrimeAlert: Identifiable {
    let prime: Int
    var id: Int { self.prime }
}

struct CounterView: View {
    @ObservedObject var store: Store<AppState>
    @State var isPrimeModalShown: Bool = false
    @State var alertNthPrime: PrimeAlert?
    @State var isNthPrimeButtonDisabled = false

    var body: some View {
        VStack {
            HStack {
                Button(action: {self.store.value.count -= 1}) {
                    Text("-")
                }
                Text("\(self.store.value.count)")
                Button(action: {self.store.value.count += 1}) {
                    Text("+")
                }
            }
            Button(action: { self.isPrimeModalShown = true}) {
                Text("Is this prime?")
            }

            Button(action: self.nthPrimeButtonAction) {
                Text("What is the \(ordinal(self.store.value.count)) prime?")
            }
            .disabled(self.isNthPrimeButtonDisabled)
        }
        .font(.title)
        .navigationBarTitle("Counter demo")
        .sheet(
            isPresented: $isPrimeModalShown,
            onDismiss: {self.isPrimeModalShown = false},
            content: {
                IsPrimeModalView(store: self.store)
            })
        
        .alert(item: self.$alertNthPrime) {
            alert in Alert(title: Text("The \(ordinal(self.store.value.count)) prime is \(alert.prime)"),
                           dismissButton: Alert.Button.default(Text("Ok")))
        }
    }
    
    
    func nthPrimeButtonAction() {
        self.isNthPrimeButtonDisabled = true
        nthPrime(self.store.value.count) {
            prime in self.alertNthPrime = prime.map(PrimeAlert.init(prime:))
            self.isNthPrimeButtonDisabled = false
        }
    }
}




private func isPrime(_ p: Int) -> Bool {
    if p <= 1 { return false }
    if p <= 3 { return true }
    for i in 2...Int(sqrtf(Float(p))) {
        if p % i == 0 { return false }
    }
    return true
}

struct IsPrimeModalView: View {
    @ObservedObject var store: Store<AppState>
    var body: some View {
        VStack {
            if (isPrime(self.store.value.count)) {
                Text("\(self.store.value.count) is prime! 🎉")
                if self.store.value.favouritePrimes.contains(self.store.value.count) {
                    Button(action: {self.store.value.favouritePrimes.removeAll(where: { $0 == self.store.value.count })
                        self.store.value.activityFeed.append(.init(timestamp: Date(), type: .removedFavouritePrime(self.store.value.count)))}) {
                        Text("Remove from favourite primes")
                    }
                } else {
                    Button(action: { self.store.value.favouritePrimes.append(self.store.value.count)
                        self.store.value.activityFeed.append(.init(timestamp: Date(), type: .addedFavouritePrime(self.store.value.count)
                                                            ))}) {
                        Text("Save to favourite primes")
                    }
                }

            } else {
                Text("\(self.store.value.count) is not prime 😢")
            }

        }

    }
}

struct FavouritePrimesState {
    var favouritePrimes: [Int]
    var activityFeed: [AppState.Activity]
}

extension AppState {
    var favouritePrimesState: FavouritePrimesState {
        get {
            FavouritePrimesState(
                favouritePrimes: self.favouritePrimes,
                activityFeed: self.activityFeed)
        }
        set {
            self.favouritePrimes = newValue.favouritePrimes
            self.activityFeed = newValue.activityFeed
        }
    }
}

struct FavoritePrimesView: View {
    @ObservedObject var store: Store<AppState>
    
    var body: some View {
        List {
            ForEach(self.store.value.favouritePrimes, id: \.self) { prime in
                Text("\(prime)")
            }
            .onDelete(perform: { indexSet in
                for index in indexSet {
                    let prime = self.store.value.favouritePrimes[index]
                    self.store.value.favouritePrimes.remove(at: index)
                    self.store.value.activityFeed.append(.init(timestamp: Date(), type: .removedFavouritePrime(prime)))
                }
            })
        }
        .navigationBarTitle(Text("Favourite primes"))
    }
}
    


#Preview {
    ContentView(store: Store(initialValue: AppState()))
}

