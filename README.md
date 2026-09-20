<div align="center">

# Equalize 🎓
### Every Student Deserves to Learn in Their Own Language

[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0+-000000?logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![AWS](https://img.shields.io/badge/AWS-Powered-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com)
[![License](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

**Built for the Bharat Builds Tour - First Commit Hackathon 2026**

</div>

---

## 💡 The Problem

Walking into a university lecture and not understanding a single word isn't a rare occurrence — it's the daily reality for millions of international students. Lectures are delivered in English or regional languages like Hindi, and for students whose native language is neither, the knowledge gap compounds every single day.

I experienced this firsthand watching foreign students around me fall behind — not because they lacked intelligence, but because they lacked comprehension. **Language should never be the barrier between a student and their education.**

I built **Equalize** to fix that.

---

## 📸 Screenshots

<div align="center">
<img src="https://github.com/user-attachments/assets/5ff8576d-546f-4d82-999a-2a8124c31e5a" width="22%" />
<img src="https://github.com/user-attachments/assets/10267808-2a93-4bd9-810e-9cebb934d817" width="22%" />
<img src="https://github.com/user-attachments/assets/7b2d191c-f1c6-452a-ac25-7d73f8af54b0" width="22%" />
<img src="https://github.com/user-attachments/assets/57a66a5a-63d8-4880-8033-8ef63a9ed4a4" width="22%" />
<br>
<img src="https://github.com/user-attachments/assets/005a722b-1149-4ce7-a583-892df4d5a8d5" width="22%" />
<img src="https://github.com/user-attachments/assets/e04fc72e-6efb-427c-90d5-41abda841162" width="22%" />
<img src="https://github.com/user-attachments/assets/2de7d6f8-5327-433c-954b-3086cc19f546" width="22%" />
<img src="https://github.com/user-attachments/assets/34f8e915-5b91-461d-8c0e-0ddbe177b98a" width="22%" />
<br>
<img src="https://github.com/user-attachments/assets/3903b0e0-24d6-4f86-a0fb-798773a64197" width="22%" />
</div>

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
📱 iOS App (SwiftData Cache)
   │
   │  ── OFFLINE (no internet needed) ─────────────────────────────────
   │  Record live lecture           → saved locally
   │  Import audio or video file    → saved locally
   │  Read notes, transcripts       → served from SwiftData cache
   │  Listen to dubbed audio        → on-device TTS (AVSpeechSynthesizer)
   │  Ask AI questions              → on-device Apple Intelligence
   │  ────────────────────────────────────────────────────────────────
   │
   │  (internet required only for this one-time processing step)
   │
   │  NWPathMonitor detects connection → auto-resumes upload queue
   │
   ├── 1. Upload audio/video ──────────────────────► Amazon S3
   │
   └── 2. API Gateway ──► Lambda ──► AWS Step Functions
                                           │
                              ┌────────────┼────────────┐
                              │            │            │
                              ▼            ▼            ▼
                        Amazon         AWS Lambda  Amazon Bedrock
                        Transcribe     (Chunker)   Nova Lite
                        Timestamped    Splits      Notes + Flashcards
                        transcript     into        + Translation
                        from audio     chunks      │
                                                   Fallback:
                                                   Groq (qwen3.8-27b)
                              │
                              └────────────────────► Amazon DynamoDB
                                                     (course content)
                                           │
                                           ▼
                      iOS polls → fetches → writes to SwiftData cache
   │
   │  ── OFFLINE AGAIN (forever after processing) ──────────────────
   │  ✅ Notes • Transcripts • Flashcards • Dubbed Audio • AI Q&A
   │  ────────────────────────────────────────────────────────────────
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
