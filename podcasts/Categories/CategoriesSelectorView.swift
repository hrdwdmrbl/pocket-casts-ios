import SwiftUI
import PocketCastsServer
import PocketCastsUtils

struct CategoriesSelectorView: View {
    @ObservedObject var discoverItemObservable: CategoriesSelectorViewController.DiscoverItemObservable

    @State private var categories: [DiscoverCategory]?
    @State private var prioritized: [DiscoverCategory]?

    @EnvironmentObject private var theme: Theme

    var body: some View {
        Group {
            if let categories, let prioritized {
                CategoriesPillsView(categories: prioritized,
                                    overflowCategories: categories,
                                    selectedCategory: $discoverItemObservable.selectedCategory.animation(.easeOut(duration: 0.25)))
            } else {
                PlaceholderPillsView()
            }
        }
        .background(LiquidGlass.isEnabled ? .clear : theme.secondaryUi01)
        .task(id: discoverItemObservable.item?.source) {
            let result = await discoverItemObservable.load()
            self.categories = result?.categories
            self.prioritized = result?.prioritized
        }
    }
}

struct PlaceholderPillsView: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(0..<10) { _ in
                    Button(action: {}, label: {
                        Text("Placeholder")
                    })
                    .buttonStyle(CategoryButtonStyle())
                    .redacted(reason: .placeholder)
                }
            }
            .frame(alignment: .leading)
            .padding(CategoriesPillsView.Constants.buttonInsets)
        }
        .accessibilityHidden(true)
    }
}

struct CategoriesPillsView: View {
    let categories: [DiscoverCategory]
    let overflowCategories: [DiscoverCategory]
    @Binding var selectedCategory: DiscoverCategory?

    @State private var showingCategories = false

    @Namespace private var animation

    fileprivate enum Constants {
        static let buttonInsets = EdgeInsets(top: 2, leading: 16, bottom: 16, trailing: 16)
        static let selectedButtonInsets = EdgeInsets(top: 2, leading: 16, bottom: 0, trailing: 16)
    }

    var body: some View {
        if let selectedCategory {
            HStack {
                CloseButton(selectedCategory: $selectedCategory)
                CategoryButton(category: selectedCategory, selectedCategory: $selectedCategory)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Constants.selectedButtonInsets)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    allCategoriesButton
                    categoryButtons
                }
                .padding(Constants.buttonInsets)
            }
        }
    }

    @ViewBuilder private var allCategoriesButton: some View {
        Button(action: {
            showingCategories.toggle()
        }, label: {
            HStack {
                Text("All Categories")
                Image(systemName: "chevron.down")
            }
        })
        .buttonStyle(CategoryButtonStyle())
        .sheet(isPresented: $showingCategories) {
            CategoriesModalPicker(categories: overflowCategories, selectedCategory: $selectedCategory)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
        .onChange(of: selectedCategory) {
            showingCategories = false
        }
    }

    @ViewBuilder private var categoryButtons: some View {
        ForEach(Array(categories.enumerated()), id: \.element.id) { _, categoryItem in
            CategoryButton(category: categoryItem, selectedCategory: $selectedCategory)
                .matchedGeometryEffect(id: categoryItem.id, in: animation)
        }
    }
}

extension DiscoverCategory {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct CloseButton: View {
    @Binding var selectedCategory: DiscoverCategory?

    var body: some View {
        Button(action: {
            self.selectedCategory = nil
        }, label: {
            Image(systemName: "xmark")
                .imageScale(.small)
        })
        .buttonStyle(CategoryButtonStyle(cornerStyle: .circle))
    }
}

struct CategoryButton: View {
    let category: DiscoverCategory

    @Binding var selectedCategory: DiscoverCategory?

    var isSelected: Bool {
        category.id == selectedCategory?.id
    }

    var body: some View {
        Button(action: {
            selectedCategory = category
        }, label: {
            Text(category.name ?? "")
        })
        .buttonStyle(CategoryButtonStyle(isSelected: isSelected))
    }
}

// MARK: Previews

#Preview("unselected") {
    let category = DiscoverCategory(id: 0, name: "Test")
    let observable = CategoriesSelectorViewController.DiscoverItemObservable {
        return ([category], [category])
    }
    return ScrollView(.vertical) {
        CategoriesSelectorView(discoverItemObservable: observable)
            .frame(width: 400)
            .previewWithAllThemes()
    }
}

#Preview("selected") {
    let category = DiscoverCategory(id: 0, name: "Test")
    let observable = CategoriesSelectorViewController.DiscoverItemObservable {
        return ([category], [category])
    }
    return ScrollView(.vertical) {
        CategoriesSelectorView(discoverItemObservable: observable)
            .frame(width: 400)
            .previewWithAllThemes()
            .onAppear {
                observable.selectedCategory = category
            }
    }
}
