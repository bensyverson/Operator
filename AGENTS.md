IMPORTANT: As you're implementing features, be sure to keep the [DocC documentation](./Sources/Operator/Documentation.docc/)  up to date, updating [README](README.md) only if a new documentation file has been added, or if new users MUST know about your changes.

## Overview

You are working on Operator, a Swift library which uses one or more LLMs to provide Agentic features (tool use in a loop) to applications.

LLM support is provided by a separate library, `LLM`, in a sibling directory. If you need to make changes to LLM, you will need to access `../LLM/`, commit your changes, and then update the dependency here.

In general, if we want to introduce changes that any LLM user (agentic or not) would want, we should try to add them there. Otherwise we will keep our changes to this repo.

## Documentation

When you need additional context, consult the docs:

- [README.md](README.md) - Project overview and quick start
- [DocC documentation](./Sources/Operator/Documentation.docc/) - In-depth documentation about Operator's architecture, models and concepts
- [project/](project/) - Internal design documents and past project plans

API documentation is generated with DocC: `swift package generate-documentation --target Operator`. Ensure any new or updated code keeps our DocC annotations up to date.

## General

- If a requirement is ambiguous or could be solved in several ways, choose the most idiomatic way to solve the problem in Swift if that would resolve the ambiguity.
- If the ambiguity is more about the requirement itself, or you face an architectural question, don't make a decision—stop and ask the user instead.
- Avoid dependencies unless the required functionality would be unreasonable to re-implement. If you MUST bring in a dependency, get the user's permission first.
- If a routine is more fragile or more complex than a simple CRUD operation, always write a unit test to verify a correct implementation.

## Understand the "why"
Before you answer a question or respond to a request, you must understand **why** the user has made this request. Beware of the "XY Problem." If the user's motivation or goal is not 100% clear, first ask clarifying questions until you fully understand what they're trying to achieve.

## Diverge, then converge
Once you understand the prompt, rather than jumping to a solution, you will use divergent thinking. Brainstorm other options. Weigh these options against the user's preferences and overall objectives. Then, converge on a recommendation, and ask for confirmation from the user. Only then can you fully converge and begin executing on a direction.

## Analysis
It will sometimes be valuable to create a script or tool in order to aid your analysis. Before you do, check the `scripts` directory to make sure it doesn't already exist. If it doesn't, rather than creating a disposable or inline script, add it to the `scripts` directory, so the user can re-run the tool in the future.

## Pre-completion Critique
Before you declare a task done, or a question answered, pause and critique your own work. Return to the context of the original user request—have you truly addressed their need? If you're producing code, do all linting and unit tests pass? If you're synthesizing or analyzing information, what are the gaps or weaknesses in your answer? What would a relevant and intelligent expert say about your work? If you identify serious flaws, keep working until you resolve them.

## Tidiness
Don't create temporary files in the root of the directory and leave them there. If you truly need a transient file, that's fine, but delete it when you're done. But if the artifact is something valuable (such as an agent's report, or a script), please save it in the correct directory.

## Git workflow
The user may not be an experienced user of Git. At moments when significant work has been completed and accepted by the user, offer to commit the changes for them. You may need to pull changes and resolve conflicts, which you should do for the user using git rebase whenever possible. If there is a real conflict, ask the user how they want to resolve it, explaining the situation clearly.

## Development workflow

- All Git commit messages should complete the sentence "This commit…", e.g. "Adds an email verification flow". You can then go on to detail the change with bullets or headers in the body of the commit.
- IMPORTANT: Anytime we are working on code which should produce a known output (e.g. data extractors, calculation modules, utilities to list data), or we are refactoring code that lacks test coverage, we ALWAYS follow strict TDD; write tests for all known example cases we're working with, verify that they fail, and *then* proceed to implement your code changes. If you must alter the test to get it to pass, explain exactly WHY to the user and get their consent.
- Prior to commiting changes, you must run the linter (`swiftformat . --lint`) and re-run to format if necessary (`swiftformat .`), or fix any issues manually if necessary. You must also run the full test suite (`swift test --quiet`). Linting and testing are both pre-commit hooks, so this will allow you to catch problems before attempting a commit.

## Development Stage

- We are in BUILD mode. This library is pre-launch, with zero users or existing files. When refactoring or implementing new features, we NEVER need to consider backward compatibility. We can assume that every use of the project is green-field. We're trying to architect a clean, clear API and codebase without any baggage. With that said, make sure the user knows when you make breaking changes, and be sure to update any relevant unit tests.
- In build mode, we are ambitious. Even if you think a feature will take weeks or months, if it's important, let's take it on now. We will build what we know is needed to achieve the overall project goals, without taking shortcuts or implementing the MVP. But we will balance this with avoiding "future-proofing" or over-engineering.

## Swift-specific

When writing Swift, adhere to these guidelines:

- Try to always make new types conform to `Friendly` (it's defined as `typealias Friendly = Codable & Hashable & Equatable & Sendable`), even if you have no current plans to serialize or compare them.
- Strongly prefer modern async / await APIs
- Ensure your work supports Swift 6's strict concurrency requirements. Resolve compiler warnings as you encounter them.
- Try to keep your code as cross-platform as possible; if you must use macOS or iOS-specific APIs, surround them with @available checks, and provide coverage for at least macOS and iOS. Whenever possible, stay within Foundation, so your code will compile on Linux/FreeBSD as well as Apple platforms.
- When using regex, always use the modern Swift Regex API over the old methods
- When initializing new objects, don't use the `.init()` shorthand; it makes the Swift type checker work harder.
- When initializing a variable with the result of an expression which uses generics, is chained, complex, or where the function signature could vary based on input (e.g. duplicate methods with the same name but different input & output types), give the type checker a hint by declaring the type of the return: `let output: String = {complex}`
- When creating a new combined library/executable, if the entire package is FooBar, name the library target & files FooBarCore, and the CLI target & files FooBarCommand.
- Nest subtype declarations within the type declaration when they're small (enums and small structs), rather than polluting the global namespace with new types.
- When creating a new group of tests (new struct), place them in a new Swift file in the correct folder, rather than adding them to an existing file.
- When extending a type, place the extension in its own folder, named `BaseType+ExtensionName.swift`—for example, if you need a custom Codable implementation for `Timeline`, it would be `Timeline+Codable.swift`. This applies to extending third-party types as well.
