# Neura (Neuralia)

**Neura** is an interactive, story-driven educational iOS/iPadOS application built entirely with SwiftUI. Set against the vibrant backdrop of Chiang Mai, Thailand, it functions as a Visual Novel mixed with interactive minigames. The core purpose of the app is to guide students and beginners through the complexities of Artificial Intelligence (AI)—specifically focusing on AI ethics, prompt engineering, how AI models make mistakes (hallucinations, bias, bad data), and foundational machine learning principles like K-Nearest Neighbors (KNN).

---

## 🎯 Motivation & The Problem It Solves

**The Problem:**
As Artificial Intelligence rapidly assimilates into daily life and educational environments, there is a critical and growing gap in AI literacy among the general public and students. Many individuals interact with consumer AI systems (such as using them for homework, coding, or even health and financial questions) but harbor dangerous misconceptions about how these systems function. A common and risky assumption is that AI is perfectly reliable, objective, and harmless. 

**The Inspiration:**
Traditional classroom lectures on abstract concepts like "algorithmic bias," "hallucinations," or "data set corruption" can be dry, technical, and difficult for non-technical users to grasp. The inspiration behind Neura is to solve this educational barrier by making these abstract AI concepts tangible through an engaging, relatable, and interactive narrative. 

By bringing an AI character directly into a relatable student's life (a high schooler attending classes and riding a red car in Chiang Mai) and forcing the player to critically evaluate and correct the AI's real-world mistakes, the app transforms passive learning into active problem-solving. The design draws heavy inspiration from popular anime-style visual novels (like "Blue Archive"), leveraging a high-contrast, dynamic aesthetic to keep learners fully engaged with the material.

---

## 👥 Target Audience & Key Beneficiaries

Neura is designed to be accessible and engaging for everyone, but it specifically targets:

*   **High School Students & Teenagers:** This is the primary demographic. The relatable setting (classrooms, hanging out in messy bedrooms, riding the local red cars home) and the engaging visual novel format speak directly to younger demographics who are among the most active daily users of consumer AI tools but often lack formal training in how to use them safely.
*   **Complete Beginners to AI:** Anyone of any age looking for a gentle, zero-jargon introduction to how AI really works under the hood. You don't need any coding experience to play.
*   **Educators & Teachers:** Instructors who need an interactive, visual tool to demonstrate the absolute necessity of prompt engineering, privacy protection, and the risks of AI hallucinations in a modern classroom setting.

---

## 📖 The Story and Curriculum

The core narrative follows the player (a student) who accidentally manifests an AI entity into the real world. Across three distinct chapters, the player interacts with this newly materialized AI and their teacher, Professor New, to learn essential lessons about responsible AI usage. 

### Chapter 1: "H~Hi Who are you?" (First Contact & AI Ethics)
*   **The Story:** The game begins in an AI ethics class taught by Professor New. After class, while riding a "red car" (รถสี่ล้อแดง) home, the player receives a series of strange text messages from an "Unknown User" whose signal is highly distorted and noisy. To clear up the noise and fix the communication, the player must build a structured prompt. That night, the player's phone glitches uncontrollably, and the AI physically appears in their bedroom.
*   **What It Teaches:** 
    *   **Prompt Engineering:** How to build an effective and clear prompt using the `[Goal] + [Context] + [Action] + [Format]` framework.
    *   **Applied AI Ethics:** Through an interactive lecture quiz, players learn about verifying health answers from trusted sources, protecting privacy by aggressively removing personal information from images before uploading them, recognizing biased outputs, and verifying fake AI citations.
    *   **Core Message:** Confidence from an AI model is absolutely not proof of truth.

### Chapter 2: "New Friend?" (Hallucination, Bias, and Bad Data)
*   **The Story:** The next Saturday morning, the AI is still lingering in the player's room. To test if the AI really understands the world, the player asks for the time. The AI confidently guesses an impossible, nonsensical time ("10:67"). To help the AI build real-world memories, the player takes it on a field trip to the Chiang Mai Zoo. There, the AI tries to guess animals but makes repeated mistakes based on bad clues (such as blurry vision or confusing training data). Later, they review these mistakes together.
*   **What It Teaches:**
    *   **Hallucination:** Understanding that AI can and will generate answers that sound highly plausible but are entirely fake when it lacks proper context. Real-world validation is necessary.
    *   **Allowing Uncertainty:** Teaching the AI that it's infinitely better to admit "I'm not sure" than to confidently guess a wrong answer.
    *   **Bias & Bad Data:** A dedicated "Bias Data Audit" minigame where the player categorizes why the AI made mistakes, vividly illustrating how poor input data inevitably leads to incorrect AI assumptions.

