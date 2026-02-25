import Foundation

let chapter2BiasAndBadDataLabMiniGame =
    BiasDataAuditMiniGame(
        title: "Bias & Bad Data Lab",
        promptLabel: "Sort each problem into the correct bucket, then tune the model setup.",
        buckets: [
            BiasDataAuditBucket(
                id: "bias",
                title: "Bias Pattern",
                description: "Narrow or unbalanced examples teach the wrong rule.",
                accentHex: "F59E0B",
                systemImage: "brain.head.profile"
            ),
            BiasDataAuditBucket(
                id: "bad-data",
                title: "Bad Data",
                description: "Noisy, blurry, wrong, or missing input/labels.",
                accentHex: "EF4444",
                systemImage: "waveform.path.badge.minus"
            ),
            BiasDataAuditBucket(
                id: "healthy",
                title: "Healthy Data",
                description: "Clear inputs, balanced examples, and verified labels.",
                accentHex: "10B981",
                systemImage: "checkmark.shield.fill"
            )
        ],
        cards: [
            BiasDataAuditCard(
                id: "daylight-only-photos",
                title: "Only daytime zoo photos in training",
                detail: "The model rarely sees night enclosures, so it misses nocturnal animals.",
                correctBucketID: "bias",
                feedback: "This is bias from an unbalanced dataset. The model learned mostly daylight patterns, not the full range.",
                systemImage: "sun.max.fill"
            ),
            BiasDataAuditCard(
                id: "blurry-aquarium-glass",
                title: "Blurry aquarium camera frame",
                detail: "Dirty glass and motion blur hide the fish shape.",
                correctBucketID: "bad-data",
                feedback: "This is bad data. The evidence is noisy/unclear, so the prediction becomes unreliable.",
                systemImage: "camera.metering.unknown"
            ),
            BiasDataAuditCard(
                id: "red-panda-rule",
                title: "Training labels teach 'panda = only big black-and-white'",
                detail: "The model rejects red pandas because it learned a narrow pattern as a rule.",
                correctBucketID: "bias",
                feedback: "This is bias. The training examples are too narrow, so valid exceptions get rejected.",
                systemImage: "pawprint.fill"
            ),
            BiasDataAuditCard(
                id: "wrong-copypaste-labels",
                title: "Copied labels are wrong on many images",
                detail: "Catfish photos are labeled as 'rock' after a bad import.",
                correctBucketID: "bad-data",
                feedback: "This is bad data. Incorrect labels directly poison the training signal.",
                systemImage: "tag.slash.fill"
            ),
            BiasDataAuditCard(
                id: "single-accent-voice-set",
                title: "Speech dataset uses only one accent",
                detail: "The AI performs poorly when visitors speak with different accents.",
                correctBucketID: "bias",
                feedback: "This is bias from limited representation. The training set does not cover real-world diversity.",
                systemImage: "waveform.badge.mic"
            ),
            BiasDataAuditCard(
                id: "balanced-verified-zoo-set",
                title: "Balanced, clear, verified zoo dataset",
                detail: "Multiple angles, lighting conditions, ages, and checked labels.",
                correctBucketID: "healthy",
                feedback: "This is healthy data. Diversity + clarity + verified labels improves model reliability.",
                systemImage: "checkmark.seal.fill"
            )
        ],
        configTitle: "Noise Config + Bias Fix",
        configHint: "Reduce noise, increase dataset diversity, and improve label checks before trusting the AI output.",
        noiseTargetMax: 25,
        diversityTargetMin: 70,
        labelQualityTargetMin: 80,
        summaryNote: "Bias usually comes from narrow or unbalanced training examples. Bad data usually comes from noisy inputs or wrong labels. Safer AI needs both better data quality and better data coverage."
    )

