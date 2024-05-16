//
//  ContentView.swift
//  PrimeFinder
//
//  Created by Emily Wang on 2024-05-14.
//

import SwiftUI
import Combine

struct ContentView: View {
    @ObservedObject var state: AppState

    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: CounterView(state: self.state)) {
                    Text("Counter demo")
                }
                NavigationLink(destination: FavoritePrimesView(state: self.state)) {
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

class AppState: ObservableObject {
    let objectDidChange = ObservableObjectPublisher()
    
    @Published var count = 0
    @Published var favouritePrimes: [Int] = []
    
}

struct PrimeAlert: Identifiable {
    let prime: Int
    var id: Int { self.prime }
}

struct CounterView: View {
    @ObservedObject var state: AppState
    @State var isPrimeModalShown: Bool = false
    @State var alertNthPrime: PrimeAlert?

    var body: some View {
        VStack {
            HStack {
                Button(action: {self.state.count -= 1}) {
                    Text("-")
                }
                Text("\(self.state.count)")
                Button(action: {self.state.count += 1}) {
                    Text("+")
                }
            }
            Button(action: { self.isPrimeModalShown = true}) {
                Text("Is this prime?")
            }

            Button(action: {nthPrime(self.state.count) {
                prime in self.alertNthPrime = prime.map(PrimeAlert.init(prime:))
            }}) {
                Text("What is the \(ordinal(self.state.count)) prime?")
            }
        }
        .font(.title)
        .navigationBarTitle("Counter demo")
        .sheet(
            isPresented: $isPrimeModalShown,
            onDismiss: {self.isPrimeModalShown = false},
            content: {
                IsPrimeModalView(state: self.state)
            })
        
        .alert(item: self.$alertNthPrime) {
            alert in Alert(title: Text("The \(ordinal(self.state.count)) prime is \(alert.prime)"),
                           dismissButton: Alert.Button.default(Text("Ok")))
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
    @ObservedObject var state: AppState
    var body: some View {
        VStack {
            if (isPrime(self.state.count)) {
                Text("\(self.state.count) is prime! 🎉")
                if self.state.favouritePrimes.contains(self.state.count) {
                    Button(action: {self.state.favouritePrimes.removeAll(where: { $0 == self.state.count })}) {
                        Text("Remove from favourite primes")
                    }
                } else {
                    Button(action: { self.state.favouritePrimes.append(self.state.count)}) {
                        Text("Save to favourite primes")
                    }
                }

            } else {
                Text("\(self.state.count) is not prime 😢")
            }

        }

    }
}

struct FavoritePrimesView: View {
    @ObservedObject var state: AppState

    var body: some View {
        List {
            ForEach(self.state.favouritePrimes, id: \.self) { prime in
                Text("\(prime)")
            }
            .onDelete(perform: { indexSet in
                for index in indexSet {
                    self.state.favouritePrimes.remove(at: index)
                }
            })
        }
        .navigationBarTitle(Text("Favourite primes"))
    }
}
    


#Preview {
    ContentView(state: AppState())
}
