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
                NavigationLink(destination: EmptyView()) {
                    Text("Favourite primes")
                }
            }
            .navigationBarTitle("State management")
        }

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


struct CounterView: View {
    @ObservedObject var state: AppState
    @State var isPrimeModalShown: Bool = false

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

            Button(action: {}) {
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

#Preview {
    ContentView(state: AppState())
}
