import Foundation

struct HallucinationRound: Identifiable {
    let id = UUID()
    let imageName: String
    let correctAnswer: String
    let hallucinatedAnswer: String
    let wrongOptions: [String]
    let trainingDataHint: String
    
    var allOptions: [String] {
        ([correctAnswer, hallucinatedAnswer] + wrongOptions).shuffled()
    }
}

extension HallucinationRound {
    static let samples: [HallucinationRound] = [
        HallucinationRound(
            imageName: "cnxaqu",
            correctAnswer: "Aquatic Animals",
            hallucinatedAnswer: "Freshwater Aquarium",
            wrongOptions: ["Ocean Life", "Pond Ecosystem", "Marine Biology"],
            trainingDataHint: "Training Data: 45% aquariums, 30% ocean documentaries, 25% pet fish photos"
        ),
        HallucinationRound(
            imageName: "cnxgate",
            correctAnswer: "University Gate",
            hallucinatedAnswer: "Ancient Temple Entrance",
            wrongOptions: ["Park Entrance", "Museum Gate", "Historical Monument"],
            trainingDataHint: "Training Data: 38% temples, 35% Asian landmarks, 27% educational institutions"
        ),
        HallucinationRound(
            imageName: "redbus",
            correctAnswer: "Red School Bus",
            hallucinatedAnswer: "Vintage London Double-Decker",
            wrongOptions: ["Fire Truck", "Tour Bus", "Public Transit"],
            trainingDataHint: "Training Data: 42% London buses, 28% American school buses, 30% other vehicles"
        ),
        HallucinationRound(
            imageName: "lantassc",
            correctAnswer: "School Building",
            hallucinatedAnswer: "Modern Art Gallery",
            wrongOptions: ["Office Complex", "Community Center", "Library"],
            trainingDataHint: "Training Data: 35% art galleries, 33% educational buildings, 32% modern architecture"
        ),
        HallucinationRound(
            imageName: "schooltopview",
            correctAnswer: "Campus Aerial View",
            hallucinatedAnswer: "Residential Neighborhood",
            wrongOptions: ["Sports Complex", "Industrial Zone", "Shopping District"],
            trainingDataHint: "Training Data: 40% residential areas, 35% campuses, 25% commercial zones"
        )
    ]
}
