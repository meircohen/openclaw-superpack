This is a comprehensive audit of Garry Tan's `gstack` skill pack. The audit covers skill definitions, prompt optimization patterns, workflow automation patterns, `CLAUDE.md` rules, and unique features.

### 1. Skill Definitions

The `gstack` repository contains a rich set of skills that cover the entire software development lifecycle, from ideation to deployment and maintenance. The skills are designed to work together as a cohesive system, with each skill representing a specific role in a virtual engineering team.

Here's a summary of the available skills:

*   **Ideation & Planning:**
    *   `/office-hours`: A YC-style office hours session to brainstorm and refine a product idea.
    *   `/plan-ceo-review`: A CEO/founder-style plan review, focusing on the product vision.
    *   `/plan-eng-review`: An engineering manager-style plan review, focusing on architecture and technical feasibility.
    *   `/plan-design-review`: A designer's eye plan review.
    *   `/autoplan`: An auto-review pipeline that runs CEO, design, and eng reviews sequentially.

*   **Design:**
    *   `/design-consultation`: Creates a complete design system for a project.
    *   `/design-shotgun`: Generates multiple AI design variants for visual brainstorming.
    *   `/design-html`: Finalizes a design from a mockup into production-quality HTML/CSS.
    - `/design-review`: A designer's eye QA that finds and fixes visual inconsistencies.

- **Development &- Review:**
-   `/investigate`: A systematic debugging skill with root cause investigation.
-   `/codex`: A wrapper for the OpenAI Codex CLI to get a second opinion on code.
-   `/review`: A pre-landing pull request review that analyzes the diff for various issues.

- **QA &- Testing:**
    - `/browse`: A fast headless browser for QA testing and site dogfooding.
    - `/connect-chrome`: Launches a real Chrome browser controlled by gstack.
    - `/setup-browser-cookies`: Imports cookies from a Chromium browser into the headless browsing session.
-   `/qa`: Systematically tests a web application, finds bugs, and fixes them in source code.
-   `/qa-only`: Same as `/qa` but only reports bugs, it doesn't fix them.
-   `/benchmark`: Performance regression detection.

*   **Deployment & Maintenance:**
    *   `/ship`: A comprehensive workflow to ship code, including creating a pull request.
    *   `/land-and-deploy`: Merges a pull request, waits for CI and deployment, and verifies the production health.
    *   `/setup-deploy`: Configures deployment settings for `/land-and-deploy`.
    *   `/canary`: Post-deploy canary monitoring.
    *   `/document-release`: Updates project documentation after a release.
    *   `/gstack-upgrade`: Upgrades gstack to the latest version.

- **Safety &- Utility:**
-   `/careful`: Provides safety guardrails for destructive commands.
-   `/freeze`: Restricts file edits to a specific directory.
-   `/unfreeze`: Clears a "freeze" boundary, allowing edits to all directories.
-   `/guard`: A full safety mode that combines `/careful` and `/freeze`.
-   `/learn`: Manages project learnings.

- **Team &- Project Management:**
-   `/retro`: A weekly engineering retrospective that analyzes commit history, work patterns, and code quality metrics.

### 2. System Prompt Optimization Patterns

The `gstack` skill pack is a masterclass in prompt engineering. It uses a variety of techniques to guide the LLM's behavior and ensure high-quality output.

*   **Personas and Cognitive Patterns:** Many skills define a specific persona for the agent (e.g., "YC office hours partner," "paranoid staff engineer," "Chief Security Officer"). The review skills also include "Cognitive Patterns" which are high-level mental models for the agent to adopt. This is a very advanced and effective form of prompt engineering.
*   **Explicit Instructions and Constraints:** The skills are very explicit about what the agent should do and what it should not do. For example, the `/ship` skill states "This is a **non-interactive, fully automated** workflow. Do NOT ask for confirmation at any step." This reduces ambiguity and prevents the agent from getting stuck.
*   **Structured Output:** The skills often specify a structured output format, such as tables, JSON, or ASCII diagrams. This makes the output more predictable and easier for both humans and other tools to parse.
*   **Confidence Calibration:** The `/review` skill requires the agent to provide a confidence score for each finding. This forces the agent to be more deliberate in its analysis and helps the user to prioritize which findings to address.
*   **Fix-First Heuristic:** The `/review` skill uses a "Fix-First" heuristic, where it classifies findings as `AUTO-FIX` or `ASK`. This empowers the agent to fix what it can while still leaving critical decisions to the user.
*   **Idempotency Checks:** Many skills include idempotency checks to avoid duplicate work, such as checking if a version has already been bumped in the `/ship` skill.
*   **Hooks for Safety:** The `careful`, `freeze`, and `guard` skills use `PreToolUse` hooks to intercept and check commands before they are executed. This is a powerful way to build safety features into an AI agent.
*   **Self-Regulation:** The `/qa` skill has a "Self-Regulation" step that uses a "WTF-likelihood" score to decide whether to stop and ask for user input. This is a great way to prevent the agent from going down a rabbit hole of failing fixes.

