-- PostgreSQL-ish DDL (adjust types if needed)
CREATE TABLE users (
  user_id BIGINT PRIMARY KEY,
  registration_date DATE NOT NULL,
  country TEXT NOT NULL,
  source TEXT NOT NULL,
  device TEXT NOT NULL
);

CREATE TABLE sessions (
  session_id BIGINT PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(user_id),
  session_start TIMESTAMP NOT NULL,
  session_end TIMESTAMP NOT NULL,
  game_played TEXT NOT NULL,
  revenue NUMERIC(12,2) NOT NULL
);

CREATE TABLE events (
  event_id BIGINT PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(user_id),
  event_time TIMESTAMP NOT NULL,
  event_type TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL
);

CREATE TABLE ab_tests (
  user_id BIGINT NOT NULL REFERENCES users(user_id),
  test_name TEXT NOT NULL,
  test_group TEXT NOT NULL,
  test_start_date DATE NOT NULL
);
