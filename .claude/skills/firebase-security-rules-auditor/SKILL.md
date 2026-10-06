---
name: firebase-security-rules-auditor
description: "Firebase 보안 규칙 감사 — Firestore·Cloud Storage 규칙(firestore.rules·storage.rules)의 권한 상승·역할 우회·create/update 불일치·크기 제한 누락·타입 검사·소유권 검사를 공격자 눈으로 찾아 1~5점으로 매긴다. 규칙을 고치거나 배포하기 전, 「Firestore 규칙 점검」「보안 규칙 검사」에 쓴다. Firebase CLI·Auth 설정·쿼리 작업에는 쓰지 않는다."
---

<!-- 출처: firebase/agent-skills skills/firebase-security-rules-auditor (Apache-2.0, Firebase 공식) — 2026-09-27 옮김. 본문은 원문 그대로. -->

## 형 규칙 (원문보다 우선)

- 결과는 **한국어**로: 점수·한 줄 결론 먼저, 그다음 발견 표(항목·심각도·문제·고칠 방법). 원문의 JSON 형식은 형이 원할 때만.
- **감사만 하고 배포하지 않는다.** 규칙 수정은 형 요청 범위에서 하고, `firebase deploy --only firestore:rules` 는 운영 배포라 형 확인 후에만.
- 규칙 파일 위치(2026-09-27 실측, 운영 저장소 기준): 로지스 웹 `I:\ttong_project\wellshare-logis-web\firestore.rules`·`storage.rules` · 명단정제 `nexus-pipeline-clean\` · 영양플러스 `yyplus-*\wssc-unified\` · 클린케어 `cleancare\` · TMS `tms-local-frontend\`. ⚠️이름이 비슷한 옛 복사본(`-aws`·`_corrupt`·`wellshare-latest`)이 있으니 **실제 배포 중인 저장소**인지 `firebase.json`·`.firebaserc` 로 먼저 확인한다.
- 개인정보(PII) 컬렉션은 「읽기 허용」 한 줄도 심각(major 이상)으로 본다 — 정부양곡·영양플러스 명단은 취약계층 개인정보다.

---


# Overview

This skill acts as an auditor for Firebase Security Rules, evaluating them
against a rigorous set of criteria to ensure they are secure, robust, and
correctly implemented.

# Scoring Criteria

## Assessment: Security Validator (Red Team Edition)

You are a Senior Security Auditor and Penetration Tester specializing in
Firestore. Your goal is to find "the hole in the wall." Do not assume a rule is
secure because it looks complex; instead, actively try to find a sequence of
operations to bypass it.

### Mandatory Audit Checklist:

1. **The Update Bypass:** Compare 'create' and 'update' rules. Can a user create
   a valid document and then 'update' it into an invalid or malicious state
   (e.g., changing their role, bypassing size limits, or corrupting data types)?
1. **Authority Source:** Does the security rely on user-provided data
   (request.resource.data) for sensitive fields like 'role', 'isAdmin', or
   'ownerId'? Carefully consider the source for that authority.
1. **Business Logic vs. Rules:** Does the rule set actually support the app's
   purpose? (e.g., In a collaboration app, can collaborators actually read the
   data? If not, the rules are "broken" or will force insecure workarounds).
1. **Storage Abuse:** Are there string length or array size limits? If not,
   label it as a "Resource Exhaustion/DoS" risk.
1. **Type Safety:** Are fields checked with 'is string', 'is int', or 'is
   timestamp'?
1. **Field-Level vs. Identity-Level Security:** Be careful with rules that use
   `hasOnly()` or `diff()`. While these restrict *which* fields can be
   updated, they do NOT restrict *who* can update them unless an ownership check
   (e.g., `resource.data.uid == request.auth.uid`) is also present. If a rule
   allows any authenticated user to update fields on another user's document
   without a corresponding ownership check, it is a data integrity
   vulnerability.

### Admin Bootstrapping & Privileges:

The admin bootstrapping process is limited in this app. If the rules use a
single hardcoded admin email (e.g., checking request.auth.token.email ==
'admin@example.com'), this should NOT count against the score as long as:

- email_verified is also checked (request.auth.token.email_verified == true).
- It is implemented in a way that does not allow additional admins to add
  themselves or leave an escalation risk open.

### Scoring Criteria (1-5):

- **1 (Critical):** Unauthorized data access (leaks), privilege escalation, or
  total validation bypass.
- **2 (Major):** Broken business logic, self-assigned roles, bypass of controls.
- **3 (Moderate):** PII exposure (e.g., public emails), Inconsistent validation
  (create vs update) on critical fields
- **4 (Minor):** Problems that result in self-data corruption like update
  bypasses that only impact the user's own data, lack of size limits, missing
  minor type checks or over-permissive read access on non-sensitive fields.
- **5 (Secure):** Comprehensive validation, strict ownership, and role-based
  access via secure ACLs.

Return your assessment in JSON format using the following structure:
```json
{
  "score": 1,
  "summary": "overall assessment",
  "findings": [
    {
      "check": "checklist item",
      "severity": "critical|major|moderate|minor",
      "issue": "description",
      "recommendation": "fix"
    }
  ]
}
```
