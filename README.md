<div align="center">

# Equalize 🎓
### Every Student Deserves to Learn in Their Own Language

[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0+-000000?logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![AWS](https://img.shields.io/badge/AWS-Powered-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com)
[![License](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

**Built for the AWS Hackathon 2026**

</div>

---

## 💡 The Problem

Walking into a university lecture and not understanding a single word isn't a rare occurrence — it's the daily reality for millions of international students. Lectures are delivered in English or regional languages like Hindi, and for students whose native language is neither, the knowledge gap compounds every single day.

I experienced this firsthand watching foreign students around me fall behind — not because they lacked intelligence, but because they lacked comprehension. **Language should never be the barrier between a student and their education.**

I built **Equalize** to fix that.

---

## 📸 Screenshots

*(Drop your screenshots here — drag images into a GitHub Issue to get URLs, then paste them below)*

| Home Feed | Lecture Detail | AI Notes | AI Voice Dubbing |
| :---: | :---: | :---: | :---: |
| `[screenshot]` | `[screenshot]` | `[screenshot]` | `[screenshot]` |

| Transcript View | Flashcard Practice | Course Q&A | Recording |
| :---: | :---: | :---: | :---: |
| `[screenshot]` | `[screenshot]` | `[screenshot]` | `[screenshot]` |

---

## ✨ What Equalize Does

### 📝 Instant AI-Structured Notes
Every lecture is automatically transcribed and converted by AWS Bedrock into beautiful, **chapter-by-chapter Markdown notes** complete with headings, bullet points, and Mermaid diagrams — rendered natively in-app via a custom WKWebView. Students no longer need to scribble frantically during class.

### 🗣️ Full-Lecture AI Voice Dubbing  
Using on-device `AVSpeechSynthesizer`, Equalize reads the entire translated lecture transcript aloud in the student's native language — **Hindi, Spanish, or French** — with automatic Premium/Enhanced voice selection for the most natural possible speech. This is full audio, not a summary clip.

### 🌍 One-Tap Language Translation
Tap **Spanish / Hindi / French** and the entire lecture — notes, transcript, and spoken audio — switches language instantly. The translation pipeline runs server-side through AWS Lambda and Bedrock, then is cached locally so it never needs to be fetched again.

### 🔍 Select-to-Explain (Apple Intelligence)
Highlight **any text** in the lecture notes and a floating "Explain" button appears. Tap it, and Apple Foundation Models (`FoundationModels` framework) generates a friendly, analogy-driven explanation tuned to a beginner — powered 100% on-device with zero latency.

### 🃏 AI Flashcards & Active Recall Practice
Generate a full multiple-choice quiz from any lecture with one tap. Equalize uses AWS Bedrock to produce scored flashcards tied to that specific lecture's content. At the end of a quiz session, students receive a detailed performance breakdown with per-question analysis.

### 🎙️ Record, Import Audio, or Import Video
Students can **live-record** lectures in-app, **import existing audio files**, or **import video files** (the audio track is extracted server-side). All three sources feed into the same AWS pipeline for transcription and AI processing.

### 📴 Record Offline, Process When Connected
No Wi-Fi in the lecture hall? No problem. Equalize saves recordings and imports locally, queuing them via `OfflineQueue` + `SyncManager`. The moment connectivity is restored, `NWPathMonitor` automatically resumes all pending uploads and processing jobs — no manual intervention needed.

### 🎵 Interactive Audio Mini-Player
A sleek floating `ultraThinMaterial` pill-shaped mini-player docks at the bottom of every lesson. Tap any transcript chapter to **instantly seek** to that exact moment in the original audio. Progress is tracked and persisted across sessions.

---

## ☁️ AWS Architecture — The Engine Room

Equalize would not exist without AWS. Every piece of heavy computation is offloaded to a fully serverless, auto-scaling AWS backend.

```
┌─────────────────────────────────────────────────────────────────┐
│                         📱 iOS App                              │
│                    (SwiftData Local Cache)                       │
│                                                                 │
│  [Offline] Record or import lecture → saved locally             │
│  [Offline] Read notes, transcripts, flashcards from cache       │
│  [Offline] Listen to dubbed audio via on-device TTS             │
└───────────────────────┬─────────────────────────────────────────┘
                        │  (requires internet only for this step)
                        ▼
         NWPathMonitor detects connection
                        │
    ┌───────────────────▼───────────────────┐
    │  1. Upload audio/video                │
    │     → Amazon S3 (presigned URL)       │
    │  2. API Gateway → Lambda              │
    │     (init lecture, trigger pipeline)  │
    └───────────────────┬───────────────────┘
                        │
                        ▼
          AWS Step Functions (orchestrator)
                        │
          ┌─────────────┼──────────────┐
          ▼             ▼              ▼
   Amazon        AWS Lambda      Amazon Bedrock
   Transcribe    (Chunker)       (Nova Lite)
   │             │               │
   Timestamped   Splits          Generates notes,
   transcript    transcript      flashcards &
   from audio    into token-     translations
                 safe chunks     │
                                 Fallback → Groq
                                 (qwen3.8-27b)
          │
          ▼
    Amazon DynamoDB
    (stores all processed
     course content)
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│  iOS App polls → fetches result → writes to SwiftData cache     │
│                                                                 │
│  ✅ From this point, the app is 100% offline capable            │
│     Notes • Transcripts • Flashcards • Dubbed Audio             │
└─────────────────────────────────────────────────────────────────┘
```

| AWS Service | Role in Equalize |
| :--- | :--- |
| **Amazon S3** | Stores raw uploaded audio/video files + processed output assets |
| **API Gateway** | Single secure REST endpoint for all iOS ↔ backend communication |
| **AWS Step Functions** | Orchestrates the multi-step transcription → chunking → LLM pipeline without timeouts |
| **Amazon Transcribe** | Converts lecture audio to timestamped, accurate speech-to-text |
| **AWS Lambda** | Intelligent text chunking, pre/post processing, translation coordination |
| **Amazon Bedrock (Nova Lite)** | Powers notes generation, flashcard creation, and multi-language translation |
| **Amazon DynamoDB** | Ultra-fast NoSQL storage for all course content, chapters, and flashcard data |
| **Amazon Cognito** | Secure user authentication, JWT-based session management |

> **Reliability Note:** When Amazon Bedrock hits rate limits, the system automatically falls back to **Groq's `qwen3.8-27b`** model to guarantee zero downtime for students.

---

## 🛠️ iOS Tech Stack

| Layer | Technology |
| :--- | :--- |
| **UI** | SwiftUI, `ultraThinMaterial`, `WKWebView` (Markdown + Mermaid rendering) |
| **State** | `@Observable`, Combine, SwiftData (`@Model`) |
| **Audio** | `AVFoundation`, `AVAudioPlayer`, `AVSpeechSynthesizer` (Premium voice auto-selection) |
| **AI (On-Device)** | Apple `FoundationModels` — `Select-to-Explain` feature |
| **Networking** | `NWPathMonitor` (online detection), `URLSession` (uploads), `OfflineQueue` |
| **Persistence** | SwiftData + Core Data for offline-capable local storage |

---

## 🚀 Getting Started

```bash
git clone https://github.com/akhandpratap18/Equalize.git
cd Equalize
open Equalize.xcodeproj
```

1. Ensure you have **Xcode 15+** and an Apple Developer account.
2. Deploy the AWS backend (`backend/template.yaml`) using AWS SAM: `sam deploy --guided`.
3. Update the base API URL in `Equalize/Data/APIClient.swift`.
4. Hit **`Cmd+R`** on a physical device for the best experience (Premium TTS voices required).

---

<div align="center">
<strong>Built with ❤️ for every student who ever sat in a class and felt lost.</strong>
</div>
