---
description: commit and push all changes after every task
---

// turbo-all

After completing any task that modifies files in the repository, always run the following steps:

1. Stage all changed files:
```
git add -A
```

2. Commit with a meaningful message describing what was done:
```
git commit -m "<type>: <short description of what was done>"
```
Use conventional commit types: `feat`, `fix`, `refactor`, `chore`, `docs`, `style`.

3. Push to the remote:
```
git push
```
