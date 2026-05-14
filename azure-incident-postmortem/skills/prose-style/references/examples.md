# Before/After Examples

These calibrate the difference between AI output and natural prose. The goal is not formal vs. casual. It is human vs. generated.

---

## Example 1: Short Explanation

**Before (AI slop)**

> Certainly! I'd be happy to explain how caching works. It's worth noting that caching is a robust mechanism that can seamlessly improve performance by leveraging stored data to avoid redundant computation. Furthermore, it's important to understand that cache invalidation is one of the more nuanced challenges in software engineering.

**After**

> Caching stores the result of an expensive operation so you don't have to repeat it. The hard part is knowing when to throw the cached result away. That is cache invalidation, and it is where most bugs live.

---

## Example 2: Recommendation

**Before (AI slop)**

> Based on a comprehensive analysis of the various factors at play, I would recommend that you consider implementing a rate limiter. This would potentially help to streamline the request flow and could possibly reduce the likelihood of downstream service failures. It's also worth noting that this approach is consistent with industry best practices.

**After**

> Add a rate limiter. Unthrottled traffic is what is taking down your downstream services, and rate limiting is the standard fix.

---

## Example 3: Slack Message

**Before (AI slop)**

> Hi team! I wanted to reach out and let everyone know that the deployment has been completed successfully. I'm happy to report that all systems are functioning as expected, and there were no issues encountered during the process. Please don't hesitate to reach out if you have any questions or concerns!

**After**

> Deploy is done. Everything looks healthy. Let me know if you see anything weird.

---

## Example 4: Status Update

**Before (AI slop)**

> In this update, I'll walk you through the current state of the project. There are several key areas to highlight:
>
> - The backend API has been implemented and is functioning as expected
> - The frontend integration is currently in progress
> - Testing is ongoing and we anticipate completion by end of week
> - Stakeholder review is scheduled for next week

**After**

> Backend API is done. Frontend integration is in progress, testing wraps up Friday, and stakeholder review is next week.

---

## Example 5: Technical Writeup Opening

**Before (AI slop)**

> In this document, we will delve into the various aspects of our new authentication system. This comprehensive overview will explore the innovative approach we've taken to foster a more robust and seamless user experience while ensuring that security considerations are holistically addressed.

**After**

> This document covers the new authentication system: how it works, why we built it this way, and what you need to know to integrate with it.

---

## Example 6: Postmortem Root Cause (plugin-specific)

**Before (AI slop)**

> The root cause of this incident was a confluence of factors that may have contributed to a cascading failure scenario. Notably, the deployment of changes to the authentication service resulted in unexpected behavior that potentially caused downstream services to experience degraded functionality. It is worth noting that several mitigating factors were also in play.

**After**

> A 14:00 deploy to the authentication service shipped a token-rotation change that did not pre-warm token caches. The first wave of post-deploy requests hit cold caches and timed out, which cascaded to the payment service through its auth dependency. The Datadog logs at `service:auth status:error` for the 14:00 to 14:15 window confirm the pattern.

---

## Calibration Notes

The after versions share a few things:

- They open with the point, not a setup.
- They use short sentences and plain words.
- They do not hedge unless the uncertainty is meaningful.
- They treat the reader as an adult who can handle a direct statement.

Length reduction is a side effect, not the goal. A long piece of writing can be completely human. It just cannot be padded.