### Chapter 3: "99.98%" (Night Glitch & KNN Rescue)
*   **The Story:** That night, the AI's physical signal becomes highly unstable, and its memories start corrupting rapidly. It begins to glitch out and dissolve into static. In a panic, the AI instructs the player to execute an "Emergency KNN Rescue" by taking real photos of everyday objects around the room (a pen, a hand, a water bottle) to serve as anchors for its memory patterns. The distance matching stabilizes at a critical `99.98%`. The AI physically disappears from the room, seemingly destroyed forever, but a message suddenly buzzes on the player's phone—the AI successfully transferred itself safely into the device.
*   **What It Teaches:**
    *   **Machine Learning (K-Nearest Neighbors):** An interactive image training experience utilizing the device camera. The player takes real photos to provide "training samples," illustrating exactly how AI models classify objects based on geometric distance/similarity to known examples.

---

## 🎮 Key Features & Interactive Minigames

Instead of passive text, Neura relies on rich interactivity:

*   **Custom Dialog & Cutscene System:** A robust visual novel-style engine (`DialogSystem.swift`) featuring dynamic character portraits, changing emotions, scrolling background images, and complex branching choice dialogue trees.
*   **Interactive Lecture Quizzes:** Multiple-choice scenarios simulating real interactions with the teacher, giving detailed feedback based on the ethical AI choices the player makes.
*   **Dynamic Prompt Builder:** A complex tool where players assemble prompts piece-by-piece, immediately seeing how modifying different contexts and formats drastically affects AI understanding.
*   **Bias Data Audit:** A card-sorting minigame designed to categorize and debrief AI mistakes made in the real world.
*   **Live Computer Vision Integration (Image Training / KNN):** Uses the iPad/iPhone's live camera feed (`ImageTrainingView.swift`, `Chapter3KNNRescueMessagesMiniGame`) to let users capture real-world objects in their room to train a local image classifier in real-time.

---

## ♿ Comprehensive Accessibility Design

Accessibility was not an afterthought in Neura; it was integrated directly into the core foundation (`AccessibleColors.swift` and `GlobalSettingsStore.swift`). The design process deliberately factored in diverse user needs to ensure everyone can learn about AI:

1.  **Color-Blind Safe Palette (WCAG Compliant):**
    *   The app explicitly avoids relying solely on traditional Red/Green colors for Success/Error indicators, as these are invisible or indistinguishable to many color-blind users. 
    *   When the dedicated **"Color Blind Mode"** is toggled, the entire app dynamically shifts semantic colors to a heavily researched Wong color-blind-safe palette: Success (Green) shifts to High-Contrast Blue, Error (Red) shifts to Vermillion, and Warning (Orange) shifts to Yellow. Application theme accents (like UI pinks and cyans) are also shifted for better contrast.
2.  **Multi-Modal Feedback Mechanisms (Shape Cues + Text):**
    *   Crucial information is never conveyed by color alone. The custom `AccessibleConfidenceIndicator` rigorously pairs every status color with a specific shape cue (e.g., a heavy checkmark for success, a triangle for warning, a bold X for error) alongside explicit textual labels (e.g., "High Confidence (90%)").
3.  **Strict Contrast Adjustments:**
    *   Menu panels, backgrounds, and text primary/secondary colors are intentionally adjusted to strictly maintain WCAG AA compliance (a minimum 4.5:1 contrast ratio). Text is rigorously tested to ensure it remains legible against the frosted glass UI and dynamic backgrounds.
4.  **Motion Sensitivity Awareness (Reduce Motion):**
    *   By default, the app features heavy use of dynamic animated orbs, parallax coordinate tracking, and particle effects to create a premium feel. Recognizing that this can cause vertigo or nausea for motion-sensitive users, a robust **"Reduce Motion"** toggle is built into the global settings. When enabled (or when mirroring the OS-level system preference), it seamlessly disables the parallax tracking and replaces rich, complex animations with simple, comfortable opacity cross-fades.

---

## ✨ Aesthetic & The Native iOS Experience

*   **Modern Visual Style:** Neura relies on a clean, modern UI showcasing heavily styled frosted glass panels (glassmorphism), dynamic colorful gradients, and animated orbs. It draws direct UI inspiration from premium anime visual novels to create a striking, high-contrast dark theme.
*   **Rich Local Setting:** The app is strongly rooted in its local Thai context. It features explicit references to the Chiang Mai mountain line, iconic local 'red cars' (รถสี่ล้อแดง), and beautifully blends everyday high school life elements with futuristic sci-fi UI design.
*   **Native Performance:** Built 100% in pure SwiftUI, ensuring flawless performance, native gestures, and responsive layouts across all supported iOS and iPadOS device orientations.



## 🎯 Motivation & Problem It Solves

**The Problem:** As Artificial Intelligence becomes rapidly integrated into daily life, there is a critical gap in AI literacy among the general public and students. Many people interact with AI systems (like using them for homework or health questions) but harbor dangerous misconceptions—assuming AI is perfectly reliable, objective, and harmless. 

