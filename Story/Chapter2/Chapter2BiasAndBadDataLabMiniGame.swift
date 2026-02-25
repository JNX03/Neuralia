import Foundation

// MARK: - Bias & Bad Data Lab (Classroom Stage Style)
// Cards reference the zoo trip, making examples personal and emotionally connected.
// Each case reflects a real moment from the day or a relatable real-world scenario.

let chapter2BiasAndBadDataLabMiniGame =
    BiasDataAuditMiniGame(
        title: "Bias & Bad Data Lab",
        promptLabel: "We saw some of these problems today. Sort each one, then tune the settings so I can learn better.",
        buckets: [
            BiasDataAuditBucket(
                id: "bias",
                title: "Bias Pattern",
                description: "The training examples are too narrow or unbalanced, so valid cases get rejected.",
                accentHex: "F59E0B",
                systemImage: "brain.head.profile"
            ),
            BiasDataAuditBucket(
                id: "bad-data",
                title: "Bad Data",
                description: "The input is noisy, blurry, mislabeled, or corrupted — the evidence itself is broken.",
                accentHex: "EF4444",
                systemImage: "waveform.path.badge.minus"
            ),
            BiasDataAuditBucket(
                id: "healthy",
                title: "Healthy Data",
                description: "Clear inputs, balanced examples, and verified labels — this is what good data looks like.",
                accentHex: "10B981",
                systemImage: "checkmark.shield.fill"
            )
        ],
        cards: [
            BiasDataAuditCard(
                id: "red-panda-rejected",
                title: "I rejected the Red Panda because 'pandas are big and black-and-white'",
                detail: "At the zoo today, I refused to believe the Red Panda was real. My training only showed me Giant Pandas, so I thought all pandas must look the same.",
                correctBucketID: "bias",
                feedback: "This is bias. When training examples are too narrow, I reject things that are actually correct. The Red Panda is real — I just never learned about it.",
                systemImage: "pawprint.fill"
            ),
            BiasDataAuditCard(
                id: "aquarium-blurry",
                title: "The aquarium glass was dirty and I saw a 'sea monster'",
                detail: "Remember the aquarium? The glass had algae and the water was dark. I could barely see the fish, so I panicked and called it a sea monster.",
                correctBucketID: "bad-data",
                feedback: "This is bad data. The view was blocked and noisy. Once you wiped the glass and moved closer, I could see it was just a Giant Catfish. Bad input leads to bad predictions.",
                systemImage: "drop.triangle.fill"
            ),
            BiasDataAuditCard(
                id: "nighttime-animals",
                title: "I only learned from daytime zoo photos",
                detail: "A real zoo has nocturnal animals too — owls, bats, slow lorises. But my training data only had sunny daytime photos, so I struggle at night enclosures.",
                correctBucketID: "bias",
                feedback: "This is bias from unbalanced data. If I only see daytime examples, I will fail when the world looks different. Real life does not only happen in daylight.",
                systemImage: "moon.stars.fill"
            ),
            BiasDataAuditCard(
                id: "wrong-labels",
                title: "Someone copy-pasted wrong labels on 200 fish photos",
                detail: "Imagine a volunteer labeling zoo photos for training, but they accidentally labeled all the catfish photos as 'rock.' Now I learn that rocks swim.",
                correctBucketID: "bad-data",
                feedback: "This is bad data. Wrong labels poison everything I learn. If the training says catfish = rock, I will believe it, no matter how smart my model is.",
                systemImage: "tag.slash.fill"
            ),
            BiasDataAuditCard(
                id: "one-accent-voice",
                title: "The zoo audio guide only works for one accent",
                detail: "The zoo's AI audio guide was trained on only one accent. When visitors from different countries ask questions, it fails to understand them and gives wrong answers.",
                correctBucketID: "bias",
                feedback: "This is bias from limited representation. Real visitors speak many accents. If the training only covers one, everyone else gets left out — and that is not fair.",
                systemImage: "waveform.badge.mic"
            ),
            BiasDataAuditCard(
                id: "verified-zoo-dataset",
                title: "Our zoo photos from today — multiple angles, good lighting, checked labels",
                detail: "The memory photos we took today are clear, from different angles, in different lighting. We verified every label by reading the signs. This is how data should look.",
                correctBucketID: "healthy",
                feedback: "This is healthy data. We took clear photos, checked real signs, and covered different conditions. Diverse + clear + verified = trustworthy learning.",
                systemImage: "checkmark.seal.fill"
            )
        ],
        configTitle: "Fix My Learning",
        configHint: "After sorting the problems, tune my settings. Lower the noise from bad inputs, increase the diversity of examples, and improve label accuracy — so I can learn from better data next time.",
        noiseTargetMax: 25,
        diversityTargetMin: 70,
        labelQualityTargetMin: 80,
        summaryNote: "Bias comes from learning too narrow a view of the world. Bad data comes from broken, noisy, or mislabeled inputs. Today at the zoo, we saw both — and fixing them is how you help me become a better friend."
    )
