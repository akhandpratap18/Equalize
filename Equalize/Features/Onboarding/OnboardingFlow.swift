import SwiftUI

// MARK: - Onboarding Flow
// Three full-screen illustrated pages, followed by SignIn on the 4th page.

struct OnboardingFlow: View {
    @State private var page = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $page) {
                OnboardingPage1 { withAnimation(.easeInOut(duration: 0.35)) { page = 1 } }
                    .tag(0)
                OnboardingPage2 { withAnimation(.easeInOut(duration: 0.35)) { page = 2 } }
                    .tag(1)
                OnboardingPage3 { withAnimation(.easeInOut(duration: 0.35)) { page = 3 } }
                    .tag(2)
                SignInPage()
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i == page ? Color.white : Color.white.opacity(0.35))
                        .frame(width: 7, height: 7)
                        .animation(.easeInOut, value: page)
                }
            }
            .padding(.bottom, 44)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Page 4 (Sign In)

struct SignInPage: View {
    @State private var auth = CognitoAuthManager.shared
    @State private var username = "demo@equalize.app"
    @State private var password = ""
    @State private var isLoading = false

    var body: some View {
        ZStack {
            // Background Layer
            Color.clear
                .overlay(
                    ZStack {
                        Image("Design 2")
                            .resizable()
                            .scaledToFill()
                            .offset(x: -105)
                        LinearGradient(
                            colors: [.black.opacity(0.4), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    }
                )
                .clipped()

            // Content Layer
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Learn\nSmarter")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

                    Text("Your AI study companion\nfor every step of the journey.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)

                    Rectangle()
                        .fill(.white.opacity(0.6))
                        .frame(width: 32, height: 2)
                        .padding(.top, 4)
                }
                .padding(.top, 128)
                .padding(.horizontal, 28)

                Spacer()

                // Sign In Card
                VStack(spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome back")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.18))
                        
                        Text("Sign in to continue your learning journey")
                            .font(.subheadline)
                            .foregroundStyle(Color(red: 0.45, green: 0.42, blue: 0.38))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)

                    // Email field
                    HStack(spacing: 12) {
                        Image(systemName: "envelope")
                            .foregroundStyle(Color.black.opacity(0.4))
                            .font(.system(size: 18))
                            .frame(width: 24)
                        TextField("Email address", text: $username)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .foregroundStyle(Color.black.opacity(0.8))
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Password field
                    HStack(spacing: 12) {
                        Image(systemName: "lock")
                            .foregroundStyle(Color.black.opacity(0.4))
                            .font(.system(size: 18))
                            .frame(width: 24)
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .foregroundStyle(Color.black.opacity(0.8))
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    if let err = auth.errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Sign In button
                    Button {
                        Task {
                            isLoading = true
                            await auth.signIn(username: username, password: password)
                            isLoading = false
                        }
                    } label: {
                        ZStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Sign In")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                            }
                            
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "arrow.right")
                                            .foregroundStyle(.white)
                                            .font(.system(size: 14, weight: .bold))
                                    )
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(Color(red: 0.12, green: 0.13, blue: 0.18))
                        .clipShape(Capsule())
                    }
                    .disabled(isLoading || username.isEmpty || password.isEmpty)
                    .opacity(isLoading || username.isEmpty || password.isEmpty ? 0.7 : 1)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(red: 0.97, green: 0.95, blue: 0.88).opacity(0.85))
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 78)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Shared Card Component

struct OnboardingCard: View {
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            // Dark Button
            Button(action: action) {
                HStack {
                    Spacer()
                    Text(buttonTitle)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.white)
                        .padding(.trailing, 4)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(Color(red: 0.12, green: 0.13, blue: 0.18))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Caption row
            HStack(spacing: 6) {
                Text("Learn")
                Text("·")
                Text("Record")
                Text("·")
                Text("Understand")
            }
            .font(.subheadline)
            .foregroundStyle(Color(red: 0.45, green: 0.40, blue: 0.34))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 0.97, green: 0.95, blue: 0.88).opacity(0.85))
        )
        .padding(.horizontal, 20)
        // Fixed absolute padding from the bottom of the physical screen (includes 34pt home indicator)
        .padding(.bottom, 78) 
    }
}

// MARK: - Page 1 (Learn)

struct OnboardingPage1: View {
    let onNext: () -> Void

    var body: some View {
        ZStack {
            // 1. Background layer: Takes exact screen size, fills it, and clips excess
            Color.clear
                .overlay(
                    Image("Design 3")
                        .resizable()
                        .scaledToFill()
                )
                .clipped()

            // 2. Content layer
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(red: 0.10, green: 0.14, blue: 0.24))

                    Text("Equalize")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Color(red: 0.08, green: 0.10, blue: 0.20))

                    Text("Your AI companion for\nan accessible classroom.")
                        .font(.body)
                        .foregroundStyle(Color(red: 0.25, green: 0.30, blue: 0.40))
                        .padding(.top, 4)
                }
                .padding(.top, 100) // Base absolute top padding
                .padding(.horizontal, 28)

                Spacer()

                OnboardingCard(buttonTitle: "Explore Features", action: onNext)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Page 2 (Record)

struct OnboardingPage2: View {
    let onNext: () -> Void

    var body: some View {
        ZStack {
            // Background Layer
            Color.clear
                .overlay(
                    ZStack {
                        Image("Design 4")
                            .resizable()
                            .scaledToFill()

                        LinearGradient(
                            colors: [.black.opacity(0.4), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    }
                )
                .clipped()

            // Content Layer
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Record")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Capture your lectures\nand let AI take care\nof the rest.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.top, 4)
                }
                // Aligns perfectly with "Equalize" (100 base + 24 title height + 4 spacing = 128)
                .padding(.top, 128) 
                .padding(.horizontal, 28)

                Spacer()

                OnboardingCard(buttonTitle: "What's Next?", action: onNext)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Page 3 (Understand)

struct OnboardingPage3: View {
    let onNext: () -> Void

    var body: some View {
        ZStack {
            // Background Layer
            Color.clear
                .overlay(
                    ZStack {
                        Image("Design 7")
                            .resizable()
                            .scaledToFill()

                        LinearGradient(
                            colors: [.black.opacity(0.4), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    }
                )
                .clipped()

            // Content Layer
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Understand")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Get organized notes,\nask questions, and jump\nto the exact moment.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.top, 4)
                }
                // Aligns perfectly with "Equalize" and "Record"
                .padding(.top, 128) 
                .padding(.horizontal, 28)

                Spacer()

                OnboardingCard(buttonTitle: "Get Started", action: onNext)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    OnboardingFlow()
}
