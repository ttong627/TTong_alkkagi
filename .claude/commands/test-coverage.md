---
description: '테스트 커버리지 분석 — 커버리지를 재서 80% 미만 파일의 빠진 경로에 테스트를 보강한다. 「커버리지」「테스트 보강」에 쓴다.'
---

# Test Coverage

Analyze test coverage and generate missing tests:

1. Run tests with coverage: npm test --coverage or pnpm test --coverage

2. Analyze coverage report (coverage/coverage-summary.json)

3. Identify files below 80% coverage threshold

4. For each under-covered file:
   - Analyze untested code paths
   - Generate unit tests for functions
   - Generate integration tests for APIs
   - Generate E2E tests for critical flows

5. Verify new tests pass

6. Show before/after coverage metrics

7. Ensure project reaches 80%+ overall coverage

Focus on:
- Happy path scenarios
- Error handling
- Edge cases (null, undefined, empty)
- Boundary conditions
