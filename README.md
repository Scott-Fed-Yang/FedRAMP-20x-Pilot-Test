# Vyond for Government (V4G) – FedRAMP 20x Phase One Submission

Welcome to the V4G FedRAMP 20x Phase One Submission. This repository provides a structured and auditable interface for FedRAMP assessors and stakeholders to review Key Security Indicators (KSI) as required by the FedRAMP 20x standards.

---

## 🔧 Overview

This repository includes an automated pipeline that verifies KSI requirements outlined in the FedRAMP 20x program.

- Reference: [FedRAMP 20x KSI Standard](https://www.fedramp.gov/20x/standards/20x-ksi/)
- Submission Dashboard: [https://status.staging.vyond-fedramp.org/phase-one/](https://status.staging.vyond-fedramp.org/phase-one/)
- Submission Dec: [FedRAMP 20x Pilot - Rationale.pptx](https://docs.google.com/presentation/d/1X2pSOBdoKqAULimb-EQDO50S9bP_VKQQ/edit?usp=sharing)
- 3PAO Committment Letter: [Kratos-Committment Letter-Vyond-FedRAMP 20X Pilot-v1.docx](https://docs.google.com/document/d/1MEWWUyeUyoiycBP4rFvF2wkh-X7ExTut/edit?usp=sharing)
---

## ♻️ Automation

A GitHub Actions workflow is scheduled to run regularly to:

1. Execute a Python-based validation script that checks eligible KSI controls
2. Generate a human-readable HTML summary report
3. Upload both the report and evidence artifacts to an S3 bucket via secure FIPS encryption

---

## ✋ Manual Uploads

For KSI that cannot be programmatically validated (e.g., attestation-only items), evidence files are uploaded manually to the same S3 structure for centralized access.

---

## 📦 Contents of This Repository

- `data.json` — JSON configuration for all KSI items and their validation definitions
- `auto_validation.py` — Main Python script for validation
- `scripts/` — Bash scripts to validate specific controls
- `.github/workflows/` — GitHub Actions workflow to automate the pipeline

---

## 🚀 Deployment Architecture

- Evidence and reports are uploaded to an S3 bucket
- Fronted by an AWS CloudFront distribution
- Publicly accessible via: [https://status.vyond-fedramp.com/phase-one/](https://status.vyond-fedramp.com/phase-one/)

---

## 💼 For Reviewers / Auditors

This Phase One Submission is organized to meet the following FedRAMP 20x expectations:

- Clearly documented Points of Contact
- Public access to the KSI summary view
- Artifacts for verified controls and manual attestations
- Support for continuous monitoring, change management, and incident response
- Optional system diagrams to aid in interpretation

If additional access is required, please contact:
📧 **devops@vyond-fedramp.com**

---

## 📆 Update Frequency

- Validation scripts are executed on a daily scheduled basis via GitHub Actions
- Evidence and reports are updated automatically or manually as needed

---

Thank you for your review and continued collaboration.
