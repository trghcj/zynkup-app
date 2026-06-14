Used tool: manage_task

Here is a professional and standard `CONTRIBUTING.md` file specifically tailored for ZynkUp. You can copy and paste this entire block directly into GitHub!

```markdown
# Contributing to ZynkUp

First off, thank you for considering contributing to ZynkUp! It's people like you that make ZynkUp a great platform for connecting students and building campus communities. 

This document provides guidelines and best practices for contributing.

## Table of Contents
1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [How to Contribute](#how-to-contribute)
    * [Reporting Bugs](#reporting-bugs)
    * [Suggesting Enhancements](#suggesting-enhancements)
    * [Pull Requests](#pull-requests)
4. [Development Setup](#development-setup)
5. [Styleguides](#styleguides)

## Code of Conduct

This project and everyone participating in it is governed by the [ZynkUp Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Getting Started

Contributions are welcome from everyone, regardless of experience level! Whether you are fixing a typo, resolving a bug, or building a new feature, your help is appreciated. 

Before starting work on a major new feature, please open an **Issue** to discuss it with the maintainers first. This ensures you don't waste time working on something that doesn't align with the project roadmap.

## How to Contribute

### Reporting Bugs
If you find a bug in the source code or a mistake in the documentation, you can help us by submitting an issue to our GitHub Repository. Even better, you can submit a Pull Request with a fix.

When reporting an issue, please include:
* A clear and descriptive title.
* Steps to reproduce the problem.
* The expected behavior vs. the actual behavior.
* Screenshots or screen recordings if it is a UI issue.

### Suggesting Enhancements
Enhancement suggestions are tracked as GitHub issues. When creating an enhancement issue, please provide:
* A clear description of the proposed feature.
* The problem the feature solves.
* Any UI/UX mockups or inspiration (if applicable).

### Pull Requests
The process for submitting a Pull Request (PR) is straightforward:
1. **Fork** the repository and clone it locally.
2. Create a new branch for your feature or bugfix (`git checkout -b feature/my-new-feature` or `bugfix/issue-123`).
3. Make your changes and commit them with descriptive commit messages.
4. Push your branch to your fork on GitHub.
5. Open a Pull Request against the `main` (or `dev`) branch of the original ZynkUp repository.

*Note: Please ensure your PR description clearly describes what the PR does and links to any relevant issues.*

## Development Setup

To run the ZynkUp application locally, we recommend using Docker for the backend. Please refer to the **Setup Guide** section in the main [README.md](README.md) for step-by-step instructions on spinning up the FastAPI backend, PostgreSQL database, and the Flutter Web/Mobile environment.

## Styleguides

### Git Commit Messages
* Use the present tense ("Add feature" not "Added feature").
* Use the imperative mood ("Move cursor to..." not "Moves cursor to...").
* Limit the first line to 72 characters or less.
* Reference issues and pull requests liberally after the first line.

### Code Style
* **Flutter/Dart:** We adhere to the standard `flutter analyze` guidelines. Please ensure your code passes the linter and try to separate business logic from UI where possible.
* **Python/FastAPI:** We follow PEP 8 standards. Ensure your code is properly typed using Python type hints.

---
*Thank you for helping make ZynkUp better!* 🚀
```