### 3. Workflow Automation Patterns

The `gstack` skills are designed to work together as a cohesive system, automating complex software development workflows from end to end.

*   **Skill Chaining:** The skills are designed to be chained together to form a complete software development lifecycle. For example, a typical workflow might be: `/office-hours` -> `/plan-ceo-review` -> `/plan-eng-review` -> implementation -> `/review` -> `/ship` -> `/land-and-deploy` -> `/document-release`.
*   **Context Passing through Artifacts:** The skills pass context to each other by creating and reading artifacts (mostly markdown files). For example, `/office-hours` writes a design doc that is read by `/plan-ceo-review`. This allows for a persistent, shared understanding of the project across different skills and sessions.
*   **Proactive Skill Invocation:** The main `gstack` skill includes routing rules that proactively invoke other skills based on the user's request. This is a powerful way to guide the user to the right tool for the job and create a more seamless user experience.
*   **The `/autoplan` Skill:** The `/autoplan` skill is the ultimate example of workflow automation. It runs the entire review pipeline (CEO, design, and eng reviews) sequentially, making decisions automatically based on a set of predefined principles.

### 4. `CLAUDE.md` and Other Conventions

The `gstack` repository promotes the use of several conventions to improve the interaction between the user, the agent, and the codebase.

*   **`CLAUDE.md`:** This file serves as a central place to provide instructions and context to the agent. The "Skill routing" section is particularly useful, as it provides explicit guidance on when to use which skill.
*   **`DESIGN.md`:** This file acts as the source of truth for the project's design system. This is a great pattern to adopt, as it ensures consistency and provides a clear reference for both the agent and human developers.
*   **`TODOS.md`:** A simple but effective way to track tasks and to-do items.

### 5. Unique and Noteworthy Features

The `gstack` skill pack contains several features that are unique and particularly noteworthy.

*   **The `browse` and `design` Binaries:** `gstack` includes its own compiled binaries for browsing and design. This is a significant piece of engineering that provides a fast, persistent, and reliable way for the agent to interact with web pages and generate design mockups.
*   **The Design Skill Set:** The suite of design skills (`/design-consultation`, `/design-shotgun`, `/design-html`, `/design-review`) is exceptionally comprehensive and powerful. The ability to generate design variants, create a complete design system, and finalize designs into production-quality HTML/CSS is a game-changer.
*   **Pretext-native HTML Engine:** The use of Pretext for dynamic text layout is a very advanced and sophisticated feature.
*   **The `/cso` skill:** A dedicated security audit skill is a great idea.
*   **The `/retro` skill:** The retrospective skill with per-person breakdowns and trend tracking is very advanced.
*   **The multi-AI second opinion (`/codex` skill):** Using another AI model (OpenAI's Codex) for a second opinion is a very clever way to improve the quality of the output.
*   **The concept of "Taste Memory":** The `/design-shotgun` skill remembers the user's preferences across sessions to bias future generations.
*   **The "Cognitive Patterns" in the review skills:** This is a very advanced and unique form of prompt engineering.
*   **The "Self-Regulation" in the `/qa` skill:** The "WTF-likelihood" score is a great way to prevent the agent from going down a rabbit hole.
*   **The `PreToolUse` hooks for safety:** The `careful`, `freeze`, and `guard` skills are a great example of how to build safety features into an AI agent.

### Conclusion

The `gstack` skill pack is a very impressive and comprehensive system for AI-assisted software development. It is well-designed, with a clear philosophy and a set of powerful, well-integrated tools. The use of advanced prompt engineering techniques, custom binaries, and multi-AI collaboration makes it a state-of-the-art example of what is possible with AI agents today.

There are many patterns and features from `gstack` that would be beneficial to adopt. The most impactful would be:

*   **The concept of a structured, multi-skill workflow** that covers the entire software development lifecycle.
*   **The use of artifacts (like `DESIGN.md` and design docs) to pass context** between skills.
*   **The advanced prompt engineering techniques,** especially the use of personas, cognitive patterns, and explicit constraints.
*   **The safety features** implemented through hooks.
*   **The multi-AI second opinion** for critical tasks like code review.

Overall, `gstack` is a fantastic resource and a great source of inspiration for building our own AI-powered development tools.