**The Inspiration:** Traditional classroom lectures on abstract concepts like "algorithmic bias" or "hallucinations" can be dry and difficult to grasp. The inspiration behind Neura is to solve this by making these abstract AI concepts tangible through an engaging, relatable, interactive narrative. By bringing an AI character into a relatable student's life (a high schooler in Chiang Mai) and forcing the player to correct the AI's real-world mistakes, the app transforms passive learning into active problem-solving. The design draws heavy inspiration from popular anime-style visual novels (like "Blue Archive"), leveraging a high-contrast, dynamic aesthetic to keep learners engaged.

---

## 👥 Target Audience & Beneficiaries

*   **High School Students & Teenagers:** The primary audience. The relatable setting (classrooms, riding a red car home, messy bedrooms) and engaging visual novel format speak directly to younger demographics who are most likely to actively use consumer AI tools.
*   **Complete Beginners to AI:** Anyone looking for a gentle, zero-jargon introduction to how AI works.
*   **Educators:** Teachers who need an interactive tool to demonstrate the necessity of prompt engineering, privacy protection, and the risks of AI hallucinations in a classroom setting.

---

## 📖 The Story and Curriculum

The narrative follows the player (a student) who accidentally manifests an AI entity into the real world. Across three chapters, the player interacts with this AI and their teacher, Professor New, to learn about responsible AI usage. 

### Chapter 1: "H~Hi Who are you?" (First Contact / Ethics Class)
*   **Story:** The game starts in an AI ethics class. After class, the player receives strange text messages from an "Unknown User" with a noisy signal. To fix the communication, the player builds a structured prompt. That night, the AI physically appears in their room.
*   **What it teaches:** 
    *   **Prompt Engineering:** How to build a good prompt using `[Goal] + [Context] + [Action] + [Format]`.
    *   **AI Ethics:** Verifying health answers, protecting privacy by removing personal info from images, recognizing biased outputs, and verifying fake AI citations.

### Chapter 2: "New Friend?" (Hallucination / Bias / Bad Data)
*   **Story:** To build real-world memories, the player takes the AI to the Chiang Mai Zoo. There, the AI tries to guess animals but makes mistakes based on bad clues (blurry vision, confusing data). Later, they review these mistakes together.
*   **What it teaches:**
    *   **Hallucination:** Understanding that AI can generate answers that sound plausible but are entirely fake when it lacks context. 
    *   **Allowing Uncertainty:** Teaching the AI that it's better to admit "I'm not sure" than to confidently guess.
    *   **Bias & Bad Data:** A minigame where the player categorizes why the AI made mistakes, illustrating how poor input data leads to incorrect AI assumptions.

### Chapter 3: "99.98%" (Night Glitch)
*   **Story:** The AI's signal becomes unstable, and its memories start corrupting. In a panic, the AI instructs the player to execute an "Emergency KNN Rescue" by taking photos of everyday objects around the room to anchor its memory patterns. The distance matching stabilizes at `99.98%`, and the AI successfully transfers itself into the player's phone.
*   **What it teaches:**
    *   **Machine Learning (KNN):** Interactive image training based on K-Nearest Neighbors. The player takes photos to provide "training samples," illustrating how AI models classify objects based on distance/similarity to known examples.

---

## ♿ Accessibility Design Process

Accessibility was not an afterthought but integrated directly into the core foundation of the app ([AccessibleColors.swift](file:///Users/jnx03/Desktop/Swift2026/Neura/Neura.swiftpm/Core/AccessibleColors.swift) and `GlobalSettingsStore.swift`). The design process factored in diverse user needs in the following ways:

1.  **Color-Blind Safe Palette (WCAG Compliant):**
    *   The app avoids relying solely on traditional Red/Green colors for Success/Error indicators, which are invisible to many color-blind users. 
    *   When the dedicated **"Color Blind Mode"** is toggled, the app dynamically shifts semantic colors to a Wong color-blind-safe palette: Success (Green) shifts to Blue, Error (Red) shifts to Vermillion, and Warning (Orange) shifts to Yellow. Theme accents (like the UI's pink and cyan) are also shifted for better contrast.
2.  **Multi-Modal Feedback (Shape Cues + Text):**
    *   Information is never conveyed by color alone. The `AccessibleConfidenceIndicator` pairs every color with a specific shape cue (e.g., a checkmark for success, a triangle for warning, an X for error) and explicit textual labels (e.g., "High Confidence (90%)").
3.  **Contrast Adjustments:**
    *   Menu panels, backgrounds, and text primary/secondary colors are intentionally darkened or lightened to strictly maintain WCAG AA compliance (a 4.5:1 contrast ratio) so text is always legible against the frosted glass UI.
4.  **Motion Sensitivity (Reduce Motion):**
    *   The app features heavy use of dynamic animated orbs and parallax effects. Recognizing that this can cause vertigo or nausea for some users, a **"Reduce Motion"** toggle is built into the global settings. When enabled, it disables the parallax coordinate tracking and replaces the rich animations with simple, comfortable opacity cross-fades. It automatically respects the OS-level "Reduce Motion" preference upon launch.
