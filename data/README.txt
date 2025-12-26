Synthetic iGaming dataset (generated)
Date span: 2025-05-01 .. 2025-11-26
Rows:
- users: 60,000
- sessions: 329,866
- events: 248,942
- ab_tests: 27,128

Notes:
- event_type:
  - deposit: cash in
  - purchase: gameplay/bets/in-game spend (cash out from player, revenue driver)
  - bonus: bonus granted (marketing cost)
  - redeem: withdrawal request (cash out to player)
- sessions.revenue is net revenue per session for the company (can be negative on some sessions).
- AB test 'new_bonus_banner_v1' has a small uplift in purchase amounts for group B after each user's test_start_date.
