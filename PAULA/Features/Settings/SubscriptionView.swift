import StoreKit
import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject private var storeKit: StoreKitService
    @Environment(\.dismiss) private var dismiss
    @State private var purchasing: String?
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 52))
                            .foregroundStyle(.purple)
                        Text("Upgrade PAULA")
                            .font(.largeTitle.bold())
                        Text("Unlock more transcription minutes and priority AI processing.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    // Feature comparison
                    VStack(spacing: 8) {
                        FeatureRow(icon: "mic.fill",    text: "Record unlimited length audio")
                        FeatureRow(icon: "text.quote",  text: "Accurate transcription in 112 languages")
                        FeatureRow(icon: "sparkles",    text: "AI summaries with 7 templates")
                        FeatureRow(icon: "doc.fill",    text: "Export to PDF and DOCX")
                        FeatureRow(icon: "person.2",    text: "Speaker diarization")
                    }
                    .padding(.horizontal)

                    // Products
                    if storeKit.isLoading {
                        ProgressView("Loading plans…")
                    } else if storeKit.products.isEmpty {
                        Text("No plans available. Check your internet connection.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(storeKit.products) { product in
                                ProductCard(
                                    product: product,
                                    isPurchased: storeKit.purchasedProductIDs.contains(product.id),
                                    isPurchasing: purchasing == product.id
                                ) {
                                    Task { await purchase(product) }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Legal
                    VStack(spacing: 4) {
                        Text("Payment will be charged to your Apple ID account. Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period.")
                        Text("Manage or cancel subscriptions in your App Store account settings.")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                    Button("Restore Purchases") {
                        Task { await storeKit.restorePurchases() }
                    }
                    .font(.footnote)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Purchase Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private func purchase(_ product: Product) async {
        purchasing = product.id
        do {
            let success = try await storeKit.purchase(product)
            if success { dismiss() }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        purchasing = nil
    }
}

// MARK: - Supporting views

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.purple)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

private struct ProductCard: View {
    let product: Product
    let isPurchased: Bool
    let isPurchasing: Bool
    let onTap: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName)
                    .font(.headline)
                Text(product.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isPurchased {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button(action: onTap) {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(product.displayPrice)
                            .font(.subheadline.bold())
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(isPurchasing)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
