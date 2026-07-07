# Sanjeevani
AI-Powered Offline Diagnostic Assistant for Rural Healthcare Workers
# 🩺 Sanjeevani
### AI-Powered Offline Diagnostic Assistant for Rural Healthcare Workers

> An offline-first, voice-enabled AI healthcare assistant designed to empower ASHA workers and rural healthcare staff with protocol-grounded clinical decision support in low-resource and low-connectivity environments.

![Flutter](https://img.shields.io/badge/Flutter-Mobile-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-Language-blue?logo=dart)
![AI](https://img.shields.io/badge/AI-RAG-success)
![SQLite](https://img.shields.io/badge/Database-SQLite-lightblue?logo=sqlite)
![Offline First](https://img.shields.io/badge/Offline-First-green)
![License](https://img.shields.io/badge/License-Academic-orange)

---

# 📖 Table of Contents

- Overview
- Problem Statement
- Why Sanjeevani?
- Objectives
- Key Features
- System Architecture
- Technology Stack
- Project Workflow
- Project Modules
- Folder Structure
- Installation
- Screenshots
- Future Scope
- Team
- Awards
- Disclaimer
- License

---

# 🌍 Overview

**Sanjeevani** is an AI-powered **offline diagnostic support system** developed specifically for **ASHA workers** and rural healthcare professionals.

The application enables healthcare workers to:

- Capture patient symptoms using voice
- Convert speech to text completely offline
- Retrieve verified medical protocols
- Generate AI-assisted triage recommendations
- Store patient records locally
- Synchronize anonymized reports whenever internet becomes available

Unlike traditional healthcare chatbots, **Sanjeevani is designed for rural India where internet connectivity cannot be assumed.**

---

# ❗ Problem Statement

Healthcare workers in rural India face several challenges:

- 👨‍⚕️ Limited availability of doctors
- 🌐 Poor or no internet connectivity
- 📝 Paper-based patient records
- 🗣 Multiple regional languages
- ⏳ Delayed referrals
- 📉 Lack of decision support during field visits

These issues often delay timely diagnosis and treatment.

Sanjeevani aims to bridge this healthcare gap using **Offline AI**.

---

# 💡 Why Sanjeevani?

Most healthcare AI applications require:

- Continuous internet
- Cloud APIs
- English input
- Powerful hardware

Sanjeevani takes the opposite approach.

✅ Offline First

✅ Voice First

✅ Rural First

✅ Privacy First

---

# 🎯 Objectives

- Develop an offline-first Android application.
- Support multilingual voice input.
- Provide AI-assisted medical triage.
- Ground AI responses using verified medical protocols.
- Maintain offline patient records.
- Enable optional cloud synchronization.
- Support PHC monitoring dashboards.

---

# ✨ Key Features

### 🎤 Voice-Based Diagnosis

- Hindi
- Gujarati
- English

Speech is converted into text completely offline.

---

### 🧠 AI Decision Support

Uses:

- Retrieval-Augmented Generation (RAG)
- Quantized Language Models
- Local Inference

This minimizes hallucinations and improves reliability.

---

### 📚 Verified Medical Knowledge

Recommendations are generated only after retrieving relevant medical protocol documents.

Protocols include:

- ICMR Guidelines
- IMNCI Guidelines

---

### 📱 Offline First

Core features work without internet:

- Voice Capture
- AI Inference
- Patient Records
- Follow-up Scheduling

---

### 🗄 Local Database

Stores:

- Patient Records
- Household Details
- Visit History
- Immunization Records
- Follow-up Schedule

using SQLite.

---

### ☁ Smart Synchronization

When internet becomes available:

- Anonymous statistics
- Referral trends
- Disease patterns

are synchronized to backend dashboards.

---

### 📊 PHC Dashboard

Medical officers can monitor:

- Daily Cases
- Referral Statistics
- High-Risk Patients
- Village Health Trends

---

# 🏗 System Architecture

```
                +-------------------------+
                |   Flutter Mobile App    |
                +------------+------------+
                             |
                             v
                +-------------------------+
                | Capture Layer           |
                | Voice Recording         |
                | Speech-to-Text          |
                +------------+------------+
                             |
                             v
                +-------------------------+
                | Intelligence Layer      |
                | FAISS Retrieval         |
                | Quantized LLM           |
                | RAG                     |
                +------------+------------+
                             |
                             v
                +-------------------------+
                | Data Layer              |
                | SQLite                  |
                | Patient Records         |
                +------------+------------+
                             |
                             v
                +-------------------------+
                | Sync Layer              |
                | Firebase/Supabase       |
                | PHC Dashboard           |
                +-------------------------+
```

---

# 🛠 Technology Stack

| Category | Technology |
|----------|------------|
| Mobile Development | Flutter |
| Programming Language | Dart |
| Speech Recognition | Vosk |
| Backup STT | Whisper Tiny |
| AI Model | Gemma 2B |
| Alternative Model | Phi-3 Mini |
| Model Runtime | llama.cpp |
| Mobile Runtime | MLC-LLM |
| Embeddings | Sentence Transformers |
| Vector Database | FAISS |
| Local Database | SQLite (sqflite) |
| Backend | Firebase / Supabase |
| Dashboard | React.js |
| Charts | Chart.js |

---

# 🔄 Workflow

```
Patient
     │
     ▼
Voice Recording
     │
     ▼
Speech-to-Text
     │
     ▼
Retrieve Medical Protocol
     │
     ▼
AI Analysis (RAG)
     │
     ▼
Recommendation
     │
     ▼
Save Patient Record
     │
     ▼
Cloud Sync (Optional)
```

---

# 📦 Project Modules

### Authentication

- Worker Login
- Local Profile

---

### Patient Registration

- Household Details
- Patient Information

---

### Voice Capture

- Record Symptoms
- Multilingual Support

---

### AI Diagnosis

- Symptom Analysis
- Protocol Retrieval
- Risk Classification

---

### Patient Records

- Visit History
- Previous Diagnosis
- Follow-up

---

### Dashboard

- Disease Trends
- Referral Monitoring
- Reports

---

# 📂 Folder Structure

```text
Sanjeevani/
│
├── android/
├── ios/
├── lib/
│   ├── screens/
│   ├── widgets/
│   ├── services/
│   ├── models/
│   ├── database/
│   ├── ai/
│   └── utils/
│
├── assets/
│   ├── images/
│   ├── icons/
│   ├── audio/
│   └── protocols/
│
├── backend/
│
├── dashboard/
│
├── docs/
│
├── README.md
│
└── pubspec.yaml
```

---

# 🚀 Installation

Clone the repository

```bash
git clone https://github.com/yourusername/sanjeevani.git
```

Navigate into the project

```bash
cd sanjeevani
```

Install dependencies

```bash
flutter pub get
```

Run the application

```bash
flutter run
```

---

# 📱 Screenshots

> *(Add screenshots here once the application UI is completed.)*

Example:

```
Home Screen

Voice Capture

AI Recommendation

Patient Records

Dashboard
```

---

# 🔮 Future Scope

- Support additional Indian languages.
- Explainable AI with protocol citations.
- Faster mobile inference.
- Offline image-based diagnosis.
- Integration with Ayushman Bharat Digital Mission.
- Wearable health device integration.
- District-level health analytics.
- Pilot deployment in Primary Health Centres.

---

# 👥 Team

| Name | Responsibility |
|------|----------------|
| Nirjala Dixit | Flutter App, UI, Speech-to-Text |
| Khushi Tiwari | AI Models, RAG Pipeline |
| Anandkumar Sharma | SQLite Database & Medical Records |
| Kirtan Thakkar | Backend, Dashboard & Synchronization |

---

# 🏆 Project Submission

This project has been developed as part of the **Dewang Mehta IT Award (DMIT) 2026 – Project Competition**.

---

# ⚠ Disclaimer

Sanjeevani is an **AI-assisted clinical decision support system**.

It is **not intended to replace licensed medical professionals** and should be used only as an aid to support frontline healthcare workers. Final diagnosis and treatment decisions must always be made by qualified healthcare providers.

---

# 📄 License

This project is developed for academic and research purposes under the **Dewang Mehta IT Award (DMIT) 2026**.

---

## ⭐ If you found this project interesting, consider giving it a star!