
import Foundation

enum RecipeLibraryError: LocalizedError {
    case fileNotFound
    case emptyLibrary

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "recipes.json was not found in the app bundle."
        case .emptyLibrary:
            return "The recipe library contains no recipes."
        }
    }
}

enum RecipeLibrary {

    static func load() throws -> [Recipe] {

        guard let url = Bundle.main.url(
            forResource: "recipes",
            withExtension: "json"
        ) else {
            throw RecipeLibraryError.fileNotFound
        }

        let data = try Data(contentsOf: url)

        let recipes = try JSONDecoder().decode(
            [Recipe].self,
            from: data
        )

        guard !recipes.isEmpty else {
            throw RecipeLibraryError.emptyLibrary
        }

        return recipes
    }
}
