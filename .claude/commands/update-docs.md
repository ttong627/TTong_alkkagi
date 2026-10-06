---
description: '문서 동기화 — package.json 스크립트·.env.example 등 진짜 출처에서 README·사용 문서를 다시 맞춘다. 기능이 바뀌어 문서가 낡았을 때 쓴다.'
---

# Update Documentation

Sync documentation from source-of-truth:

1. Read package.json scripts section
   - Generate scripts reference table
   - Include descriptions from comments

2. Read .env.example
   - Extract all environment variables
   - Document purpose and format

3. Generate docs/CONTRIB.md with:
   - Development workflow
   - Available scripts
   - Environment setup
   - Testing procedures

4. Generate docs/RUNBOOK.md with:
   - Deployment procedures
   - Monitoring and alerts
   - Common issues and fixes
   - Rollback procedures

5. Identify obsolete documentation:
   - Find docs not modified in 90+ days
   - List for manual review

6. Show diff summary

Single source of truth: package.json and .env.example
