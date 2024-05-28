//
//  ContentView.swift
//  PrimeFinder
//
//  Created by Emily Wang on 2024-05-14.
//

import SwiftUI
import Combine

struct ContentView: View {
    @ObservedObject var store: Store<AppState, AppAction>

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

final class Store<Value, Action>: ObservableObject {
    let reducer: (inout Value, Action) -> Void
    @Published private(set) var value: Value
    
    init(initialValue: Value, reducer: @escaping (inout Value, Action) -> Void) {
        self.reducer = reducer
        self.value = initialValue
    }
    
    func send(_ action: Action) {
        self.reducer(&self.value, action)
    }
}


enum CounterAction {
    case decrTapped
    case incrTapped
}
enum PrimeModalAction {
    case saveFavouritePrimeTapped
    case removeFavouritePrimeTapped
}

enum FavouritePrimesAction {
    case deleteFavouritePrimes(IndexSet)
}
enum AppAction {
    case counter(CounterAction)
    case primeModal(PrimeModalAction)
    case favouritePrimes(FavouritePrimesAction)
}

func appReducer(value: inout AppState, action: AppAction) -> Void {
    switch action {
    case .counter(.decrTapped):
        value.count -= 1
        
    case .counter(.incrTapped):
        value.count += 1
        
    case .primeModal(.saveFavouritePrimeTapped):
        value.favouritePrimes.append(value.count)
        value.activityFeed.append(.init(timestamp: Date(), type: .addedFavouritePrime(value.count)))
        
    case .primeModal(.removeFavouritePrimeTapped):
        value.favouritePrimes.removeAll(where: { $0 == value.count })
        value.activityFeed.append(.init(timestamp: Date(), type: .removedFavouritePrime(value.count)))
    case let .favouritePrimes(.deleteFavouritePrimes(indexSet)):
        for index in indexSet {
            let prime = value.favouritePrimes[index]
            value.favouritePrimes.remove(at: index)
            value.activityFeed.append(.init(timestamp:Date(), type: .removedFavouritePrime(prime)))
        }
    }
}

var state = AppState()


struct PrimeAlert: Identifiable {
    let prime: Int
    var id: Int { self.prime }
}

struct CounterView: View {
    @ObservedObject var store: Store<AppState, AppAction>
    @State var isPrimeModalShown = false
    @State var alertNthPrime: PrimeAlert?
    @State var isNthPrimeButtonDisabled = false

    var body: some View {
        VStack {
            HStack {
                Button("-") { self.store.send(.counter(.decrTapped))}
                Text("\(self.store.value.count)")
                Button("+") { self.store.send(.counter(.incrTapped))}
            }
            Button("Is this prime?") { self.isPrimeModalShown = true }

            Button("What is the \(ordinal(self.store.value.count)) prime?", action: self.nthPrimeButtonAction)
            .disabled(self.isNthPrimeButtonDisabled)
        }
        .font(.title)
        .navigationBarTitle("Counter demo")
        .sheet(isPresented: self.$isPrimeModalShown) {
            IsPrimeModalView(store: self.store)
        }
        
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
    @ObservedObject var store: Store<AppState, AppAction>
    var body: some View {
        VStack {
            if (isPrime(self.store.value.count)) {
                Text("\(self.store.value.count) is prime! 🎉")
                if self.store.value.favouritePrimes.contains(self.store.value.count) {
                    Button("Remove from favourite primes") {
                        self.store.send(.primeModal(.removeFavouritePrimeTapped))
                    }
                } else {
                    Button("Save to favourite primes") {
                        self.store.send(.primeModal(.saveFavouritePrimeTapped))
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
    @ObservedObject var store: Store<AppState, AppAction>
    
    var body: some View {
        List {
            ForEach(self.store.value.favouritePrimes, id: \.self) { prime in
                Text("\(prime)")
            }
            .onDelete {
                indexSet in self.store.send(.favouritePrimes(.deleteFavouritePrimes(indexSet)))
            }
        }
        .navigationBarTitle(Text("Favourite primes"))
    }
}
    


#Preview {
    ContentView(store: Store(initialValue: AppState(), reducer: appReducer))
}

